#!/bin/bash -x

#
# ./restart_neutron_services DVR
#

NEUTRON_SERVER=neutron-server
NEUTRON_L3_AGENT=neutron-l3-agent
NEUTRON_OVS_AGENT=neutron-openvswitch-agent
# !!! If you use VPN please uncomment next line !!!
#NEUTRON_L3_AGENT=neutron-vpn-agent

let TIMEOUT=10*60

NODES=$(fuel node)

# Restart neutron services on compute nodes if DVR is used
if [[ $1 == "DVR" ]]; then
	for i in $(echo "${NODES}" | awk '/compute/ {print $10}'); do 
		ssh $i "initctl restart ${NEUTRON_OVS_AGENT} && \
			initctl restart ${NEUTRON_L3_AGENT}"; 
	done
fi

# Restart neutron-server on all controllers
for i in $(echo "${NODES}" | awk '/controller/ {print $10}'); do 
	ssh $i "initctl restart ${NEUTRON_SERVER}"; 
done

# Restart neutron services which are under pacemaker (L3 and OVS agents)
CONTROLLER=$(echo "${NODES}" | awk '/controller/ {print $10}' | head -n 1)
ssh ${CONTROLLER} "pcs resource disable p_${NEUTRON_L3_AGENT}  --wait=${TIMEOUT} &&  \
		   pcs resource enable  p_${NEUTRON_L3_AGENT}  --wait=${TIMEOUT};    \
		   pcs resource disable p_${NEUTRON_OVS_AGENT} --wait=${TIMEOUT} && \
		   pcs resource enable  p_${NEUTRON_OVS_AGENT} --wait=${TIMEOUT};" 

