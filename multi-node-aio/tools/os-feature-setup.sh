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

echo "  ${node}:" >> ${CONFD_FILE}
echo "    ip: 172.29.236.${seq}" >> ${CONFD_FILE}
/opt/openstack-ansible/playbooks/inventory/dynamic_inventory.py > /dev/null
cd /opt/openstack-ansible/playbooks
openstack-ansible setup-hosts.yml --limit "${node}"
openstack-ansible setup-openstack.yml --skip-tags nova-key-distribute --limit "${node}"
openstack-ansible setup-openstack.yml --tags nova-key --limit compute_hosts
openstack-ansible --tags=openstack-host-hostfile setup-hosts.yml