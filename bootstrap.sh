#!/bin/bash

function create_keypair(){(
    openstack keypair show zob 2>&1 >/dev/null
    if [ $? -eq 1 ] ; then
        openstack keypair create --public-key data/zob.key.pub zob
    fi
)}

function boot(){(
    NAME=$1
    PUBLIC_NET=$2
    USERDATA=userdata/${NAME/-[0-9]*/}

    echo ""
    echo "Booting $NAME..."

    cp $USERDATA /tmp/userdata__$$
    sed -i -r "s/__OS_USERNAME__/$OS_USERNAME/" /tmp/userdata__$$
    sed -i -r "s/__OS_PASSWORD__/$OS_PASSWORD/" /tmp/userdata__$$
    sed -i -r "s/__OS_TENANT_NAME__/$OS_TENANT_NAME/" /tmp/userdata__$$
    sed -i -r "s/__OS_TENANT_ID__/$OS_TENANT_ID/" /tmp/userdata__$$
    sed -i -r "s/__OS_REGION_NAME__/$OS_REGION_NAME/" /tmp/userdata__$$

    [ -n "$PUBLIC_NET" ] && EXTRA="--nic net-id=$PUBLIC_NET"

    # Checking if instances does not already exists
    ID=$(openstack server list --name $NAME -f value -c ID)

    if [ -z "$ID" ] ; then
        openstack server create \
            --key-name zob \
            --nic net-id=Ext-Net \
            --nic net-id=management $EXTRA \
            --image 'Ubuntu 16.04' \
            --flavor c2-7 \
            --user-data /tmp/userdata__$$ \
            $NAME
    else
        echo "$NAME already exists with ID $ID, nothing to do."
    fi
)}

create_keypair
boot deployer
boot rabbit
boot mysql
boot keystone
boot nova
boot glance
boot horizon
boot neutron public
boot compute-1 public
boot designate
