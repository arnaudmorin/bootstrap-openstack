#!/bin/bash

todelete=""

IFS=$'\n'
for line in $(openstack server list -f value -c ID -c Name) ; do
    id=$(echo $line | awk '{ print $1}')
    name=$(echo $line | awk '{ print $2}')

    if [[ "$name" =~ deployer|rabbit|mysql|keystone|nova|placement|cinder|glance|horizon|neutron|compute|designate ]]; then
        echo "Deleting $name"
        todelete="$todelete $id"
    fi
done

eval "openstack server delete $todelete"
