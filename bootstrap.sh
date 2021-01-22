#!/bin/bash

function create_keypair(){(
    openstack keypair show zob 2>&1 >/dev/null
    if [ $? -eq 1 ] ; then
        openstack keypair create --public-key data/zob.key.pub zob
    fi
)}

function create_networks(){(
    networks=$(openstack network list -c Name -f value)
    echo $networks | grep -q 'management' || {
        openstack network create management
        openstack subnet create --dhcp --gateway none --subnet-range 192.168.1.0/24 --network management --dns-nameserver 0.0.0.0 192.168.1.0/24
    }
    echo $networks | grep -q 'public' || {
        openstack network create public --provider-network-type=vrack --provider-segment=0
        openstack subnet create --no-dhcp --gateway none --subnet-range 192.168.1.0/24 --network public --dns-nameserver 0.0.0.0 192.168.1.0/24
    }
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
            --image 'Debian 10' \
            --flavor c2-7 \
            --user-data /tmp/userdata__$$ \
            $NAME
    else
        echo "$NAME already exists with ID $ID, nothing to do."
    fi
)}

create_keypair
create_networks
boot deployer
boot rabbit
boot mysql
boot keystone
boot nova
boot placement
boot glance
boot horizon
boot neutron
boot compute-1 public
boot designate
