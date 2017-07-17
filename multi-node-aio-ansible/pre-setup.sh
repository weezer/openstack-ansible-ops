#!/usr/bin/env bash
set -eu
# Copyright [2016] [Kevin Carter]
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

# Load all functions
source functions.rc

# bring in variable definitions if there is a variables.sh file
[[ -f variables.sh ]] && source variables.sh

# Make the rekick function part of the main general shell
declare -f rekick_vms | tee /root/.functions.rc
declare -f ssh_agent_reset | tee -a /root/.functions.rc
if ! grep -q 'source /root/.functions.rc' /root/.bashrc; then
  echo 'source /root/.functions.rc' | tee -a /root/.bashrc
fi

# Reset the ssh-agent service to remove potential key issues
ssh_agent_reset

if [ ! -f "/root/.ssh/id_rsa" ];then
  ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa
fi

# This gets the root users SSH-public-key
SSHKEY=$(cat /root/.ssh/id_rsa.pub)
if ! grep -q "${SSHKEY}" /root/.ssh/authorized_keys; then
  cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
fi

# add ansible repo to /etc/apt/sources.list
echo "deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main" >> /etc/apt/sources.list

# add key and install ansible
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
apt-get update && apt-get install -y ansible
