#!/bin/bash -x

export L2_config_file=/etc/neutron/plugin.ini 
export L3_config_file=/etc/neutron/l3_agent.ini 
export ML2_config_file=/etc/neutron/plugins/ml2/ml2_conf.ini
export OVS_config_file=/etc/neutron/plugins/ml2/openvswitch_agent.ini

create_net_infra () 
{
	# parse arguments
	NAME=${1:?"Please specify the name"}
	IF=${2:?"Please specify interface name"}
	MTU=${3:-"1500"}
	PORT_RANGE=${9:-""}
	# set names for new devices using our name
	OVS_BR=br-${NAME}
	PHYSNET=physnet-${NAME}

	# 2.1 create dedicated ovs bridge for new ext network
	ovs-vsctl add-br ${OVS_BR}
	
	# 2.2 add external interface to the ovs bridge 
	ovs-vsctl add-port ${OVS_BR} ${IF}

	# 2.3 add new physnet in bridge_map with appropriate MTU
	if ! fgrep ${PHYSNET} ${OVS_config_file}; then
		LINE=$(awk '/^bridge_mappings/ {print NR}' ${OVS_config_file}) 
		sed -i "${LINE} s/$/,${PHYSNET}:${OVS_BR}/" ${OVS_config_file}
	fi
		
	
	# 1.2 update configuration for the defualt current external network net04_ex
	if ! fgrep ${PHYSNET} ${L2_config_file}; then
		# Adding new physnet mtu to L2
		LINE=$(awk '/^physical_network_mtus/ {print NR}' ${L2_config_file}) 
		sed -i "${LINE} s/$/,${PHYSNET}:${MTU}/" ${L2_config_file}
		
		# Adding new network_vlan_ranges to L2
		LINE=$(awk '/^network_vlan_ranges/ {print NR}' ${L2_config_file}) 
		sed -i "${LINE} s/$/,${PHYSNET}:${PORT_RANGE}/" ${L2_config_file}
				
	fi

	if ! fgrep ${PHYSNET} ${ML2_config_file}; then
		
		# Adding new physnet mtu to L2
		LINE=$(awk '/^physical_network_mtus/ {print NR}' ${ML2_config_file}) 
		sed -i "${LINE} s/$/,${PHYSNET}:${MTU}/" ${ML2_config_file}
		
		# Adding new network_vlan_ranges to L2
		LINE=$(awk '/^network_vlan_ranges/ {print NR}' ${ML2_config_file}) 
		sed -i "${LINE} s/$/,${PHYSNET}:${PORT_RANGE}/" ${ML2_config_file}
		
	fi

}


create_net_infra $@
