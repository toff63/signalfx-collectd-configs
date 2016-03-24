#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd 2>/dev/null)
source "${SCRIPT_DIR}/install_helpers"
SFX_INGEST_URL="https://ingest.signalfx.com"

get_logfile() {
    LOGTO="\"/var/log/signalfx-collectd.log\""
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$NAME" == "CentOS Linux" -a "$VERSION_ID" == "7" ]; then
            LOGTO="stdout";
        fi
    fi
}

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
    USE_SERVICE_COLLECTD=0
    if [ "$COLLECTD_ETC" == "/etc" ]; then
	USE_SERVICE_COLLECTD=1
        COLLECTD_ETC="/etc/collectd.d"
        printf "Making /etc/collectd.d..."
        mkdir -p ${COLLECTD_ETC};
        check_for_err "Success\n";
    elif [ "$COLLECTD_ETC" == "/etc/collectd" ]; then
        USE_SERVICE_COLLECTD=1
    fi

	 COLLECTD_MANAGED_CONFIG_DIR=${COLLECTD_ETC}/managed_config
	 COLLECTD_FILTERING_CONFIG_DIR=${COLLECTD_ETC}/filtering_config
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
        echo "There are two ways to configure the source name to be used by collectd"
        echo "when reporting metrics:"
        echo "dns - Use the name of the host by resolving it in dns"
        echo "input - You can enter a hostname to use as the source name"
        echo
        read -p "How would you like to configure your Hostname? (dns  or input): " SOURCE_TYPE < /dev/tty

        while [ "$SOURCE_TYPE" != "dns" -a "$SOURCE_TYPE" != "input" ]; do
            read -p "Invalid answer. How would you like to configure your Hostname? (dns or input): " SOURCE_TYPE < /dev/tty
        done
    fi

    case $SOURCE_TYPE in
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
    echo "   [-o SIGNALFX_ORG] [-H HOSTNAME] [-i SFX_INGEST_URL] [/path/to/collectd]"
    echo "Installs collectd.conf and configures it for talking to SignalFx."
    echo "Installs the SignalFx collectd plugin on supported oses.  If on an unknown os"
    echo "and the plugin is already present, will configure it."
    echo "If path to collectd is not specified then it will be searched for in well know places."
    echo
    echo "  -s SOURCE_TYPE : How to configure the Hostname field in collectd.conf:"
    echo "                    input - set a hostname. See --hostname"
    echo "                    dns - use FQDN of the host as the Hostname"
    echo
    echo " -H HOSTNAME: The Hostname value to use if you selected hostname as your source_type"
    echo
    echo " -i SFX_INGEST_URL: The Ingest URL to be used. Defaults to ${SFX_INGEST_URL}"
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
    release_type=release
    while getopts ":s:t:u:o:H:hbTa:i:" opt; do
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
           b)
               release_type=beta
               source "${SCRIPT_DIR}/install_helpers"
               ;;
           T)
               release_type=test
               source "${SCRIPT_DIR}/install_helpers"
               ;;
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

install_filters() {
    printf "Installing filtering configs\n"
    for i in `ls -1 ${FILTERING_CONF_DIR}`
    do
     cp "${FILTERING_CONF_DIR}/$i" "${COLLECTD_FILTERING_CONFIG_DIR}/"
     check_for_err  "Instaiilng $i - Success\n"
    done

}
check_for_aws() {
    printf "Checking to see if this box is in AWS: "
    AWS_UNIQUE_ID=$(${SCRIPT_DIR}/get_aws_unique_id)
    status=$?
    if [ $status -eq 0 ]; then
        printf "Using AWSUniqueId: %s\n" "${AWS_UNIQUE_ID}"
        EXTRA_DIMS="?sfxdim_AWSUniqueId=${AWS_UNIQUE_ID}"
    elif [ $status -ne 28 -a $status -ne 7 ]; then
        check_for_err "Unknown Error $status\n"
    else
        printf "Not IN AWS\n"
    fi
}

install_plugin_common() {
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
    check_for_aws
}

install_signalfx_plugin() {
    if [ -n "$NO_PLUGIN" ]; then
        return
    fi
    install_plugin_common

    printf "Fixing SignalFX plugin configuration.."
    sed -e "s#%%%API_TOKEN%%%#${API_TOKEN}#g" \
        -e "s#%%%INGEST_HOST%%%#${SFX_INGEST_URL}#g" \
        -e "s#%%%EXTRA_DIMS%%%#${EXTRA_DIMS}#g" \
        "${MANAGED_CONF_DIR}/10-signalfx.conf" > "${COLLECTD_MANAGED_CONFIG_DIR}/10-signalfx.conf"
    check_for_err "Success\n";
}

install_write_http_plugin(){
    install_plugin_common

    printf "Fixing write_http plugin configuration.."
    sed -e "s#%%%API_TOKEN%%%#${API_TOKEN}#g" \
        -e "s#%%%INGEST_HOST%%%#${SFX_INGEST_URL}#g" \
	-e "s#%%%EXTRA_DIMS%%%#${EXTRA_DIMS}#g" \
        "${MANAGED_CONF_DIR}/10-write_http-plugin.conf" > "${COLLECTD_MANAGED_CONFIG_DIR}/10-write_http-plugin.conf"
    check_for_err "Success\n";
}

copy_configs(){
    okay_ver=$(vercomp "$COLLECTD_VER" 5.2)
    if [ "$okay_ver" !=  2 ]; then
        install_config 10-aggregation-cpu.conf "CPU Aggregation Plugin"
    fi
    install_write_http_plugin
    install_filters
}

verify_configs(){
    echo "Verifying config"
    ${COLLECTD} -t
    echo "All good"
}

check_with_user_and_stop_other_collectd_instances(){
    count_running_collectd_instances=$(pgrep -x collectd | wc -l)
    if [ $count_running_collectd_instances -ne 0 ]; then
        PROCEED_STATUS=0
        printf "Currently, $count_running_collectds more instances of collectd are running on this machine\n"
        printf "Do you want to\n"
        printf "1. Stop here and check\n"
        printf "2. Stop all running instances of collectd and start a new one\n"
        printf "3. Start this along with others\n"
        while [[ ! ( $PROCEED_STATUS -eq 1 || $PROCEED_STATUS -eq 2 || $PROCEED_STATUS -eq 3 ) ]]; do
            read -p "Choose an option(1/2/3): " PROCEED_STATUS < /dev/tty
        done
        case $PROCEED_STATUS in
            1)
                echo "Check and come back. Exiting for now..."
                exit 0;
                ;;
            2)
                echo "Stopping all running collectd instances..."
                pkill -x collectdmon > /dev/null 2>&1
                pkill -x collectd > /dev/null 2>&1 # centos does not have collectdmon
                ;;
        esac
    fi
}


main() {
    get_collectd_config
    get_source_config
    get_logfile
    okay_ver=$(vercomp "$COLLECTD_VER" 5.4.0)
    if [ "$okay_ver" != 2 ]; then
        WRITE_QUEUE_CONFIG="WriteQueueLimitHigh 500000\\nWriteQueueLimitLow  400000"
    fi
    okay_ver=$(vercomp "$COLLECTD_VER" 5.5.0)
    if [ "$okay_ver" != 2 ]; then
        WRITE_QUEUE_CONFIG="$WRITE_QUEUE_CONFIG\\nCollectInternalStats true"
    fi

    printf "Making managed config dir %s ..." "${COLLECTD_MANAGED_CONFIG_DIR}"
    mkdir -p "${COLLECTD_MANAGED_CONFIG_DIR}"
    check_for_err "Success\n";

    printf "Making managed filtering config dir %s ..." "${COLLECTD_FILTERING_CONFIG_DIR}"
    mkdir -p "${COLLECTD_FILTERING_CONFIG_DIR}"
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
        -e "s#%%%COLLECTDFILTERINGCONFIG%%%#${COLLECTD_FILTERING_CONFIG_DIR}#" \
        -e "s#%%%LOGTO%%%#${LOGTO}#" \
        "${BASE_DIR}/collectd.conf.tmpl" > "${COLLECTD_CONFIG}"
    check_for_err "Success\n"

    # Install Plugin
    install_plugin
    install_signalfx_plugin

    # Install managed_configs
    copy_configs
    verify_configs

    # Stop running Collectd
    echo "Stopping collectd"
    if [ ${USE_SERVICE_COLLECTD} -eq 1 ]; then
        service collectd stop
    else
        pkill -nx collectd # stops the newest (most recently started) collectd similar to 'service collectd stop'
    fi

    check_with_user_and_stop_other_collectd_instances

    echo "Starting collectd"
    if [ ${USE_SERVICE_COLLECTD} -eq 1 ]; then
        service collectd start
    else
        ${COLLECTD}
    fi
}

BASE_DIR=$(cd "$(dirname "$0")" && pwd 2>/dev/null)
MANAGED_CONF_DIR=${BASE_DIR}/managed_config
FILTERING_CONF_DIR=${BASE_DIR}/filtering_config

parse_args "$@"
main
