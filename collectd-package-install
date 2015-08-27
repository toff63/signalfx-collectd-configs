#! /bin/bash

#variables used
selection=0
needed_rpm=null_rpm_link
needed_rpm_name=null_rpm_name
needed_package_name=null_package_name
api_token=$1

#rpm file variables
centos_7_rpm="SignalFx-RPMs-centos-7-release-1.0-0.noarch.rpm"
centos_6_rpm="SignalFx-RPMs-centos-6-release-1.0-0.noarch.rpm"
centos_5_rpm="SignalFx-RPMs-centos-5-release-1.0-0.noarch.rpm"
aws_linux_2014_09_rpm="SignalFx-RPMs-AWS_EC2_Linux_2014_09-release-1.0-0.noarch.rpm"
aws_linux_2015_03_rpm="SignalFx-RPMs-AWS_EC2_Linux_2015_03-release-1.0-0.noarch.rpm"

#download location variables
centos_7="https://dl.signalfx.com/rpms/SignalFx-rpms/release/${centos_5_rpm}"
centos_6="https://dl.signalfx.com/rpms/SignalFx-rpms/release/${centos_6_rpm}"
centos_5="https://s3.amazonaws.com/public-downloads--signalfuse-com/rpms/SignalFx-rpms/release/${centos_5_rpm}"
aws_linux_2014_09="https://dl.signalfx.com/rpms/SignalFx-rpms/release/${aws_linux_2014_09_rpm}"
aws_linux_2015_03="https://dl.signalfx.com/rpms/SignalFx-rpms/release/${aws_linux_2015_03_rpm}"

#determine hostOS for newer versions of Linux
hostOS=$(cat /etc/*-release | grep PRETTY_NAME | grep -o '".*"' | sed 's/"//g' | sed -e 's/([^()]*)//g' | sed -e 's/[[:space:]]*$//') 
if [ ! -f /etc/redhat-release ]
   then
      hostOS_2=null_os
   else
   	  #older versions of RPM based Linux that don't have version in PRETTY_NAME format
      hostOS_2=$(head -c 16 /etc/redhat-release) 
fi

#Functions used throughout
basic_collectd() 
{
   printf "Starting Configuration of collectd... \n"
   if [ -z "$api_token" ]
      then
        #url to configure collectd asks for host-name and username:password
        curl -sSL https://dl.signalfx.com/collectd-simple | sudo bash -s --
   else
       #url to configure collectd asks for host-name	
       curl -sSL https://dl.signalfx.com/collectd-simple | sudo bash -s -- -t "$api_token"
   fi
}

#Function to determine the OS to install for from end user input
assign_needed_os()
{
    case $selection in
        #REHL/Centos 7.x    
        1)
            hostOS="CentOS Linux 7"
        ;;
        #REHL/Centos 6.x
        2)
            hostOS="CentOS Linux 6"
        ;;
        #REHL/Centos 5.x
        3)
            hostOS="CentOS release 5"
        ;;
        #Amazon Linux 2015.03
        4)
            hostOS="Amazon Linux AMI 2015.03"
        ;;
        #Amazon Linux 2014.09
        5)
            hostOS="Amazon Linux AMI 2014.09"
        ;;
        #Ubuntu 15.04
        6)
            hostOS="Ubuntu 15.04"
        ;;
        #Ubuntu 14.04
        7)
            hostOS="Ubuntu 14.04.1 LTS"
        ;;
        #Ubuntu 12.04
        8)  
            hostOS="Ubuntu 12.04"
        ;;
        *)
        printf "error occurred. Exiting. Please contact support@signalfx.com\n" && exit 0
        ;;
    esac
}

#Get end user input for OS to install for
get_os_input() 
{
	#Ask end user for what OS to install for
	printf "\nWe were unable to automatically determine the version of Linux you are on!
Please enter the number of the OS you wish to install for:
1. RHEL/Centos 7
2. RHEL/Centos 6.x
3. REHL/Centos 5.x
4. Amazon Linux 2015.03
5. Amazon Linux 2014.09
6. Ubuntu 15.04
7. Ubuntu 14.04
8. Ubuntu 12.04
9. Other\n"
	read -r selection

	if [ "$selection" -eq 9 ]
		then
			printf "\nWe currently do not support any other OS with our collectd packages. 
Please visit ~LINK~ for detailed instructions on how to install 
collectd for various Operating Systems.\n" && exit 0
	
	else
			assign_needed_os
	fi
}

#confirm user input (yes or no)
confirm ()
{
    read -r -p "Is this correct? [y/N] " response
    if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
        then
    return
    else
        exit 0
    fi
}

#RPM Based Linux Functions
#Install function for RPM collectd
install_rpm_collectd_procedure() 
{
    #update wget
    printf "Installing wget\n"
    sudo yum -y install wget 
    
    #download signalfx rpm for collectd
    printf "Downloading SignalFx RPM\n"
    wget $needed_rpm 
    
    #install signalfx rpm for collectd
    printf "Installing SignalFx RPM\n"
    sudo yum -y install $needed_rpm_name  
    
    #install collectd from signalfx rpm
    printf "Installing collectd\n"
    sudo yum -y install collectd  
    
    #install base plugins signalfx deems necessary
    printf "Installing base-plugins\n"
    sudo yum -y install collectd-disk collectd-write_http 
    
    basic_collectd
}

#Install function for centos 5.x
install_rpm_RHELcentos5.x_procedure()
{
    #installing simple-json
    printf "Installing Simple-Json\n"
    sudo yum -y install python-simplejson
    
    #installing/updating openssl
    printf "Install Openssl\n"
    sudo yum -y install openssl
    
    #installing wget
    printf "Installing wget\n"
    sudo yum -y install wget
    
    #downloading signalfx rpm
    printf "Downloading SignalFx RPM\n"
    wget $centos_5

    #install signalfx rpm
    printf "Installing SignalFx RPM\n"
    sudo yum -y install --nogpgcheck $centos_5_rpm
    
    #install collectd from signalfx rpm
    printf "Installing collectd\n"
    sudo yum -y install collectd 
    
    #install base plugins signalfx deems necessary
    printf "Installing baseplugins\n"
    sudo yum -y install collectd-disk collectd-write_http 

    #configure collectd to send metrics to signalfx
    if [ -z "$api_token" ]
        then
            printf "We need you to provide the API Token for your org. This can be found @ https://app.signalfx.com/#/myprofile \n"
            printf "Please enter your API Token: \n"
    
            read -r api_token
    
            printf "Starting Configuration of collectd... \n"
            curl https://s3.amazonaws.com/public-downloads--signalfuse-com/collectd-simple | sudo bash -s -- -t "$api_token"
        else
    	   curl https://s3.amazonaws.com/public-downloads--signalfuse-com/collectd-simple  | sudo bash -s -- -t "$api_token"
    fi
}

#Debian Based Linux Functions
#Install function for debian based systems
install_debian_collectd_procedure() #install function for debian collectd
{
    #update apt-get
    printf "Updating apt-get\n"
    sudo apt-get -y update

    #Installing dependent packages to later add signalfx repo
    printf "Installing source package to get SignalFx collectd package\n"
    sudo apt-get -y install $needed_package_name 
    
    #Adding signalfx repo
    printf "Getting SignalFx collectd package\n"
    sudo add-apt-repository -y ppa:signalfx/collectd-release
    
    #Updating apt-get to reference the signalfx repo to install collectd
    printf "Updating apt-get to reference new SignalFx package\n"
    sudo apt-get -y update
    
    #Installing signalfx collectd package and plugins
    printf "Installing collectd and additional plugins\n"
    sudo apt-get -y install collectd 
    
    #Configuring collectd with basic configuration
    basic_collectd
}

#take "hostOS" and match it up to OS and assign tasks
perform_install_for_os()
{
case $hostOS in 
    "CentOS Linux 7")
        needed_rpm=$centos_7
        needed_rpm_name=$centos_7_rpm
        printf "Install will proceed for %s\n" "$hostOS"
        confirm
        install_rpm_collectd_procedure
    ;;
    "CentOS Linux 6")
        needed_rpm=$centos_6
        needed_rpm_name=$centos_6_rpm
        printf "Install will proceed for %s\n" "$hostOS"
        confirm
        install_rpm_collectd_procedure
    ;;
    "Amazon Linux AMI 2014.09") 
        needed_rpm=$aws_linux_2014_09
        needed_rpm_name=$aws_linux_2014_09_rpm
        printf "Install will proceed for %s\n" "$hostOS"
        confirm
        install_rpm_collectd_procedure
    ;;
    "Amazon Linux AMI 2015.03") 
        needed_rpm=$aws_linux_2015_03
        needed_rpm_name=$aws_linux_2015_03_rpm
        printf "Install will proceed for %s\n" "$hostOS"
        confirm
        install_rpm_collectd_procedure
    ;;
    "Ubuntu 15.04" | "Ubuntu 14.04.1 LTS") 
        needed_package_name=software-properties-common
        printf "Install will proceed for %s\n" "$hostOS"
        confirm
        install_debian_collectd_procedure
    ;;
    "Ubuntu 12.04")
        needed_package_name=python-software-properties
        printf "Install will proceed for %s\n" "$hostOS"
        confirm
        install_debian_collectd_procedure
    ;;
    *)
    case $hostOS_2 in 
        "CentOS release 6") 
            needed_rpm=$centos_6
            needed_rpm_name=$centos_6_rpm
            printf "Install will proceed for %s\n" "$hostOS_2"
            confirm
            install_rpm_collectd_procedure
        ;;
        "CentOS release 5")    
            needed_rpm=$centos_5
            needed_rpm_name=$centos_5_rpm
            printf "Install will proceed for %s\n" "$hostOS_2"
            confirm
            install_rpm_RHELcentos5.x_procedure
        ;;
        *) 
            get_os_input
            perform_install_for_os
        ;;
    esac
    ;;
esac
}

#Determine the OS and install/configure collectd to send metrics to SignalFx
perform_install_for_os

