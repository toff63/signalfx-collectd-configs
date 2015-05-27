#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd 2>/dev/null)
source "${SCRIPT_DIR}/install_helpers"

get_collectd_config() {
    printf "Getting config file for collectd..."
    COLLECTD_CONFIG=$(${COLLECTD} -h 2>/dev/null | grep 'Config file' | awk '{ print $3; }')
    if [ -z "$COLLECTD_CONFIG" ]; then
        echo "Failed"
        exit 2;
    else
        echo "Success";
    fi
    COLLECTD_ETC=$(dirname "${COLLECTD_CONFIG}")
    if [ "$COLLECTD_ETC" == "/etc" ]; then
        COLLECTD_ETC="/etc/collectd.d"
        printf "Making /etc/collectd.d..."
        mkdir -p ${COLLECTD_ETC};
        check_for_err "Success\n";
    fi
    COLLECTD_MANAGED_CONFIG_DIR=${COLLECTD_ETC}/managed_config
    printf "Getting TypesDB default value..."
    if [ -x /usr/bin/strings ]; then
        TYPESDB=$(strings "${COLLECTD}" | grep /types.db)
    else
        TYPESDB=$(grep -oP -a "/[-_/[:alpha:]0-9]+/types.db\x00" "${COLLECTD}")
    fi
    if [ -z "$TYPESDB" ]; then
        echo "FAILED"
        exit 2;
    else
        echo "Success";
    fi
    find_collectd_ver
}

get_source_config() {
    if [ -z "$SOURCE_TYPE" ]; then
        echo "There are three ways to configure the source name to be used by collectd"
        echo "when reporting metrics."
        echo "dns - Use the name of the host by resolving it in dns"
        echo "input - You can enter a hostname to use as the source name"
        echo "aws - Use the AWS instance id. This is is helpful if you use tags"
        echo "      or other AWS attributes to group metrics"
        echo
        read -p "How would you like to configure your Hostname? (dns, input, or aws): " SOURCE_TYPE < /dev/tty

        while [ "$SOURCE_TYPE" != "dns" -a "$SOURCE_TYPE" != "input" -a "$SOURCE_TYPE" != "aws" ]; do
            read -p "Invalid answer. How would you like to configure your Hostname? (dns, input, or aws): " SOURCE_TYPE < /dev/tty
        done
    fi

    case $SOURCE_TYPE in
    "aws")
        printf "Fetching AWS instance id.."
        SOURCE_NAME_INFO="Hostname \"$(curl -s http://169.254.169.254/latest/meta-data/instance-id)\""
        if [ -z "${SOURCE_NAME_INFO}" ]; then
            echo "FAILED";
        else
            echo "Success";
        fi
        ;;
     "input")
        if [ -z "$INPUT_HOSTNAME" ]; then
            read -p "Input hostname value: " INPUT_HOSTNAME < /dev/tty
            while [ -z "$INPUT_HOSTNAME" ]; do
              read -p "Invalid input. Input hostname value: " INPUT_HOSTNAME < /dev/tty
            done
        fi
        SOURCE_NAME_INFO="Hostname \"${INPUT_HOSTNAME}\""
        ;;
    "dns")
        SOURCE_NAME_INFO="FQDNLookup   true"
        ;;
    *)
       echo "Invalid SOURCE_TYPE value ${SOURCE_TYPE}";
       exit 2;
    esac

}

usage(){
    echo "$0 [-s SOURCE_TYPE] [-t API_TOKEN] [-u SIGNALFX_USER]"
    echo "   [-o SIGNALFX_ORG] [-H HOSTNAME] [/path/to/collectd]"
    echo "Installs collectd.conf and configures it for talking to SignalFx."
    echo "If path to collectd is not specified then it will be searched for in well know places."
    echo
    echo "  -s SOURCE_TYPE : How to configure the Hostname field in collectd.conf:"
    echo "                    aws - use the aws instance id."
    echo "                    input - set a hostname. See --hostname"
    echo "                    dns - use FQDN of the host as the Hostname"
    echo
    echo " -H HOSTNAME: The Hostname value to use if you selected hostname as your source_type"
    echo
    echo "  Configuring SignalFX access"
    echo "------------------------------"
    echo "  -t API_TOKEN:     If you already know your SignalFx API Token you can specify it."
    echo "  -u SIGNALFX_USER: The SignalFx user name to use to fetch a user token"
    echo "  -o SIGNALFX_ORG:  If the SignalFxe user is part of more than one organization this"
    echo "                      parameter is required."
    echo
    exit "$1";
}

parse_args(){
    SFX_INGEST_URL="https://ingest.signalfx.com"
    while getopts ":s:t:u:o:H:ha:i:" opt; do
        case "$opt" in
           s)
               SOURCE_TYPE="$OPTARG" ;;
           H)
               INPUT_HOSTNAME="$OPTARG" ;;
           t)
               API_TOKEN="$OPTARG" ;;
           u)
               SFX_USER="$OPTARG" ;;
           o)
               SFX_ORG="--org=$OPTARG" ;;
           a)
               SFX_API="--url=$OPTARG" ;;
           i)
               SFX_INGEST_URL="$OPTARG" ;;
           h)
               usage 0; ;;
	   \?) echo "Invalid option: -$OPTARG" >&2;
	       exit 2;
	       ;;
	   :) echo "Option -$OPTARG requires an argument." >&2;
	      exit 2;
	      ;;
           *) break ;;
       esac
    done

    COLLECTD=${@:$OPTIND:1}
    if [ -z "${COLLECTD}" ]; then
        find_installed_collectd
        if [ -z "${COLLECTD}" ]; then
            echo "Unable to find collectd"
            usage 2
        else
            echo "Collectd not specified using: ${COLLECTD}"
        fi
   fi
}

install_config(){
    printf "Installing %s.." "$2"
    cp "${MANAGED_CONF_DIR}/$1" "${COLLECTD_MANAGED_CONFIG_DIR}"
    check_for_err "Success\n"
}

install_write_http_plugin(){

    if [ -z "$API_TOKEN" ]; then
       if [ -z "${SFX_USER}" ]; then
           read -p "Input SignalFx user name: " SFX_USER < /dev/tty
           while [ -z "${SFX_USER}" ]; do
               read -p "Invalid input. Input SignalFx user name: " SFX_USER < /dev/tty
           done
       fi
       API_TOKEN=$(python ${SCRIPT_DIR}/get_all_auth_tokens.py --print_token_only --error_on_multiple ${SFX_API} ${SFX_ORG} "${SFX_USER}")
       if [ -z "$API_TOKEN" ]; then
          echo "Failed to get SignalFx API token";
          exit 2;
       fi
    fi
    printf "Fixing SignalFX plugin configuration.."
    sed -e "s#%%%API_TOKEN%%%#${API_TOKEN}#" \
        -e "s#%%%INGEST_HOST%%%#${SFX_INGEST_URL}#" \
        "${MANAGED_CONF_DIR}/10-write_http-plugin.conf" > "${COLLECTD_MANAGED_CONFIG_DIR}/10-write_http-plugin.conf"
    check_for_err "Success\n";
}

copy_configs(){
    okay_ver=$(vercomp "$COLLECTD_VER" 5.2)
    if [ "$okay_ver" !=  2 ]; then
        install_config 10-aggregation-cpu.conf "CPU Aggregation Plugin"
    fi
    install_write_http_plugin
}

verify_configs(){
    echo "Verifying config"
    ${COLLECTD} -t
    echo "All good"
}

main() {
    get_collectd_config
    get_source_config
    okay_ver=$(vercomp "$COLLECTD_VER" 5.4.0)
    if [ "$okay_ver" != 2 ]; then
        WRITE_QUEUE_CONFIG="WriteQueueLimitHigh 2000000\\nWriteQueueLimitLow  1800000";
    fi

    printf "Making managed config dir %s ..." "${COLLECTD_MANAGED_CONFIG_DIR}"
    mkdir -p "${COLLECTD_MANAGED_CONFIG_DIR}"
    check_for_err "Success\n";

    if [ -e "${COLLECTD_CONFIG}" ]; then
        printf "Backing up %s: " "${COLLECTD_CONFIG}";
        _bkupname=${COLLECTD_CONFIG}.$(date +"%Y-%m-%d-%T");
        mv "${COLLECTD_CONFIG}" "${_bkupname}"
        check_for_err "Success(${_bkupname})\n";
    fi
    printf "Installing signalfx collectd configuration to %s: " "${COLLECTD_CONFIG}"
    sed -e "s#%%%TYPESDB%%%#${TYPESDB}#" \
        -e "s#%%%SOURCENAMEINFO%%%#${SOURCE_NAME_INFO}#" \
	-e "s#%%%WRITEQUEUECONFIG%%%#${WRITE_QUEUE_CONFIG}#" \
        -e "s#%%%COLLECTDMANAGEDCONFIG%%%#${COLLECTD_MANAGED_CONFIG_DIR}#" \
        "${BASE_DIR}/collectd.conf.tmpl" > "${COLLECTD_CONFIG}"
    check_for_err "Success\n"

    #install managed_configs
    copy_configs

    verify_configs

    echo "Starting collectd"
    ${COLLECTD}
}

BASE_DIR=$(cd "$(dirname "$0")" && pwd 2>/dev/null)
MANAGED_CONF_DIR=${BASE_DIR}/managed_config

parse_args "$@"
main
