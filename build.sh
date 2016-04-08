#!/bin/sh

set -ex

rm -rf managed_config *.conf install.sh
mkdir -p managed_config

for x in collectd-signalfx/10-signalfx.conf collectd-write_http/10-write_http-plugin.conf collectd-aggregation/10-aggregation-cpu.conf; do
	curl -sSL "https://raw.githubusercontent.com/signalfx/integrations/master/${x}" > managed_config/`basename $x`
done
curl -sSL "https://raw.githubusercontent.com/signalfx/integrations/master/collectd/collectd.conf.tmpl" > collectd.conf.tmpl

./create_installer.sh
