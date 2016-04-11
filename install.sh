#!/bin/bash

#variables used
selection=0
needed_rpm=null_rpm_link
needed_deps="tar curl"
needed_rpm_name=null_rpm_name
needed_package_name=null_package_name
stage=release
installer_level=""
interactive=1
source_type=""
insecure=""
name=collectd_package_install
debian_distribution_name=""
sfx_ingest_url="https://ingest.signalfx.com"

#rpm file variables
centos_rpm="SignalFx-collectd-RPMs-centos-${stage}-latest.noarch.rpm"
aws_linux_rpm="SignalFx-collectd-RPMs-AWS_EC2_Linux-${stage}-latest.noarch.rpm"

#download location variables
centos="https://dl.signalfx.com/rpms/SignalFx-rpms/${stage}/${centos_rpm}"
aws_linux="https://dl.signalfx.com/rpms/SignalFx-rpms/${stage}/${aws_linux_rpm}"

#plugin rpm file variables
centos_plugin_rpm="SignalFx-collectd_plugin-RPMs-centos-${stage}-latest.noarch.rpm"
aws_linux_plugin_rpm="SignalFx-collectd_plugin-RPMs-AWS_EC2_Linux-${stage}-latest.noarch.rpm"

#plugin download location variables
centos_plugin="https://dl.signalfx.com/rpms/SignalFx-rpms/${stage}/${centos_plugin_rpm}"
aws_linux_plugin="https://dl.signalfx.com/rpms/SignalFx-rpms/${stage}/${aws_linux_plugin_rpm}"

signalfx_public_key_id="185894C15AE495F6"

#ppa locations for wheezy and jessie
signalfx_public_key_id="185894C15AE495F6"
wheezy_ppa="https://dl.signalfx.com/debs/collectd/wheezy/${stage}"
jessie_ppa="https://dl.signalfx.com/debs/collectd/jessie/${stage}"


usage() {
    echo "Usage: $name [ <api_token> ] [ --beta | --test ] [ -H <hostname> ] [ -U <Ingest URL>] [ -h ] [ --insecure ] [ -y ]"
    echo " -y makes the operation non-interactive. api_token is required and defaults to dns if no hostname is set"
    echo " -H <hostname> will set the collectd hostname to <hostname> instead of what dns says."
    echo " -U <Ingest URL> will be used as the ingest url. Defaults to ${sfx_ingest_url}"
    echo " --beta will use the beta repos instead of release."
    echo " --test will use the test repos instead of release."
    echo " --insecure will use the insecure -k with any curl fetches."
    echo " -h this page."
    exit $1
}

#confirm user input (yes or no)
confirm ()
{
    [ $interactive -eq 0 ] && return
    read -r -p "Is this correct? [y/N] " response < /dev/tty
    if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
        then
    return
    else
        exit 0
    fi
}


parse_args(){
    while [ $# -gt 0 ]; do
        case $1 in
           -y)
              [ -z "$source_type" ] && source_type="-s dns"
              interactive=0; shift 1 ;;
           --beta)
              stage=beta
              installer_level="-b" ; shift 1 ;;
           --test)
              stage=test
              installer_level="-T" ; shift 1 ;;
           --insecure)
              insecure="-k"
              shift 1 ;;
           -H)
              [ -z "$2" ] && echo "Argument required for hostname parameter." && usage -1
              source_type="-s input -H $2"; shift 2 ;;
           -U)
              [ -z "$2" ] && echo "Argument required for Ingest URL parameter." && usage -1
              sfx_ingest_url="$2"; shift 2 ;;
           -h)
               usage 0; ;;
           \?) echo "Invalid option: -$1" >&2;
               exit 2;
               ;;
           *) break ;;
       esac
    done
    if [ -n "$insecure" ]; then
        echo "You have entered insecure mode; all curl commands will be executed with the -k 'insecure' parameter."
        confirm
    fi
}

parse_args_wrapper() {
    BASE_DIR=$(cd "$(dirname "$0")" && pwd 2>/dev/null)
    MANAGED_CONF_DIR=${BASE_DIR}/managed_config
    FILTERING_CONF_DIR=${BASE_DIR}/filtering_config

    if [ "$1" = "-h" ]; then
        usage 0
    fi

    if [ "$#" -gt 0 ]; then

        if [ ! "`echo $1 | cut -c1`" = "-" ]; then
            api_token="-t $1"
            raw_api_token=$1
            shift
        fi
    fi

    if [ "$#" -gt 0 ]; then
        parse_args "$@"
    fi

    if [ $interactive -eq 0 ] && [ -z "$api_token" ]; then
        echo "Non-interactive requires the api token"
        usage -1
    fi

    if [ -n "$api_token" ]; then
        api_output=`curl $insecure -d '[]' -H "X-Sf-Token: $raw_api_token" -H "Content-Type:application/json" -X POST $sfx_ingest_url/v2/event 2>/dev/null`
        if [ ! "$api_output" = "\"OK\"" ]; then
            echo "There was a problem with the api token '$raw_api_token' passed in and we were unable to communicate with SignalFx: $api_output"
            echo "Please check your auth token is valid or check your networking."
            exit 1
        fi
    fi

    #determine if the script is being run by root or not
    user=$(whoami)
    if [ "$user" == "root" ]; then
        sudo=""
    else
        sudo="sudo"
    fi
fi


determine_os() {
    #determine hostOS for newer versions of Linux
    hostOS=$(cat /etc/*-release | grep PRETTY_NAME | grep -o '".*"' | sed 's/"//g' | sed -e 's/([^()]*)//g' | sed -e 's/[[:space:]]*$//')
    if [ ! -f /etc/redhat-release ]
    then
	hostOS_2=null_os
    else
	#older versions of RPM based Linux that don't have version in PRETTY_NAME format
	hostOS_2=$(head -c 16 /etc/redhat-release)
    fi

    #determine if the script is being run by root or not
    user=$(whoami)
    if [ "$user" == "root" ]; then
	sudo=""
    else
	sudo="sudo"
    fi
}

#Function to determine the OS to install for from end user input
assign_needed_os() {
    case $selection in
        #REHL/Centos 7.x
        1)
            hostOS="CentOS Linux 7"
        ;;
        #REHL/Centos 6.x
        2)
            hostOS="CentOS Linux 6"
        ;;
        #Amazon Linux
        3)
            hostOS="Amazon Linux (all versions 2014.09 and newer)"
        ;;
        #Ubuntu 15.04
        4)
            hostOS="Ubuntu 15.04"
        ;;
        #Ubuntu 14.04
        5)
            hostOS="Ubuntu 14.04.1 LTS"
        ;;
        #Ubuntu 12.04
        6)
            hostOS="Ubuntu 12.04"
        ;;
        #Debian GNU/Linux 7 (wheezy)
        7)
            hostOS="Debian GNU/Linux 7"
        ;;
        #Debian GNU/Linux 8 (jessie)
        8)
            hostOS="Debian GNU/Linux 8"
        ;;
        *)
        printf "error occurred. Exiting. Please contact support@signalfx.com\n" && exit 0
        ;;
    esac
}

#Validate the users input
validate_os_input() {
if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 && "$selection" -le 10 ]]
    then
        assign_needed_os
elif [ "$selection" == 11 ];
    then
        printf "\nWe currently do not support any other Linux distribution with our collectd packages.
Please visit https://support.signalfx.com/hc/en-us/articles/201094025-Use-collectd for detailed
instructions on how to install collectd for various Linux distributions or contact support@signalfx.com\n" && exit 0
elif [ "$selection" == 0 ];
    then
        printf "\nGood Bye!" && exit 0
else
    printf "\nInvalid user input please make a Distribution selection of 1 through 8.
Enter your Selection: "
    read -r selection < /dev/tty
    validate_os_input
fi
}

#Get end user input for OS to install for
get_os_input() {
	#Ask end user for what OS to install for
	printf "\nWe were unable to automatically determine the version of Linux you are on!
Please enter the number of the OS you wish to install for:
1. RHEL/Centos 7
2. RHEL/Centos 6.x
3. Amazon Linux (all versions 2014.09 and newer)
4. Ubuntu 15.04
5. Ubuntu 14.04
6. Ubuntu 12.04
7. Debian GNU/Linux 7
8. Debian GNU/Linux 8
9. Other
0. Exit
Enter your Selection: "
	read -r selection < /dev/tty

    validate_os_input

}

#RPM Based Linux Functions
#Install function for RPM collectd
install_rpm_collectd_procedure() {
    #install deps
    printf "Installing Dependencies\n"
    $sudo yum -y install $needed_deps

    #download signalfx rpm for collectd
    printf "Downloading SignalFx RPM $needed_rpm\n"
    curl $insecure $needed_rpm -o $needed_rpm_name

    #install signalfx rpm for collectd
    printf "Installing SignalFx RPM\n"
    $sudo yum -y install $needed_rpm_name
    $sudo rm -f $needed_rpm_name
    type setsebool > /dev/null 2>&1 && $sudo setsebool -P collectd_tcp_network_connect on

    #install collectd from signalfx rpm
    printf "Installing collectd\n"
    $sudo yum -y install collectd

    #install base plugins signalfx deems necessary
    printf "Installing base-plugins\n"
    $sudo yum -y install collectd-disk collectd-write_http
}

#Debian Based Linux Functions
#Install function for debian based systems
#install function for debian collectd
install_debian_collectd_procedure() {
    #update apt-get
    printf "Updating apt-get\n"
    $sudo apt-get -y update
    if [ "$stage" = "test" ]; then
        needed_deps="$needed_deps apt-transport-https"
    fi

    #Installing dependent packages to later add signalfx repo
    printf "Installing source package to get SignalFx collectd package\n"
    $sudo apt-get -y install $needed_deps $needed_package_name

    if [ "$stage" = "test" ]; then
        printf "Getting SignalFx collectd package from test repo hosted at SignalFx\n"
        echo "deb [trusted=yes] https://dl.signalfx.com/debs/collectd/${debian_distribution_name}/${stage} /" | $sudo tee /etc/apt/sources.list.d/signalfx_collectd-${stage}-${debian_distribution_name}.list > /dev/null
    else
        #Adding signalfx repo
        printf "Getting SignalFx collectd package\n"
        if [ "$debian_distribution_name" == "wheezy" ] || [ "$debian_distribution_name" == "jessie" ]; then
            $sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $signalfx_public_key_id
            echo "deb ${repo_link} /" | $sudo tee /etc/apt/sources.list.d/signalfx_collectd.list > /dev/null
        else
            $sudo add-apt-repository -y ppa:signalfx/collectd-${stage}
        fi
    fi

    #Updating apt-get to reference the signalfx repo to install collectd
    printf "Updating apt-get to reference new SignalFx package\n"
    $sudo apt-get -y update

    #Installing signalfx collectd package and plugins
    printf "Installing collectd and additional plugins\n"
    $sudo apt-get -y install collectd collectd-core

    #Configuring collectd with basic configuration
}

#take "hostOS" and match it up to OS and assign tasks
perform_install_for_os() {
case $hostOS in
    "CentOS Linux 7")
        needed_rpm=$centos
        needed_rpm_name=$centos_rpm
	    needed_plugin_rpm=$centos_plugin
	    needed_plugin_rpm_name=$centos_plugin_rpm
        printf "Install will proceed for %s\n" "$hostOS"
        confirm
        install_rpm_collectd_procedure
	    install_rpm_plugin_procedure
    ;;
    "CentOS Linux 6")
        needed_rpm=$centos
        needed_rpm_name=$centos_rpm
	    needed_plugin_rpm=$centos_plugin
	    needed_plugin_rpm_name=$centos_plugin_rpm
        printf "Install will proceed for %s\n" "$hostOS"
        confirm
        install_rpm_collectd_procedure
    ;;
    "Amazon Linux AMI"*)
        needed_rpm=$aws_linux
        needed_rpm_name=$aws_linux_rpm
	    needed_plugin_rpm=$aws_linux_plugin
	    needed_plugin_rpm_name=$aws_linux_plugin_rpm
        printf "Install will proceed for %s\n" "$hostOS"
        confirm
        install_rpm_collectd_procedure
    ;;
    "Ubuntu 15.04"*)
        needed_package_name=software-properties-common
        printf "Install will proceed for %s\n" "$hostOS"
        debian_distribution_name="vivid"
        confirm
        install_debian_collectd_procedure
        install_debian_collectd_plugin_procedure
    ;;
    "Ubuntu 14.04"*)
        needed_package_name=software-properties-common
        printf "Install will proceed for %s\n" "$hostOS"
        debian_distribution_name="trusty"
        confirm
        install_debian_collectd_procedure
        install_debian_collectd_plugin_procedure
    ;;
    "Ubuntu 12.04"* | "Ubuntu precise"*)
        needed_package_name=python-software-properties
        printf "Install will proceed for %s\n" "$hostOS"
        debian_distribution_name="precise"
        confirm
        install_debian_collectd_procedure
        install_debian_collectd_plugin_procedure
    ;;
    "Debian GNU/Linux 7")
        needed_package_name="apt-transport-https"
        printf "Install will proceed for %s\n" "$hostOS"
        repo_link=$wheezy_ppa
        debian_distribution_name="wheezy"
        confirm
        install_debian_collectd_procedure
        install_debian_collectd_plugin_procedure
    ;;
    "Debian GNU/Linux 8")
        needed_package_name="apt-transport-https"
        printf "Install will proceed for %s\n" "$hostOS"
        repo_link=$jessie_ppa
        debian_distribution_name="jessie"
        confirm
        install_debian_collectd_procedure
        install_debian_collectd_plugin_procedure
    ;;
    *)
    case $hostOS_2 in
        "CentOS release 6")
            needed_rpm=$centos
            needed_rpm_name=$centos_rpm
            needed_plugin_rpm=$centos_plugin
            needed_plugin_rpm_name=$centos_plugin_rpm
            printf "Install will proceed for %s\n" "$hostOS_2"
            confirm
            install_rpm_collectd_procedure
	        install_rpm_plugin_procedure
        ;;
        "Red Hat Enterpri")
            needed_rpm=$centos
            needed_rpm_name=$centos_rpm
            needed_plugin_rpm=$centos_plugin
            needed_plugin_rpm_name=$centos_plugin_rpm
            printf "Install will proceed for %s\n" "$hostOS"
            install_rpm_collectd_procedure
	        install_rpm_plugin_procedure
        ;;
        *)
            get_os_input
            perform_install_for_os
        ;;
    esac
    ;;
esac
}

vercomp () {
    if [[ $1 == "$2" ]]
    then
        echo 0
        return
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            echo 1
            return
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            echo 2
            return
        fi
    done
    echo 0
}

check_for_err() {
    if [ $? != 0 ]; then
    printf "FAILED\n";
    exit 1;
    else
    printf "$@";
    fi
}

find_installed_collectd(){
   for p in /opt/signalfx-collectd/sbin/collectd /usr/sbin/collectd "/usr/local/sbin/collectd"; do
       if [ -x $p ]; then
           COLLECTD=${p}
           find_collectd_ver
           break;
       fi
   done
}

find_collectd_ver() {
    COLLECTD_VER=$(${COLLECTD} -h | sed -n 's/^collectd \([0-9\.]*\).*/\1/p')
    if [ -z "$COLLECTD_VER" ]; then
        echo "Failed to figure out CollectD version";
        exit 2;
    fi
}

#RPM Based Linux Functions
#Install function for RPM collectd
install_rpm_plugin_procedure() {
    if [ -f /opt/signalfx-collectd-plugin/signalfx_metadata.py ]; then
        printf "SignalFx collectd plugin already installed\n"
        return
    fi
    #download signalfx plugin rpm for collectd
    printf "Downloading SignalFx plugin RPM\n"
    curl $insecure $needed_rpm -o $needed_rpm_name

    #install signalfx rpm for collectd
    printf "Installing SignalFx plugin RPM\n"
    $sudo yum -y install $needed_rpm_name
    $sudo rm -f $needed_rpm_name

    #install collectd from signalfx plugin rpm
    printf "Installing signalfx-collectd-plugin\n"
    $sudo yum -y install signalfx-collectd-plugin
    FOUND=1
}

install_plugin() {

    determine_os

    #take "hostOS" and match it up to OS and assign tasks
    case $hostOS in
	"CentOS Linux 7")
	    printf "Install will proceed for %s\n" "$hostOS"
	    install_rpm_plugin_procedure
	    ;;
	"CentOS Linux 6")
	    needed_plugin_rpm=$centos_plugin
	    needed_plugin_rpm_name=$centos_plugin_rpm
	    printf "Install will proceed for %s\n" "$hostOS"
	    install_rpm_plugin_procedure
	    ;;
	"Amazon Linux AMI"*)
	    printf "Install will proceed for %s\n" "$hostOS"
	    install_rpm_plugin_procedure
	    ;;
    "Debian GNU/Linux 7")
        needed_package_name="apt-transport-https"
        printf "Install will proceed for %s\n" "$hostOS"
        debian_distribution_name="wheezy"
        ;;
    "Debian GNU/Linux 8")
        needed_package_name="apt-transport-https"
        printf "Install will proceed for %s\n" "$hostOS"
        debian_distribution_name="jessie"
        install_debian_collectd_plugin_procedure
        ;;
    "Ubuntu 15.04"*)
        needed_package_name=software-properties-common
        printf "Install will proceed for %s\n" "$hostOS"
        debian_distribution_name="vivid"
        install_debian_collectd_plugin_procedure
    ;;
    "Ubuntu 14.04"*)
        needed_package_name=software-properties-common
        printf "Install will proceed for %s\n" "$hostOS"
        debian_distribution_name="trusty"
        install_debian_collectd_plugin_procedure
    ;;
    "Ubuntu 12.04"* | "Ubuntu precise"*)
        needed_package_name=python-software-properties
        printf "Install will proceed for %s\n" "$hostOS"
        debian_distribution_name="precise"
        install_debian_collectd_plugin_procedure
    ;;
        *)
	    case $hostOS_2 in
		"CentOS release 6")
		    needed_plugin_rpm=$centos_plugin
		    needed_plugin_rpm_name=$centos_plugin_rpm
		    printf "Install will proceed for %s\n" "$hostOS_2"
		    install_rpm_plugin_procedure
		    ;;
        "Red Hat Enterpri")
            needed_plugin_rpm=$centos_plugin
            needed_plugin_rpm_name=$centos_plugin_rpm
            printf "Install will proceed for %s\n" "$hostOS"
            install_rpm_plugin_procedure
            ;;
		*)
		    ;;
	    esac
	    ;;
    esac
    if [ -z "$FOUND" ]; then
	printf "Unsupported OS, will not attempt to install plugin\n"
	NO_PLUGIN=1
    fi
}

#Debian Based Linux Functions
#Install function for debian based systems
install_debian_collectd_plugin_procedure() {
    if [ -f /opt/signalfx-collectd-plugin/signalfx_metadata.py ]; then
        printf "SignalFx collectd plugin already installed\n"
        return
    fi
    #Installing dependent packages to later add signalfx plugin repo
    printf "Installing source package to get SignalFx collectd plugin package\n"
    $sudo apt-get -y install $needed_package_name

    repo_link="https://dl.signalfx.com/debs/signalfx-collectd-plugin/${debian_distribution_name}/${release_type}"
    if [ "$release_type" = "test" ]; then
        printf "Getting SignalFx collectd package from test repo hosted at SignalFx\n"
        echo "deb [trusted=yes] ${repo_link} /" | $sudo tee /etc/apt/sources.list.d/signalfx_collectd_plugin-${release_type}-${debian_distribution_name}.list > /dev/null
    else
        #Adding signalfx repo
        printf "Getting SignalFx collectd package\n"
        if [ "$debian_distribution_name" == "wheezy" ] || [ "$debian_distribution_name" == "jessie" ]; then
            $sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $signalfx_public_key_id
            echo "deb ${repo_link} /" | $sudo tee /etc/apt/sources.list.d/signalfx_collectd_plugin-${release_type}-${debian_distribution}.list > /dev/null
        else
            $sudo add-apt-repository -y ppa:signalfx/collectd-plugin-${release_type}
        fi
    fi


    #Updating apt-get to reference the signalfx repo to install plugin
    printf "Updating apt-get to reference new SignalFx plugin package\n"
    $sudo apt-get -y update

    #Installing signalfx collectd package and plugins
    printf "Installing collectd and additional plugins\n"
    $sudo apt-get -y install signalfx-collectd-plugin
    FOUND=1
}

sfx_ingest_url="https://ingest.signalfx.com"
insecure=""

get_logfile() {
    LOGTO="\"/var/log/signalfx-collectd.log\""
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$NAME" == "CentOS Linux" -a "$VERSION_ID" == "7" ]; then
            LOGTO="stdout";
        fi
    fi
}

download_configs() {
    curl -sSL $insecure https://dl.signalfx.com/

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
        -e "s#URL.*#URL \"${sfx_ingest_url}/v1/collectd${EXTRA_DIMS}\"#g" \
        "${MANAGED_CONF_DIR}/10-signalfx.conf" > "${COLLECTD_MANAGED_CONFIG_DIR}/10-signalfx.conf"
    check_for_err "Success\n";
}

install_write_http_plugin(){
    install_plugin_common

    printf "Fixing write_http plugin configuration.."
    sed -e "s#%%%API_TOKEN%%%#${API_TOKEN}#g" \
        -e "s#%%%INGEST_HOST%%%#${sfx_ingest_url}#g" \
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

find_collectd(){
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


configure_collectd() {
    find_collectd
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


#Determine the OS and install/configure collectd to send metrics to SignalFx
parse_args_wrapper "$@"
determine_os

perform_install_for_os
configure_collectd
