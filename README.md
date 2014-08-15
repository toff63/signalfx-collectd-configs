SignalFuse collectd configs
===========================

About
-----

A collection of collectd configs that work well with SignalFuse.

Installation
------------

  ```
  git clone https://github.com/signalfx/signalfx-collectd-configs.git /opt
  cp /opt/collectd.conf /etc/collectd.d/collectd.conf
  mkdir /etc/collectd.d/managed_config
  cp /opt/signalfx-collectd-configs/managed_config/10-bob.conf /etc/collectd.d/managed_config/
  ```
