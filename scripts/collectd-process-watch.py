#!/usr/bin/python

# script to send process-specific metrics to collectd
# writes in collectd text protocol format

import os
import psutil
import time
from datetime import datetime
import sys

###   CONFIG   ###
DEFAULT_INTERVAL = 10
DEFAULT_HOSTNAME = 'localhost'
PLUGIN_NAME = 'processwatch'
MIN_RUN_INTERVAL = 30
MIN_CPU_USAGE_PERCENT = 25.0
MIN_MEM_USAGE_PERCENT = 25.0
### END CONFIG ###

###   DEBUG    ###
DEBUG_DO_FILTER_PROCESSES = False	# True by default
DEBUG_OUTPUT_LOG = True			# False by default
DEBUG_OUTPUT_LOGFILE = '/tmp/collectd_output.log'
### END DEBUG  ###


def get_processes_info():
    ACCESS_DENIED = ''
    pmaps = {}
    for p in psutil.process_iter():
        pmap = {}
        try:
            pinfo = p.as_dict(ad_value=ACCESS_DENIED)
        except psutil.NoSuchProcess:
            # it went away
            continue
        pruntime = time.time() - pinfo['create_time']
        pcpupct = pinfo['cpu_percent']
        pmempct = round(pinfo['memory_percent'], 1)
        pio = pinfo.get('io_counters', ACCESS_DENIED)
        if DEBUG_DO_FILTER_PROCESSES == False or \
           (pruntime > MIN_RUN_INTERVAL and
            (pcpupct > MIN_CPU_USAGE_PERCENT or pmempct > MIN_MEM_USAGE_PERCENT)):
            pmap['pcpupct'] = pcpupct
            pmap['pmempct'] = pmempct
            pmap['pruntime'] = pruntime
            if pio != ACCESS_DENIED:
                pmap['pbreads'] = pio.read_bytes
                pmap['pbwrites'] = pio.write_bytes
            # we are using these as separators in the output line
            pname = pinfo['name'].replace('/','_').replace('-','_')
            pmaps[pname] = pmap
    return pmaps


def main():
    HOSTNAME = os.getenv('COLLECTD_HOSTNAME', DEFAULT_HOSTNAME)
    INTERVAL = float(os.getenv('COLLECTD_INTERVAL', DEFAULT_INTERVAL))

    dlogfd = None
    if DEBUG_OUTPUT_LOG == True:
        dlogfd = open(DEBUG_OUTPUT_LOGFILE, 'a')

    while True:
        pmaps = get_processes_info()
        for pname,pmap in pmaps.iteritems():
            for metric,val in pmap.iteritems():
                # format:
                # host "/" plugin ["-" plugin instance] "/" type ["-" type instance]
                plugin_str = "%s/%s-%s/" % (HOSTNAME, PLUGIN_NAME, pname)
                out_cmd = "PUTVAL %s%s interval=%.2f N:%s" % (plugin_str, metric, INTERVAL, val)
                print out_cmd
                if DEBUG_OUTPUT_LOG == True:
                    dlogfd.write(str(datetime.now()) + ': ' + out_cmd + '\n')
                # event notification
                outnotif_cmd = "PUTNOTIF severity=okay time=%s message=%s:%.2f" % (int(time.time()), metric, val)
                print outnotif_cmd
                if DEBUG_OUTPUT_LOG == True:
                    dlogfd.write(str(datetime.now()) + ': ' + outnotif_cmd + '\n')
        if DEBUG_OUTPUT_LOG == True:
            dlogfd.write('-----' + '\n')
        time.sleep(INTERVAL)

    if DEBUG_OUTPUT_LOG == True:
        dlogfd.close()


if __name__ == "__main__":
    main()
