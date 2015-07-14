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

## Releasing

To release the configuration script *signalfx-configure-collectd.sh*:
 1. run ./create_installer.sh
 2. Go to [signalfx-collectd-configs/releases](https://github.com/signalfx-collectd-configs/releases) and draft a new release. 
 3. The git tag and release should both be title v\<version number\> e.g. v0.18 
 4. Document the changes in the release in the release notes
 5. Upload the *signalfx-configure-collectd.sh* you just created
 6. Publish the release
