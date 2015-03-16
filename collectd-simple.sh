#!/bin/bash

dlfile=$(mktemp -t sfx-download-XXXXXX)

clean_up() {
 rm $dlfile;
 trap 0 
 exit;
}

trap clean_up 0 1 2 3 15
curl -sSL $(curl -s https://api.github.com/repos/signalfx/signalfx-collectd-configs/releases | grep browser_download_url | head -n 1 | cut -d '"' -f 4) > $dlfile

/bin/bash $dlfile -- "$@"

