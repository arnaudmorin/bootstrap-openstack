#!/bin/bash

function boot(){(
    NAME=$1
    IP=$2
    openstack server create \
        --key-name arnaud-ovh \
        --nic net-id=Ext-Net \
        --nic net-id=public \
        --image 'Ubuntu 16.04' \
        --flavor c2-7 \
        --user-data userdata/${NAME/-[0-9]*/} \
        $NAME
)}

#boot deployer
#boot rabbit
#boot mysql
#boot keystone
#boot nova
#boot glance
#boot neutron
#boot compute-1
