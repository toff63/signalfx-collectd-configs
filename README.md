# SignalFx CollectD installer

The installer/configurator for collectd

curl -sSL https://dl.signalfx.com/collectd-install | bash -s YOUR_API_TOKEN

You can go non-interactive with

curl -sSL https://dl.signalfx.com/collectd-install | bash -s YOUR_API_TOKEN -y

You can provide your own collectd and just use the script to configure it with


curl -sSL https://dl.signalfx.com/collectd-install | bash -s YOUR_API_TOKEN --configure-only
