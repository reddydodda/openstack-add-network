#!/bin/bash -x

# how to use
#
# ./add_ext_net.sh ext1 eth3 1500 20.0.0.0/24 20.0.0.1 20.0.0.100 20.0.0.200 DVR
#

# parse arguments
NAME=${1:?"Please specify the name (1 arg)"}
IF=${2:?"Please specify interface name (2 arg)"}
MTU=${3:?"Please specify MTU (3 arg)"}
CIDR=${4:?"Please specify CIDR (4 arg)"}
GATEWAY=${5:?"Please specify GATEWAY IP (5 arg)"}
FIP_START=${6:?"Please specify start IP of Floating IP reange  (6 arg)"}
FIP_END=${7:?"Please specify end IP of Floating IP reange  (7 arg)"}
DVR=${8}
PORT_RANGE=${9:?"Please specify vlan Range ex : 200:205"}

NODE_TMPL="controller"

if [[ ${DVR} == "DVR" ]]; then
	NODE_ALL="${NODE_TMPL}|compute"
fi
NODE_CTRL=$(fuel node | egrep "${NODE_TMPL}")

# 1 step
for i in $(echo "${NODE_ALL}" | awk '{print $10}'); do
	ssh $i 'bash -x -s' < ./1.prepare_for_multi_ext_net.sh ${NAME} ${IF}
done


# 2 step
for i in $(echo "${NODE_CTRL}" | awk '{print $10}'); do
	ssh $i 'bash -x -s' < ./2.create_infra_for_new_ext_net.sh ${NAME} ${MTU} ${PORT_RANGE}
done


# 3 step
./3.restart_neutron_services.sh ${DVR}

# 4 step
CONTROLLER=$(echo "${NODES}" | awk '/controller/ {print $10}' | head -n 1)
ssh ${CONTROLLER} 'bash -x -s' < ./4.create_new_ext_net.sh ${NAME} ${CIDR} ${GATEWAY} ${FIP_START} ${FIP_END}
