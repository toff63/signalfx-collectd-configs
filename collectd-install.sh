#!/bin/bash

dlfile=$(mktemp -t sfx-download-XXXXXX)

insecure=""
local=0

parse_args(){
    while [ $# -gt 0 ]; do
        case $1 in
           --local)
              local=1
              shift 1 ;;
           --insecure)
              insecure="-k"
              shift 1 ;;
           *)
           shift 1 ;;
       esac
    done
}

clean_up() {
 rm $dlfile;
 trap 0 
 exit;
}

trap clean_up 0 1 2 3 15
parse_args "$@"
if [ $local -eq 1 ]; then
  ./create_installer.sh
  /bin/bash collectd-package-install "$@"
else
  curl $insecure -sSL $(curl $insecure -s https://api.github.com/repos/signalfx/signalfx-collectd-configs/releases | grep browser_download_url | grep "collectd-package-install" | head -n 1 | cut -d '"' -f 4) > $dlfile
fi

/bin/bash $dlfile "$@"
