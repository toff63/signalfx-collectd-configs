#!/bin/sh
makeself --tar-extra '-X makeself.excludes' `pwd` signalfx-configure-collectd.sh "SignalFx CollectD configuration tool" ./install.sh
