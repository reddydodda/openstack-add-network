#!/bin/bash

export L2_config_file=/etc/neutron/plugins/ml2/ml2_conf.ini 
export L3_config_file=/etc/neutron/l3_agent.ini 
export DEFAULT_BR_EX="br-floating"
export DEFAULT_PHYSNET="physnet-ex"

# restart service by killing with SIGKILL if it exist and then waiting it back
restart_service()
{
	SERVICE=${1:?"Please specify service"}
	PROCESS=${2:-$SERVICE}
	SERVICE_TYPE=${3:-"UPSTART"}
	if ps aux | grep -v grep | grep "/${PROCESS}"; then
		case ${SERVICE_TYPE} in
		"UPSTART" )
			initctl restart ${SERVICE};;
		"PACEMAKER" )
			killall -9 ${PROCESS};
			pcs resource debug-start ${SERVICE};;
		esac
		while ! ps aux | grep -v grep | grep  "/${PROCESS}"; do echo "waiting service ${SERVICE} back..."; sleep 1; done; 
	fi
}

# restart neutron services
restart_neutron_services ()
{
	if pcs status &>/dev/null; then
		initctl restart neutron-server
		#restart_service neutron-server
		#restart_service p_neutron-l3-agent neutron-l3-agent PACEMAKER
		#restart_service p_neutron-plugin-openvswitch-agent neutron-openvswitch-agent PACEMAKER
	else
		initctl restart neutron-l3-agent
		initctl restart neutron-plugin-openvswitch-agent
		#restart_service neutron-l3-agent neutron-l3-agent
		#restart_service neutron-plugin-openvswitch-agent neutron-openvswitch-agent
	fi
}

prepare_for_multi_ext_nets ()
{
	# clear gateway_external_network_id and external_network_bridge parameters in /etc/neutron/l3_agent.ini
	if ! grep "^gateway_external_network_id" ${L3_config_file}; then
		sed -i "/^# gateway_external_network_id/a gateway_external_network_id =" ${L3_config_file}
	fi
	sed -i "/^external_network_bridge/c external_network_bridge =" ${L3_config_file}

	# update configuration for the defualt current external network net04_ex
	grep "^bridge_mappings" /etc/neutron/plugins/ml2/ml2_conf.ini | grep ${DEFAULT_BR_EX}
	if (( 0 != $? )); then
		LINE=$(awk '/^bridge_mappings/ {print NR}' ${L2_config_file}) 
		sed -i "${LINE} s/$/,${DEFAULT_PHYSNET}:${DEFAULT_BR_EX}/" ${L2_config_file}
	fi

	# update configuration of the current external network net04_ext in DB
	if mysql -e "show status;" &> /dev/null; then
		mysql neutron -e "update  ml2_network_segments set network_type='flat', physical_network='${DEFAULT_PHYSNET}' where network_type='local';"
	fi
}

create_net_infra () 
{
	# parse arguments
	NAME=${1:?"Please specify the name"}
	IF=${2:?"Please specify interface name"}
	MTU=${3:-"1500"}
	# set names for new devices using our name
	LINUX_BR=linux-br-${NAME}
	OVS_BR=br-${NAME}
	PATCH=patch-${NAME}
	PHYSNET=physnet-${NAME}

	# add ovs bridge and create a patch between ovs and linux bridges
	ovs-vsctl add-br ${OVS_BR}
	ovs-vsctl add-port ${OVS_BR} ${PATCH} -- set Interface ${PATCH} type=internal
	echo "auto ${PATCH}
	allow-${OVS_BR} ${PATCH}
	iface ${PATCH} inet manual
	mtu ${MTU}
	ovs_type OVSIntPort
	ovs_bridge ${OVS_BR}" > /etc/network/interfaces.d/ifcfg-${PATCH}
	ifup ${PATCH}

	# add linux bridge
	echo "auto ${LINUX_BR} 
	iface ${LINUX_BR} inet manual
	mtu ${MTU}
	bridge_ports ${IF} ${PATCH}" > /etc/network/interfaces.d/ifcfg-${LINUX_BR}
	ifup ${LINUX_BR}

	# add new physnet in bridge_map with appropriate MTU
	if ! fgrep ${PHYSNET} ${L2_config_file}; then
		LINE=$(awk '/^bridge_mappings/ {print NR}' ${L2_config_file}) 
		sed -i "${LINE} s/$/,${PHYSNET}:${OVS_BR}/" ${L2_config_file}
		LINE=$(awk '/^physical_network_mtus/ {print NR}' ${L2_config_file}) 
		sed -i "${LINE} s/$/,${PHYSNET}:${MTU}/" ${L2_config_file}
	fi
}


prepare_for_multi_ext_nets
create_net_infra $@
restart_neutron_services


