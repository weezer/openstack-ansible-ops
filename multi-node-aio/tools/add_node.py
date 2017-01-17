import os
import argparse

NODES = {
    "Compute":{
        "node_type": "nova_compute",
        "node": "compute3",
        "seq": "122"},
    "Infra":{
        "node_type": "infra",
        "node": "infra4",
        "seq": "103"
    },
    "CONFD_FILE" : "/etc/openstack_deploy/conf.d/compute_hosts.yml"
}


# VM_DISK_SIZE="${VM_DISK_SIZE:-252}"
# DEFAULT_NETWORK="${DEFAULT_NETWORK:-eth0}"
# DEVICE_NAME="${DEVICE_NAME:-vda}"
# node_type="${node_type:-nova_compute}"
# node="${node:-compute5:134}"
# CONFD_FILE="/etc/openstack_deploy/conf.d/compute_hosts.yml"

def add_nodes(**kwargs):
    for i in kwargs:
        os.environ[i] = kwargs[i]



def args():
    """Setup argument Parsing."""
    parser = argparse.ArgumentParser(
        usage='%(prog)s',
        description='Add Node Capaity Testing'
    )

    parser.add_argument(
        '-d',
        '--VM_DISK_SIZE',
        help='Disk size for VM',
        required=False,
        default='252'
    )

    parser.add_argument(
        '-n',
        '--DEFAULT_NETWORK',
        help='the default nic VM use',
        required=False,
        default='eth0'
    )


    parser.add_argument(
        '-i',
        '--DEVICE_NAME',
        help='the disk device name',
        required=False,
        default='vda'
    )

    return vars(parser.parse_args())

def main():
    arg_dict = args()
    print arg_dict
    add_nodes(**arg_dict)

if __name__ == "__main__":
    main()

