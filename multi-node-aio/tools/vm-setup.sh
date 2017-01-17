#!/usr/bin/env bash
set -eu

pushd .
cd ..
cp -v "templates/vmnode-config/${node_type}.openstackci.local.xml" /etc/libvirt/qemu/${node}.openstackci.local.xml
sed -i "s|__NODE__|${node}|g" /etc/libvirt/qemu/${node}.openstackci.local.xml
sed -i "s|__COUNT__|${seq}|g" /etc/libvirt/qemu/${node}.openstackci.local.xml
sed -i "s|__DEVICE_NAME__|${DEVICE_NAME}|g" /etc/libvirt/qemu/${node}.openstackci.local.xml


# Populate network configurations based on node type

sed "s/__COUNT__/${seq}/g" "templates/network-interfaces/vm.openstackci.local-bonded-bridges.cfg" > \
"/var/www/html/osa-${node}.openstackci.local-bridges.cfg"


qemu-img create -f qcow2 -o preallocation=metadata,compat=1.1,lazy_refcounts=on \
                    /var/lib/libvirt/images/${node}.openstackci.local.img "${VM_DISK_SIZE}G"

virsh define /etc/libvirt/qemu/${node}.openstackci.local.xml || true
virsh create /etc/libvirt/qemu/${node}.openstackci.local.xml || true

# Wait here for all nodes to be booted and ready with SSH
echo "Waiting for node: ${node} on 10.0.0.${seq}"
until ssh -q -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10 10.0.0.${node#*':'} exit > /dev/null; do
  sleep 15
done
for i in $(apt-key list | awk '/pub/ {print $2}' | awk -F'/' '{print $2}'); do
  apt-key export "$i" > "/tmp/keys/$i"
done
ssh -q -n -f -o StrictHostKeyChecking=no 10.0.0.${seq} "mkdir -p /tmp/keys"
for i in /etc/apt/apt.conf.d/00-nokey /etc/apt/sources.list /etc/apt/sources.list.d/* /tmp/keys/*; do
  if [[ -f "$i" ]]; then
    scp "$i" "10.0.0.${seq}:$i"
  fi
done
ssh -q -n -f -o StrictHostKeyChecking=no 10.0.0.${seq} "(
    for i in /tmp/keys/*; do \
    apt-key add \$i; \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys \$(basename \$i); done); \
    apt-get clean; \
    apt-get update"
popd