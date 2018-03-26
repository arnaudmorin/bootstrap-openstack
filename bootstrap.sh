#!/bin/bash

function create_keypair(){(
    openstack keypair show zob 2>&1 >/dev/null
    if [ $? -eq 1 ] ; then
        openstack keypair create --public-key data/zob.pub zob
    fi
)}

function boot(){(
    NAME=$1
    USERDATA=userdata/${NAME/-[0-9]*/}

    cp $USERDATA /tmp/userdata__$$
    sed -i -r "s/__OS_USERNAME__/$OS_USERNAME/" /tmp/userdata__$$
    sed -i -r "s/__OS_PASSWORD__/$OS_PASSWORD/" /tmp/userdata__$$
    sed -i -r "s/__OS_TENANT_NAME__/$OS_TENANT_NAME/" /tmp/userdata__$$
    sed -i -r "s/__OS_TENANT_ID__/$OS_TENANT_ID/" /tmp/userdata__$$
    sed -i -r "s/__OS_REGION_NAME__/$OS_REGION_NAME/" /tmp/userdata__$$

    openstack server create \
        --key-name zob \
        --nic net-id=Ext-Net \
        --nic net-id=management \
        --nic net-id=public \
        --image 'Ubuntu 16.04' \
        --flavor c2-7 \
        --user-data /tmp/userdata__$$ \
        $NAME
)}

create_keypair
boot deployer
boot rabbit
boot mysql
boot keystone
boot nova
boot glance
boot neutron
boot horizon
boot compute-1
