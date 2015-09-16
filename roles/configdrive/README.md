ansible-role-configdrive
========================

Ansible role to create config-drives for OpenStack Ironic. 
It creates OpenStack config-drives data for nodes and it is able
to setup complex networking configuration like bonding, vlans 
and bridges on Debian and RedHat based distributions. Note 
that the images have to have support for those features 
(kernel modules, packages, ...). This tool just create the 
configuration files which are going to be injected in the host at 
boot time using Cloud-Init.

This playbook is intended to be executed prior to the deployments 
of nodes via Ironic. It creates a basic configuration drive 
containing network configuration, a SSH key permitting the 
user to login to the host, and other files like `/etc/hosts` or 
`/etc/resolv.conf`. Also, it is able to include user_data 
file https://help.ubuntu.com/community/CloudInit


Requirements
------------

It does not install packages on the target host, it just creates the 
folders and files needed to create a config-drive volume, So, be 
aware that you probably you will need to install `genisoimage`, 
`base64` and `gzip`.


Configuration
-------------

Role parameters
```
# You should overwrite those role variables!
# It will generate the network configuration based
# on the family!
configdrive_os_family: "Debian"
configdrive_uuid: "uuid-test-01"
configdrive_fqdn: "test.example.com"
configdrive_name: "test"
configdrive_ssh_public_key:
configdrive_availability_zone: ""
configdrive_network_info: True
configdrive_config_dir: "/var/lib/ironic/images/"
configdrive_volume_path: "/var/lib/ironic/images/"

# Aditional metadata
configdrive_meta: {}

# Path to ssh public key file
configdrive_ssh_public_key_path:
# Path to cloud-config file
configdrive_config_user_data_path:

# Automatically assigned with uuid
#configdrive_instance_dir:
# Delete the instace dir folder after creation
configdrive_config_dir_delete: False

# Populate the /etc/resolv.conf
#configdrive_resolv:
#    domain: "example.com"
#    search: "hola.example.com"
#    dns: ['8.8.8.8']

# Populate the /etc/hosts
#configdrive_hosts:
#  - ['127.0.1.1', 'host1.domain.com']
#  - ['127.0.1.2', 'host3.domain.com']

# Definition list of devices
#configdrive_network_device_list:
#  - device: "eth1"
#    bootproto: "dhcp"
#  - device: "eth2"
#    bootproto: "dhcp"
#    type: "phy"
#  - device: "eth0.500"
#    type: "vlan"
#    address: "10.1.1.10"
#    netmask: "255.255.255.0"
#    gateway: "10.1.1.1"
#    nameservers: 
#      - 8.8.8.8
#      - 9.9.9.9
#    domain: "hola.com"
#    backend: ["eth0"]
```

Usage
-----

Have a look at the `site.yml` and type `vagrant up`, go to the folder
`/tmp/configdrive` inside the vagrant vm and you will see the compresed
iso volume and all the folder/files structure included in it. 


Author Information
------------------

José Riguera López
