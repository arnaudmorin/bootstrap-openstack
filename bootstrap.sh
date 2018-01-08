#!/bin/bash

function boot(){(
    NAME=$1
    IP=$2
    openstack server create \
        --key-name arnaud-ovh \
        --nic net-id=Ext-Net \
        --nic net-id=management,v4-fixed-ip=192.168.1.$IP \
        --image 'Ubuntu 16.04' \
        --flavor c2-7 \
        --user-data userdata/$NAME \
        $NAME
)}

#boot rabbit 100
#boot mysql 101
#boot keystone 102
boot nova 103
