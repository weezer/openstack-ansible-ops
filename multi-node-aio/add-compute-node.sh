#!/usr/bin/env bash
set -eu
# Copyright [2017] [Weezer Su]
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.



VM_DISK_SIZE="${VM_DISK_SIZE:-252}"
DEFAULT_NETWORK="${DEFAULT_NETWORK:-eth0}"
DEVICE_NAME="${DEVICE_NAME:-vda}"
node_type="${node_type:-nova_compute}"
node="${node:-compute3:152}"
CONFD_FILE="/etc/openstack_deploy/conf.d/compute_hosts.yml"

cobbler system add \
  --name="${node%%':'*}" \
  --profile="ubuntu-server-14.04-unattended-cobbler-${node_type}.seed" \
  --hostname="${node%%":"*}.openstackci.local" \
  --kopts="interface=${DEFAULT_NETWORK}" \
  --interface="${DEFAULT_NETWORK}" \
  --mac="52:54:00:bd:81:${node:(-2)}" \
  --ip-address="10.0.0.${node#*":"}" \
  --subnet=255.255.255.0 \
  --gateway=10.0.0.200 \
  --name-servers=8.8.8.8 8.8.4.4 \
  --static=1

cd ..
cp -v "templates/vmnode-config/${node_type}.openstackci.local.xml" /etc/libvirt/qemu/${node%%":"*}.openstackci.local.xml
sed -i "s|__NODE__|${node%%":"*}|g" /etc/libvirt/qemu/${node%%":"*}.openstackci.local.xml
sed -i "s|__COUNT__|${node:(-2)}|g" /etc/libvirt/qemu/${node%%":"*}.openstackci.local.xml
sed -i "s|__DEVICE_NAME__|${DEVICE_NAME}|g" /etc/libvirt/qemu/${node%%":"*}.openstackci.local.xml


# Populate network configurations based on node type

sed "s/__COUNT__/${node#*":"}/g" "templates/network-interfaces/vm.openstackci.local-bonded-bridges.cfg" > \
"/var/www/html/osa-${node%%":"*}.openstackci.local-bridges.cfg"



qemu-img create -f qcow2 -o preallocation=metadata,compat=1.1,lazy_refcounts=on \
                    /var/lib/libvirt/images/${node%%":"*}.openstackci.local.img "${VM_DISK_SIZE}G"

virsh define /etc/libvirt/qemu/${node%%":"*}.openstackci.local.xml || true
virsh create /etc/libvirt/qemu/${node%%":"*}.openstackci.local.xml || true

# Wait here for all nodes to be booted and ready with SSH
echo "Waiting for node: ${node%%":"*} on 10.0.0.${node#*":"}"
until ssh -q -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10 10.0.0.${node#*':'} exit > /dev/null; do
  sleep 15
done

ssh -q -n -f -o StrictHostKeyChecking=no 10.0.0.${node#*":"} "mkdir -p /tmp/keys"
for i in /etc/apt/apt.conf.d/00-nokey /etc/apt/sources.list /etc/apt/sources.list.d/* /tmp/keys/*; do
  if [[ -f "$i" ]]; then
    scp "$i" "10.0.0.${node#*":"}:$i"
  fi
done
ssh -q -n -f -o StrictHostKeyChecking=no 10.0.0.${node#*":"} "(for i in /tmp/keys/*; do \
    apt-key add \$i; \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys \$(basename \$i); done); \
    apt-get clean; \
    apt-get update" &

echo "  ${node%%':'*}:" >> ${CONFD_FILE}
echo "    ip: 172.29.236.${node#*":"}" >> ${CONFD_FILE}

sleep 60

/opt/openstack-ansible/playbooks/inventory/dynamic_inventory.py > /dev/null
cd /opt/openstack-ansible/playbooks
openstack-ansible setup-hosts.yml --limit "${node%%':'*}"
openstack-ansible setup-openstack.yml --skip-tags nova-key-distribute --limit "${node%%':'*}"
openstack-ansible setup-openstack.yml --tags nova-key --limit compute_hosts
openstack-ansible --tags=openstack-host-hostfile setup-hosts.yml
