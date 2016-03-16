#!/bin/bash -x

# how to use
#
# ./add_ext_net ext_new eth10 1500 77.0.0.0/24 77.0.0.1 77.0.0.100 77.0.0.200
#


# parse arguments
NAME=${1:?"Please specify the name"}
IF=${2:?"Please specify interface name"}
MTU=${3:-"1500"}
CIDR=${4}
GATEWAY=${5}
FIP_START=${6}
FIP_END=${7}

# set names for new devices using our name
LINUX_BR=linux-br-${NAME}
OVS_BR=br-${NAME}
PATCH=patch-${NAME}
PHYSNET=physnet-${NAME}
DEFAULT_BR_EX="br-floating"
DEFAULT_PHYSNET="physnet-ex"

L2_config_file=/etc/neutron/plugins/ml2/ml2_conf.ini 
L3_config_file=/etc/neutron/l3_agent.ini 

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

# clear gateway_external_network_id and external_network_bridge parameters in /etc/neutron/l3_agent.ini
if ! grep "^gateway_external_network_id" ${L3_config_file}; then
	sed -i "/^# gateway_external_network_id/a gateway_external_network_id =" ${L3_config_file}
fi
sed -i "/^external_network_bridge/c external_network_bridge =" ${L3_config_file}

# update configuration for the defualt current external network net04_ex
grep "^bridge_mappings" /etc/neutron/plugins/ml2/ml2_conf.ini | grep ${DEFAULT_BR_EX}
if [ $? ]; then
	LINE=$(awk '/^bridge_mappings/ {print NR}' ${L2_config_file}) 
	sed -i "${LINE} s/$/,${DEFAULT_PHYSNET}:${DEFAULT_BR_EX}/" ${L2_config_file}
fi

# add new physnet in bridge_map with appropriate MTU
if ! fgrep ${PHYSNET} ${L2_config_file}; then
	LINE=$(awk '/^bridge_mappings/ {print NR}' ${L2_config_file}) 
	sed -i "${LINE} s/$/,${PHYSNET}:${OVS_BR}/" ${L2_config_file}
	LINE=$(awk '/^physical_network_mtus/ {print NR}' ${L2_config_file}) 
	sed -i "${LINE} s/$/,${PHYSNET}:${MTU}/" ${L2_config_file}
fi
	
# update configuration of the current external network net04_ext in DB
mysql  neutron -e "update  ml2_network_segments set network_type='flat', physical_network='physnet-ex' where network_type='local';"

# restart neutron services if it is not a controller
initctl restart neutron-server
#if ! crm resource restart p_neutron-plugin-openvswitch-agent; then
initctl restart neutron-plugin-openvswitch-agent
#fi
#if ! crm resource restart p_neutron-l3-agent; then
initctl restart neutron-l3-agent
#fi

# check if we have CIDR and GATEWAY
if [ -z ${CIDR} ] && [ -z ${GATEWAY} ]; then 
	exit 0
fi

source openrc

# check if it is exist and create net if not
$(neutron net-list | awk -v NAME=$NAME '{if (NAME == $4) exit 123;}')
if (( 123 != $? )); then
	neutron net-create ${NAME} --provider:network_type flat --provider:physical_network ${PHYSNET} --router:external
fi

# check if it is exist and create subnet if not
$(neutron subnet-list | awk -v NAME=$NAME '{if (NAME == $4) exit 123;}')
if (( 123 != $? )); then
	neutron subnet-create ${NAME} ${CIDR} --name ${NAME} --gateway ${GATEWAY} --enable_dhcp=False --allocation-pool start=${FIP_START},end=${FIP_END}
fi
