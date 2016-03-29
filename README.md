First of all you need to clone this repo to the fuel master node:
git clone https://github.com/aepifanov/openstack-add-network.git

Before starting you should make sure that everything works pretty good:
pcs status
rabbitmqctl cluster_status
mysql -e "show status"
neutron agent-list 
nova service-list

The the easiest way to add a new external network is the execute the following script:
./add_ext_net.sh <NAME> <IF> <MTU> <CIDR> <GATEWAY>  <START_FIP_RANGE> <END_FIP_RANGE> [DVR]
This script just performs all the following steps automatically.

If you have some network modification or want to do it with additional checking you can 
perform the following steps manually:

1. Prepare the cloud for working with multiple external network 
(if you don't use DVR you shoud use only controller for search template in awk):
for i in $(fuel node  | awk '/controller|compute/ {print $10}'); do ssh $i 'bash -x -s' < ./1.prepare_for_multi_ext_net.sh; done

1.1 If you want to make sure that everything work after this change you just need to
restart neutron services and test it:
./restart_netutron_services DVR

2. Create network infrastructure for new external network:
(if you don't use DVR you shoud use only controller for search template in awk):
for i in $(fuel node  | awk '/controller|compute/ {print $10}'); do ssh $i 'bash -x -s' < ./2.create_infra_for_new_ext_net.sh <NAME> <IF> <MTU> ; done

3. Restart all neutron services on all nodes
./restart_netutron_services DVR

4. Create a new external network:
HOST=$(fuel node | awk '/controller/ { print $10 }' | head -n 1) && ssh $HOST 'bash -x -s' < ./3.create_new_ext_net.sh <NAME> <CIDR> <GATEWAY> <START_FIP_RANGE> <END_FIP_RANGE>

If you need to add N ext networks you should repeat N times steps 2 and 4.
Enjoy!



