# SignalFx CollectD configs

## About

A collection of [collectd](http://www.collectd.org) configs that work
well with SignalFx.

## Installation

```
$ git clone https://github.com/signalfx/signalfx-collectd-configs.git
$ cd signalfx-collectd-configs/
$ ./install.sh /path/to/collectd
```

If you want to add another config, simply copy it into your collectd
configuration directory's `managed_config` sub-directory:

```
$ cp managed_config/10-bob.conf /etc/collectd.d/managed_config/
```

In most cases, you'll need to edit the file to configure credentials,
paths or endpoints. Read the instructions at the top of each config file
for how to use or debug it.
