for i in $(virsh list --all | awk '/f70-dvr-slave/ {print $2}'); do virsh snapshot-revert $i init ; done
for i in $(virsh list --all | awk '/f70-dvr-slave/ {print $2}'); do virsh resume $i  ; done



HOST=$(fuel node | awk '/controller/ { print $10 }' | head -n 1) && ssh $HOST 'bash -x -s' < ./create_new_ext_net.sh ext1 20.0.0.0/24 20.0.0.1 20.0.0.100. 20.0.0.200
for i in $(fuel node  | awk '/controller|compute/ {print $10}'); do ssh $i 'bash -x -s' < ./add_ext_net.sh ext1 eth3 1500 ; done
