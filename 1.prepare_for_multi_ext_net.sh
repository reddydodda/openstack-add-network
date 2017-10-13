#!/bin/bash

L3_config_file=/etc/neutron/l3_agent.ini
OVS_config_file=/etc/neutron/plugins/ml2/openvswitch_agent.ini
DEFAULT_BR_EX="br-floating"
DEFAULT_PHYSNET="physnet1"
# parse arguments
NAME=${1:?"Please specify the name"}
IF=${2:?"Please specify interface name"}

prepare_for_multi_ext_nets ()
{
	# 1.1 clear gateway_external_network_id parameters in /etc/neutron/l3_agent.ini
	if ! grep "^gateway_external_network_id" ${L3_config_file}; then
		sed -i "/^#gateway_external_network_id/a gateway_external_network_id =" ${L3_config_file}
	fi

		# set names for new devices using our name
		OVS_BR=br-${NAME}
		PHYSNET=physnet-${NAME}

		# 2.1 create dedicated ovs bridge for new ext network
		ovs-vsctl add-br ${OVS_BR}

		# 2.2 add external interface to the ovs bridge
		ovs-vsctl add-port ${OVS_BR} ${IF}

		# 2.3 add new physnet in bridge_map with appropriate MTU ( both controller and compute )
		if ! fgrep ${PHYSNET} ${OVS_config_file}; then
			LINE=$(awk '/^bridge_mappings/ {print NR}' ${OVS_config_file})
			sed -i "${LINE} s/$/,${PHYSNET}:${OVS_BR}/" ${OVS_config_file}
		fi
	# 1.3 update configuration of the current external network net04_ext in DB
	#if mysql -e "show status;" &> /dev/null; then
	#	mysql neutron -e "update  ml2_network_segments set network_type='flat', physical_network='${DEFAULT_PHYSNET}' where network_type='local';"
	#fi
}

prepare_for_multi_ext_nets
