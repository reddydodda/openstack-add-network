#!/bin/bash

nova_config_file=/etc/nova/nova.conf
# parse arguments
NAME=${1:?"Please specify the name"}
IF=${2:?"Please specify interface name"}

prepare_for_host_mem ()
{
	# 1.1 add served host memory
	if grep "^reserved_host_memory_mb" ${nova_config_file}; then
		sed -i "/^reserved_host_memory_mb/c\reserved_host_memory_mb = 40960" ${nova_config_file}
	fi

}

prepare_for_host_mem
