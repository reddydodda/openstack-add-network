#!/bin/bash -x

export L2_config_file=/etc/neutron/plugin.ini 
export L3_config_file=/etc/neutron/l3_agent.ini 

create_net_infra () 
{
	# parse arguments
	NAME=${1:?"Please specify the name"}
	IF=${2:?"Please specify interface name"}
	MTU=${3:-"1500"}
	# set names for new devices using our name
	OVS_BR=br-${NAME}
	PHYSNET=physnet-${NAME}

	# 2.1 create dedicated ovs bridge for new ext network
	ovs-vsctl add-br ${OVS_BR}
	
	# 2.2 add external interface to the ovs bridge 
	ovs-vsctl add-port ${OVS_BR} ${IF}

	# 2.3 add new physnet in bridge_map with appropriate MTU
	if ! fgrep ${PHYSNET} ${L2_config_file}; then
		LINE=$(awk '/^bridge_mappings/ {print NR}' ${L2_config_file}) 
		sed -i "${LINE} s/$/,${PHYSNET}:${OVS_BR}/" ${L2_config_file}
		LINE=$(awk '/^physical_network_mtus/ {print NR}' ${L2_config_file}) 
		sed -i "${LINE} s/$/,${PHYSNET}:${MTU}/" ${L2_config_file}
	fi
}


create_net_infra $@
