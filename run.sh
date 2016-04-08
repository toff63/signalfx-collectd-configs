#!/bin/sh

name=$0
script="collectd-package-install.sh"
parse_args(){
    while [ $# -gt 0 ]; do
        case $1 in
 	   --configure-only)
            script="configure_collectd.sh"; shift 1 ;;
           *) shift 1; ;;
       esac
    done
}

parse_args "$@"

./$script "$@"

