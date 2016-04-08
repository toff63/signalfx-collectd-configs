#!/bin/bash
SCRIPTDIR=$(cd $(dirname $0) 2>/dev/null && pwd)

cd ${SCRIPTDIR}
./makeself --nox11 --tar-extra '-X makeself.excludes' `pwd` install.sh "SignalFx CollectD configuration tool" ./run.sh
