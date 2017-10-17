#!/bin/bash

for i in $(fuel node list | grep "controller" | awk '{print $9}') do
	ssh $i 'bash -x -s' < ./ctrl_ext_net.sh
done

for i in $(fuel node list | grep "compute" | awk '{print $9}') do
	ssh $i 'bash -x -s' < ./comp_ext_net.sh
done
