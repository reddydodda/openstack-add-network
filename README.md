for i in $(virsh list --all | awk '/f70-dvr-slave/ {print $2}'); do virsh snapshot-revert $i init ; done
for i in $(virsh list --all | awk '/f70-dvr-slave/ {print $2}'); do virsh resume $i  ; done




for i in $(fuel node  | awk '/controller/ {print $10}'); do ssh $i 'bash -x -s' < ./add_ext_net.sh ext1 eth3 9000 20.0.0.0/25 20.0.0.1; done
for i in $(fuel node  | awk '/compute/ {print $10}'); do ssh $i 'bash -x -s' < ./add_ext_net.sh ex1 eth3 9000; done
