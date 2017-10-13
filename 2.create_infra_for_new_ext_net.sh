#!/bin/bash -x

export L2_config_file=/etc/neutron/plugins/ml2/ml2_conf.ini
export L3_config_file=/etc/neutron/l3_agent.ini
export OVS_config_file=/etc/neutron/plugins/ml2/openvswitch_agent.ini

create_net_infra ()
{
	# parse arguments
	NAME=${1:?"Please specify the name"}
	MTU=${2:-"1500"}
	PORT_RANGE=${3:-""}
	# set names for new devices using our name
	PHYSNET=physnet-${NAME}


	# 1.2 update configuration for the defualt current external network net04_ex
	if ! fgrep ${PHYSNET} ${L2_config_file}; then
		# Adding new physnet mtu to L2 ( only controller )
		LINE=$(awk '/^physical_network_mtus/ {print NR}' ${L2_config_file})
		sed -i "${LINE} s/$/,${PHYSNET}:${MTU}/" ${L2_config_file}

		# Adding new network_vlan_ranges to L2 ( only controller )
		LINE=$(awk '/^network_vlan_ranges/ {print NR}' ${L2_config_file})
		sed -i "${LINE} s/$/,${PHYSNET}:${PORT_RANGE}/" ${L2_config_file}

	fi


}


create_net_infra $@
