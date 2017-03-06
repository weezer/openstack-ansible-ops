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

# The default image for VMs, change it to 16.04 if you want to use xenial as operation system.
DEFAULT_IMAGE="${DEFAULT_IMAGE:-"$(lsb_release -sd | awk '{print $2}')"}"

# The default kernel for Image, leave it empty will install the lastest kernel.
DEFAULT_KERNEL="${DEFAULT_KERNEL:-}"

if [ -z "$DEFAULT_KERNEL" ]; then
  DEFAULT_KERNEL=linux-image-generic
else
  DEFAULT_KERNEL="linux-image-$DEFAULT_KERNEL-generic"
fi

# Install cobbler
wget -qO - http://download.opensuse.org/repositories/home:/libertas-ict:/cobbler26/xUbuntu_14.04/Release.key | apt-key add -
add-apt-repository "deb http://download.opensuse.org/repositories/home:/libertas-ict:/cobbler26/xUbuntu_14.04/ ./"
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install cobbler dhcp3-server debmirror isc-dhcp-server ipcalc tftpd tftp fence-agents iptables-persistent

# Basic cobbler setup
sed -i 's/^manage_dhcp\:.*/manage_dhcp\: 1/g' /etc/cobbler/settings
sed -i 's/^restart_dhcp\:.*/restart_dhcp\: 1/g' /etc/cobbler/settings
sed -i 's/^next_server\:.*/next_server\: 10.0.0.200/g' /etc/cobbler/settings
sed -i 's/^server\:.*/server\: 10.0.0.200/g' /etc/cobbler/settings
sed -i 's/^http_port\:.*/http_port\: 5150/g' /etc/cobbler/settings
sed -i 's/^INTERFACES.*/INTERFACES="br-dhcp"/g' /etc/default/isc-dhcp-server

# Move Cobbler Apache config to the right place
cp -v /etc/apache2/conf.d/cobbler.conf /etc/apache2/conf-available/
cp -v /etc/apache2/conf.d/cobbler_web.conf /etc/apache2/conf-available/

# Fix Apache conf to match 2.4 configuration
sed -i "/Order allow,deny/d" /etc/apache2/conf-available/cobbler*.conf
sed -i "s/Allow from all/Require all granted/g" /etc/apache2/conf-available/cobbler*.conf
sed -i "s/^Listen 80/Listen 5150/g" /etc/apache2/ports.conf
sed -i "s/\:80/\:5150/g" /etc/apache2/sites-available/000-default.conf

# Enable the above config
a2enconf cobbler cobbler_web

# Enable Proxy modules
a2enmod proxy
a2enmod proxy_http

# Fix TFTP server arguments in cobbler template to enable it to work on Ubuntu
sed -i "s/server_args .*/server_args             = -s \$args/" /etc/cobbler/tftpd.template

mkdir_check "/tftpboot"

chown www-data /var/lib/cobbler/webui_sessions

#  when templated replace \$ with $
# Copy dhcp template and replace with DNS var
cp -v templates/dhcp.template /etc/cobbler/dhcp.template
sed -i "s|__DNS_NAMESERVER__|${DNS_NAMESERVER}|g" /etc/cobbler/dhcp.template

# Create a sources.list.j2 file
if [[ $DEFAULT_IMAGE == "14.04."* ]]; then
  cp -v templates/trusty-sources.list /var/www/html/trusty-sources.list
else
  cp -v templates/xenial-sources.list /var/www/html/xenial-sources.list
fi

# Set the default preseed device name.
#  This is being set because sda is on hosts, vda is kvm, xvda is xen.
DEVICE_NAME="${DEVICE_NAME:-vda}"

# This is set to instruct the preseed what the default network is expected to be
DEFAULT_NETWORK="${DEFAULT_NETWORK:-eth0}"

# Set SSH key to root user's public key
SSHKEY="${SSHKEY:-$(cat /root/.ssh/id_rsa.pub)}"

# Template the seed files
for seed_file in $(ls -1 templates/pre-seeds); do
  cp -v "templates/pre-seeds/${seed_file}" "/var/lib/cobbler/kickstarts/${seed_file#*'/'}"
  sed -i "s|__DEVICE_NAME__|${DEVICE_NAME}|g" "/var/lib/cobbler/kickstarts/${seed_file#*'/'}"
  sed -i "s|__SSHKEY__|${SSHKEY}|g" "/var/lib/cobbler/kickstarts/${seed_file#*'/'}"
  sed -i "s|__DEFAULT_NETWORK__|${DEFAULT_NETWORK}|g" "/var/lib/cobbler/kickstarts/${seed_file#*'/'}"
  sed -i "s|__DEFAULT_KERNEL__|${DEFAULT_KERNEL}|g" "/var/lib/cobbler/kickstarts/${seed_file#*'/'}"
done

# Restart services again and configure autostart
service cobblerd restart
service apache2 restart
service xinetd restart
update-rc.d cobblerd defaults

# Update Cobbler Signatures
cobbler signature update

# Get ubuntu server image md5 hash file
wget -qO /tmp/MD5SUMS http://releases.ubuntu.com/"${DEFAULT_IMAGE:0:5}"/MD5SUMS

# Get ubuntu server image, if the server image exists, compare the md5, rm and download new image if the hash is not
# the same.
mkdir_check "/var/cache/iso"
pushd /var/cache/iso
  if [ -f "/var/cache/iso/ubuntu-"${DEFAULT_IMAGE}"-server-amd64.iso" ]; then
    md5=`md5sum ubuntu-"${DEFAULT_IMAGE}"-server-amd64.iso | awk '{ print $1 }'`
    if ! grep -q ${md5} /tmp/MD5SUMS ; then
      rm /var/cache/iso/ubuntu-"${DEFAULT_IMAGE}"-server-amd64.iso
      wget http://releases.ubuntu.com/"${DEFAULT_IMAGE:0:5}"/ubuntu-"${DEFAULT_IMAGE}"-server-amd64.iso
    fi
  else
    wget http://releases.ubuntu.com/"${DEFAULT_IMAGE:0:5}"/ubuntu-"${DEFAULT_IMAGE}"-server-amd64.iso
  fi
popd

# import cobbler image
if ! cobbler distro list | grep -qw "ubuntu-"${DEFAULT_IMAGE}"-server-x86_64"; then
  mkdir_check "/mnt/iso"
  mount -o loop /var/cache/iso/ubuntu-"${DEFAULT_IMAGE}"-server-amd64.iso /mnt/iso
  cobbler import --name=ubuntu-"${DEFAULT_IMAGE}"-server-amd64 --path=/mnt/iso
  umount /mnt/iso
fi

# Create cobbler profile
for seed_file in /var/lib/cobbler/kickstarts/ubuntu*"${DEFAULT_IMAGE:0:5}"*.seed; do
  if ! cobbler profile list | grep -qw "${seed_file##*'/'}"; then
    cobbler profile add \
      --name "${seed_file##*'/'}" \
      --distro ubuntu-"${DEFAULT_IMAGE}"-server-x86_64 \
      --kickstart "${seed_file}"
  fi
done

# sync cobbler
cobbler sync

# Get Loaders
cobbler get-loaders


# Create cobbler systems
for node_type in $(get_all_types); do
  for node in $(get_host_type ${node_type}); do
    if cobbler system list | grep -qw "${node%%':'*}"; then
      echo "removing node ${node%%':'*} from the cobbler system"
      cobbler system remove --name "${node%%':'*}"
    fi
    echo "adding node ${node%%':'*} from the cobbler system"
    cobbler system add \
      --name="${node%%':'*}" \
      --profile="ubuntu-server-"${DEFAULT_IMAGE:0:5}"-unattended-cobbler-${node_type}.seed" \
      --hostname="${node%%":"*}.openstackci.local" \
      --kopts="interface=${DEFAULT_NETWORK} net.ifnames=0 biosdevname=0" \
      --interface="${DEFAULT_NETWORK}" \
      --mac="52:54:00:bd:81:${node:(-2)}" \
      --ip-address="10.0.0.${node#*":"}" \
      --subnet=255.255.255.0 \
      --gateway=10.0.0.200 \
      --name-servers="${DNS_NAMESERVER}" \
      --static=1
  done
done

# sync cobbler
cobbler sync

# Restart XinetD
service xinetd stop
service xinetd start

# Remove the expired key and opensuse repo, no need after the cobbler being set up.
aptkey_mesg=$(apt-key list)
if [[ $(contains "$aptkey_mesg" "expired") -gt 0 ]]; then
    expired_key=$(echo "$aptkey_mesg" | awk /expired/'{print $ sub(".*\/", "")}')
    apt-key del $expired_key
    add-apt-repository --remove "deb http://download.opensuse.org/repositories/home:/libertas-ict:/cobbler26/xUbuntu_14.04/ ./"
fi
