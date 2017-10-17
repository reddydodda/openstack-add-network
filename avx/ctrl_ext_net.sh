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


prepare_for_multi_ext_ctrl ()
{
	# 1.1 clear gateway_external_network_id parameters in /etc/neutron/l3_agent.ini
	if ! grep "^gateway_external_network_id" ${L3_config_file}; then
		sed -i "/^#gateway_external_network_id/a gateway_external_network_id =" ${L3_config_file}
	fi
	
		#Copy Interfaces 
		
		printf "auto enp1s0f0 \niface enp1s0f0 inet manual" > /etc/network/interfaces.d/ifcfg-enp1s0f0
		printf "auto enp1s0f1 \niface enp1s0f1 inet manual" > /etc/network/interfaces.d/ifcfg-enp1s0f1
		if up enp1s0f0
		if up enp1s0f1
		
		PHYSNET1=physnet-ext2
		PHYSNET2=physnet-ext3

		# 2.1 create dedicated ovs bridge for new ext network
		ovs-vsctl add-br br-ext2
		ovs-vsctl add-br br-ext3
		
		# 2.2 add external interface to the ovs bridge
		ovs-vsctl add-port br-ext2 enp1s0f1
		ovs-vsctl add-port br-ext3 enp1s0f0
		
		# 2.3 add new physnet in bridge_map with appropriate MTU ( both controller and compute )
		if ! fgrep ${PHYSNET1} ${OVS_config_file}; then
			LINE=$(awk '/^bridge_mappings/ {print NR}' ${OVS_config_file})
			sed -i "${LINE} s/$/,${PHYSNET1}:br-ext2/" ${OVS_config_file}
		fi
		if ! fgrep ${PHYSNET2} ${OVS_config_file}; then
			LINE=$(awk '/^bridge_mappings/ {print NR}' ${OVS_config_file})
			sed -i "${LINE} s/$/,${PHYSNET2}:br-ext3/" ${OVS_config_file}
		fi
		
		# 1.2 update configuration for the defualt current external network net04_ex
		if ! fgrep ${PHYSNET1} ${L2_config_file}; then
			# Adding new physnet mtu to L2 ( only controller )
			LINE=$(awk '/^physical_network_mtus/ {print NR}' ${L2_config_file})
			sed -i "${LINE} s/$/,${PHYSNET1}:1500/" ${L2_config_file}

			# Adding new network_vlan_ranges to L2 ( only controller )
			LINE=$(awk '/^network_vlan_ranges/ {print NR}' ${L2_config_file})
			sed -i "${LINE} s/$/,${PHYSNET1}:296:297/" ${L2_config_file}
		fi
		
		if ! fgrep ${PHYSNET2} ${L2_config_file}; then
			# Adding new physnet mtu to L2 ( only controller )
			LINE=$(awk '/^physical_network_mtus/ {print NR}' ${L2_config_file})
			sed -i "${LINE} s/$/,${PHYSNET2}:1500/" ${L2_config_file}

			# Adding new network_vlan_ranges to L2 ( only controller )
			LINE=$(awk '/^network_vlan_ranges/ {print NR}' ${L2_config_file})
			sed -i "${LINE} s/$/,${PHYSNET2}:298:299/" ${L2_config_file}
		fi

		# Restart Neutron Services
		pcs resource disable clone_neutron-l3-agent
		pcs resource enable clone_neutron-l3-agent
		service neutron-openvswitch-agent restart
		
}


prepare_for_multi_ext_ctrl

