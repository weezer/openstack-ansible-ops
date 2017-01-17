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
node="${node:-compute5:134}"
CONFD_FILE="/etc/openstack_deploy/conf.d/compute_hosts.yml"

source cobbler-setup.sh

source vm-setup.sh

source os-feature-setup.sh