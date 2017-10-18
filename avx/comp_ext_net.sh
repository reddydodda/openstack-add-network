#!/bin/bash

L3_config_file=/etc/neutron/l3_agent.ini
OVS_config_file=/etc/neutron/plugins/ml2/openvswitch_agent.ini
DEFAULT_BR_EX="br-floating"
DEFAULT_PHYSNET="physnet1"
# parse arguments
NAME1="ext2"
NAME2="ext3"
CTRL_IF1="enp1s0f1"
CTRL_IF2="enp1s0f0"
#Compute Node
COMP_IF1="eno3"
COMP_IF2="eno4"


prepare_for_multi_ext_comp ()
{
	# 1.1 clear gateway_external_network_id parameters in /etc/neutron/l3_agent.ini
	if ! grep "^gateway_external_network_id" ${L3_config_file}; then
		sed -i "/^#gateway_external_network_id/a gateway_external_network_id =" ${L3_config_file}
	fi
		# Copy Interfaces
		printf "auto eno3 \niface eno3 inet manual" > /etc/network/interfaces.d/ifcfg-eno3
		printf "auto eno4 \niface eno4 inet manual" > /etc/network/interfaces.d/ifcfg-eno4
		ifup eno3
		ifup eno4
		
		PHYSNET1=physnet-ext2
		PHYSNET2=physnet-ext3

		# 2.1 create dedicated ovs bridge for new ext network
		ovs-vsctl add-br br-ext2
		ovs-vsctl add-br br-ext3
		
		# 2.2 add external interface to the ovs bridge
		ovs-vsctl add-port br-ext2 eno3
		ovs-vsctl add-port br-ext3 eno4
		
		# 2.3 add new physnet in bridge_map with appropriate MTU ( both controller and compute )
		if ! fgrep ${PHYSNET1} ${OVS_config_file}; then
			LINE=$(awk '/^bridge_mappings/ {print NR}' ${OVS_config_file})
			sed -i "${LINE} s/$/,${PHYSNET1}:br-ext2/" ${OVS_config_file}
		fi
		if ! fgrep ${PHYSNET2} ${OVS_config_file}; then
			LINE=$(awk '/^bridge_mappings/ {print NR}' ${OVS_config_file})
			sed -i "${LINE} s/$/,${PHYSNET2}:br-ext3/" ${OVS_config_file}
		fi
		
		# 1.1 add served host memory
		if grep "^reserved_host_memory_mb" ${nova_config_file}; then
			sed -i "/^reserved_host_memory_mb/c\reserved_host_memory_mb = 40960" ${nova_config_file}
		fi
		
		# Restart services
		service neutron-l3-agent restart
		service neutron-openvswitch-agent restart
		service nova-compute restart
		
}


prepare_for_multi_ext_comp

