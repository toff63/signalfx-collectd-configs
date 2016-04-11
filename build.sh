#!/bin/sh

set -ex

rm -rf managed_config collectd.conf.tmpl
mkdir -p managed_config

for x in collectd-signalfx/10-signalfx.conf collectd-write_http/10-write_http-plugin.conf collectd-aggregation/10-aggregation-cpu.conf; do
	curl -sSL "https://raw.githubusercontent.com/signalfx/integrations/master/${x}" > managed_config/`basename $x`
done
curl -sSL "https://raw.githubusercontent.com/signalfx/integrations/master/collectd/collectd.conf.tmpl" > collectd.conf.tmpl

tar -cvzf install-files.tgz managed_config filtering_config collectd.conf.tmpl get_aws_unique_id

aws s3 cp install.sh s3://public-downloads--signalfuse-com/collectd-install-test --cache-control="max-age=0, no-cache"
aws s3 cp install-files.tgz s3://public-downloads--signalfuse-com/install-files-test.tgz --cache-control="max-age=0, no-cache"
