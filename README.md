Ansible-Ironic-Standalone
=========================

A set of roles to setup an OpenStack Ironic node in standalone mode, 
just to be able to deploy servers like cobbler but based on images ...

Have a look at the wiki to know more about this setup: 
https://github.com/jriguera/ansible-ironic-standalone/wiki


Requirements
------------

It was tested on Ubuntu Trusty, but all roles run on Centos as well 
(to be tested!). These roles install all requirements from the 
distribution repos and the official Kilo Ubuntu-Cloud repository,
so no development packages are installed, just official packages!

Roles used:

 * `roles/mysql` to setup a MySQL server and databases.
 * `roles/rabbitmq` to setup a message queue using RabbitMQ.
 * `roles/monit` (optional) to setup processes control with Monit.
 * `roles/ironic` to setup the OpenStack Ironic daemons.
 * `roles/dnsmasq` to setup a PXE server to use with Ironic.
 * `roles/nginx` (optional) to setup HTTP image repo server (for IPA).

Note that those roles have no dependecies between each other, so you 
can reuse them in other projects, they have more functionalities than 
the required for this setup. Also, they were created/adapted following 
devops practices.
 
The Ironic client is not updated to the latest version (Kilo) on the
Ubuntu Cloud repository, you have to build it from source, but it is 
not part on this setup because it is just the client part.

How to run this thing
---------------------

Just type: `vagrant up` to run all the setup (playbook and roles: `site.yml`), 
after that just launch `vagrant ssh ironic` to have a look at the configuration.

When vagrant will be finished, you will have those ports available:

 * http://127.0.0.1:15672 - RabbitMQ (ironic:rabbitmq)
 * mysql://127.0.0.1:3306 - MySQL (ironic:mysql)
 * http://127.0.0.1:6385 - Ironic API
 * http://127.0.0.1:8080 - Nginx http image repository
 * http://127.0.0.1:2812 - Monit (admin:admin) 

Remember that the client needs those environment variables:
```
export OS_AUTH_TOKEN=" "
export IRONIC_URL=http://server:6385/
```

Also remember you have to copy the images which you create and want to use for 
the baremetal hosts (ramdisk and deploy) to `{{ ironic_pxe_images_path }}` 
(`/var/lib/ironic/http/deploy/`) in the server and reference them as
`file:///var/lib/ironic/http/deploy/image.bin` on the client. Let's see an example 
with a client (at least version 0.5.0) running on the server (installed with 
`pip install python-ironicclient`):

```
# This example uses the pxe_ipmitool driver!

# Define the parameter for the new server
NAME=test1
MAC=00:25:90:8f:51:a0
IPMI=10.0.0.2
 
# Ironic in standalone mode!
export OS_AUTH_TOKEN=" "
export IRONIC_URL=http://localhost:6385/
 
# Define the new server using the pxe_ipmitool driver
ironic node-create -n $NAME \
       -d pxe_ipmitool \
       -i ipmi_address=$IPMI \
       -i ipmi_username=ADMIN \
       -i ipmi_password=ADMIN \
       -i deploy_kernel=file:///var/lib/ironic/http/deploy/my-deploy-ramdisk.kernel \
       -i deploy_ramdisk=file:///var/lib/ironic/http/deploy/my-deploy-ramdisk.initramfs

# Get the UUID of the new host
UUID=$(ironic node-list | awk "/$NAME/ { print \$2 }")
 
# Define the link between the baremetal server and the PXE MAC address
ironic port-create -n $UUID -a $MAC

# Ironic needs the MD5 checksum, otherwise the deploy will fail
MD5=$(md5sum /var/lib/ironic/http/images/my-image.qcow2 | cut -d' ' -f 1)
 
# Define the rest of the parameters, like the final image to
# install on the baremetal host
ironic node-update $UUID add \
       instance_info/image_source=file:///var/lib/ironic/http/images/my-image.qcow2 \
       instance_info/kernel=file:///var/lib/ironic/http/images/my-image.vmlinuz \
       instance_info/ramdisk=file:///var/lib/ironic/http/images/my-image.initrd \
       instance_info/root_gb=10 \
       instance_info/image_checksum=$MD5
 
# Validate the node
ironic node-validate $UUID
 
# Create the config drive!!
# See the documentation about how to do it!
CONFIG_DRIVE=/path/to/folder
 
# Deploy the node, set state to active
ironic node-set-provision-state --config-drive $CONFIG_DRIVE $UUID active
```

To build the images, you will need `ramdisk-image-create` and `disk-image-create` 
(install them from the repo: https://github.com/openstack/diskimage-builder ):

```
# Create the initial ramdkisk
export ELEMENTS_PATH="/home/jriguera/diskimage-builder/elements" 
ramdisk-image-create ubuntu deploy-ironic grub-install -o my-deploy-ramdisk
 
# Create the final Ubuntu image to deploy on baremetal host disk 
# (with ConfigDrive support!!)
DIB_CLOUD_INIT_DATASOURCES="ConfigDrive, OpenStack" \
disk-image-create ubuntu baremetal dhcp-all-interfaces -o my-image
```

Copy `my-image.*` (image, ramdisk and kernel) to `/var/lib/ironic/http/images/`
on the Ironic server, and the deploy ramdisk kernel and image to 
`/var/lib/ironic/http/deploy/` (Create those folders if they do not exist).

Ironic Client Playbooks
-----------------------

To automatically define (and delete) baremetal servers using the driver `agent_ipmitool`
(which allows deploy full disk images -with lvm, for example), I have created two playbooks
which are using the `configdrive` role to create the initial cloud-init configuration
with the proper network definition. Have a look at the playbooks and at the `/vars` folder
to see how to define the variables for your infrastructure.

The configdrive definition is provided to the client via URL, by using the HTTP server 
running on the Ironic server, so have a look at the structure provided by the HTTP server.


 * `add-baremetal.yml`: To add a new baremetal server. It will ask for the required parameters.
```
$ ansible-playbook -i hosts/production \
  -e baremetal_ipmi_ip=10.0.0.15 \
  -e baremetal_mac=00:24:90:58:51:f0 \
  -e baremetal_fqdn=compute-11.domain.com \
  -e baremetal_ip=10.10.0.15 \
  add-baremetal.yml

IPMI user? [ADMIN]: XXXXX 
IPMI password? [ADMIN]: XXXX
Main network? (optional, default=pxe): admin
Image to deploy? [trusty]: 

PLAY [Define and deploy physical servers using Ironic] ************************ 

TASK: [Include image definitions] ********************************************* 
ok: [pe-prod-ironic-01]

TASK: [Include network definitions] ******************************************* 
ok: [pe-prod-ironic-01]

TASK: [Define the MD5 checksum URI if needed] ********************************* 
ok: [pe-prod-ironic-01]

TASK: [Get the url image MD5 checksum if needed] ****************************** 
changed: [pe-prod-ironic-01]

TASK: [Load the previous MD5 checksum] **************************************** 
ok: [pe-prod-ironic-01]

TASK: [Workout the checksum with the image url if needed] ********************* 
skipping: [pe-prod-ironic-01]

TASK: [Load the previous MD5 checksum] **************************************** 
skipping: [pe-prod-ironic-01]

TASK: [Get the file image MD5 checksum if needed] ***************************** 
skipping: [pe-prod-ironic-01]

TASK: [Load the url MD5 checksum is needed] *********************************** 
skipping: [pe-prod-ironic-01]

TASK: [Workout the checksum with the image if needed] ************************* 
skipping: [pe-prod-ironic-01]

TASK: [Load the url MD5 checksum is needed] *********************************** 
skipping: [pe-prod-ironic-01]

TASK: [Define the server domain] ********************************************** 
skipping: [pe-prod-ironic-01]

TASK: [Define the server name] ************************************************ 
ok: [pe-prod-ironic-01]

TASK: [Define the server name as MAC] ***************************************** 
skipping: [pe-prod-ironic-01]

TASK: [Get the current date] ************************************************** 
changed: [pe-prod-ironic-01]

TASK: [Define the date] ******************************************************* 
ok: [pe-prod-ironic-01]

TASK: [Assign network parameters] ********************************************* 
ok: [pe-prod-ironic-01]

TASK: [Assign network parameters with DHCP] *********************************** 
skipping: [pe-prod-ironic-01]

TASK: [Check if the network needs an IP address for the server] *************** 
skipping: [pe-prod-ironic-01]

TASK: [Checking if MAC address is correct] ************************************ 
skipping: [pe-prod-ironic-01]

TASK: [Checking if IPMI address is defined] *********************************** 
skipping: [pe-prod-ironic-01]

TASK: [Checking if md5 image checksum is defined] ***************************** 
skipping: [pe-prod-ironic-01]

TASK: [Check if the new node was defined] ************************************* 
changed: [pe-prod-ironic-01 -> localhost]

TASK: [Checking if server name is already used] ******************************* 
skipping: [pe-prod-ironic-01]

TASK: [Define the new baremetal node] ***************************************** 
changed: [pe-prod-ironic-01 -> localhost]

TASK: [Get the server UUID] *************************************************** 
ok: [pe-prod-ironic-01]

TASK: [configdrive | Include OS specific variables] *************************** 
ok: [pe-prod-ironic-01]

TASK: [configdrive | Setup configdrive instance folder] *********************** 
ok: [pe-prod-ironic-01]

TASK: [configdrive | Create configdrive metadata folders] ********************* 
changed: [pe-prod-ironic-01] => (item=openstack/2012-08-10)
changed: [pe-prod-ironic-01] => (item=openstack/latest)
changed: [pe-prod-ironic-01] => (item=openstack/content)
changed: [pe-prod-ironic-01] => (item=openstack/_)

TASK: [configdrive | Setup temporary folder for include files] **************** 
ok: [pe-prod-ironic-01]

TASK: [configdrive | Check if the ssh public key is defined locally] ********** 
skipping: [pe-prod-ironic-01]

TASK: [configdrive | Read ssh public key locally] ***************************** 
skipping: [pe-prod-ironic-01]

TASK: [configdrive | Check if the ssh public key is on the server] ************ 
skipping: [pe-prod-ironic-01]

TASK: [configdrive | Read ssh public key on the server] *********************** 
skipping: [pe-prod-ironic-01]

TASK: [configdrive | Check if the ssh public key is readable] ***************** 
skipping: [pe-prod-ironic-01]

TASK: [configdrive | Load file ssh public keys] ******************************* 
skipping: [pe-prod-ironic-01]

TASK: [configdrive | List the backend devices] ******************************** 
ok: [pe-prod-ironic-01] => (item=eth0)
ok: [pe-prod-ironic-01] => (item=eth0)

TASK: [configdrive | Create network_info.json if needed] ********************** 
changed: [pe-prod-ironic-01] => (item=openstack/2012-08-10)
changed: [pe-prod-ironic-01] => (item=openstack/latest)

TASK: [configdrive | Create the network configuration folders] **************** 
changed: [pe-prod-ironic-01] => (item=/etc/network/interfaces.d/)

TASK: [configdrive | Setup resolver file resolv.conf] ************************* 
skipping: [pe-prod-ironic-01]

TASK: [configdrive | Setup static hosts file] ********************************* 
skipping: [pe-prod-ironic-01]

TASK: [configdrive | Setup network/interfaces for Debian] ********************* 
changed: [pe-prod-ironic-01]

TASK: [configdrive | Setup undefined backend devices] ************************* 
changed: [pe-prod-ironic-01] => (item=eth0)

TASK: [configdrive | Setup all defined devices] ******************************* 
changed: [pe-prod-ironic-01] => (item={'device': 'eth0.507', 'bootproto': 'dhcp', 'type': 'vlan', 'backend': ['eth0']})
changed: [pe-prod-ironic-01] => (item={'domain': u'domain.com', 'nameservers': ['8.8.8.8'], 'netmask': '255.255.255.0', 'address': u'10.0.0.15', 'device': 'eth0.500', 'type': 'vlan', 'gateway': '10.0.0.1', 'backend': ['eth0']})

TASK: [configdrive | Setup route configuration for RedHat] ******************** 
skipping: [pe-prod-ironic-01] => (item={'device': 'eth0.507', 'bootproto': 'dhcp', 'type': 'vlan', 'backend': ['eth0']})
skipping: [pe-prod-ironic-01] => (item={'domain': u'domain.com', 'nameservers': ['8.8.8.8'], 'netmask': '255.255.255.0', 'address': u'10.0.0.15', 'device': 'eth0.500', 'type': 'vlan', 'gateway': '10.0.0.1', 'backend': ['eth0']})

TASK: [configdrive | List the include files on temporary folder] ************** 
changed: [pe-prod-ironic-01]

TASK: [configdrive | Get the include files on temporary folder] *************** 
ok: [pe-prod-ironic-01]

TASK: [configdrive | Copy files to content from temporary folder] ************* 
changed: [pe-prod-ironic-01] => (item=(0, u'/etc/network/interfaces.d/ifcfg-eth0.507'))
changed: [pe-prod-ironic-01] => (item=(1, u'/etc/network/interfaces.d/ifcfg-eth0'))
changed: [pe-prod-ironic-01] => (item=(2, u'/etc/network/interfaces.d/ifcfg-eth0.500'))
changed: [pe-prod-ironic-01] => (item=(3, u'/etc/network/interfaces'))

TASK: [configdrive | Create meta_data.json] *********************************** 
changed: [pe-prod-ironic-01] => (item=openstack/2012-08-10)
changed: [pe-prod-ironic-01] => (item=openstack/latest)

TASK: [configdrive | Copy user_data if defined] ******************************* 
skipping: [pe-prod-ironic-01] => (item=openstack/2012-08-10)
skipping: [pe-prod-ironic-01] => (item=openstack/latest)

TASK: [configdrive | Create config-2 volume] ********************************** 
changed: [pe-prod-ironic-01]

TASK: [configdrive | Cleanup temporary folder for include files] ************** 
changed: [pe-prod-ironic-01]

TASK: [configdrive | Cleanup instance configdrive folder] ********************* 
skipping: [pe-prod-ironic-01]

TASK: [Define the install image for the node] ********************************* 
changed: [pe-prod-ironic-01 -> localhost]

TASK: [Define the kernel and ramdisk for the image] *************************** 
skipping: [pe-prod-ironic-01]

TASK: [Create the MAC address ports for the new node] ************************* 
changed: [pe-prod-ironic-01 -> localhost]

TASK: [Add reference to config-drive in metadata info] ************************ 
changed: [pe-prod-ironic-01 -> localhost]

TASK: [Define the configdrive parameter] ************************************** 
ok: [pe-prod-ironic-01 -> localhost]

TASK: [Define the configdrive parameter when enabled configdrive] ************* 
ok: [pe-prod-ironic-01 -> localhost]

TASK: [Active and deploy the server] ****************************************** 
changed: [pe-prod-ironic-01 -> localhost]

PLAY RECAP ******************************************************************** 
pe-prod-ironic-01          : ok=36   changed=19   unreachable=0    failed=0   
```
 
 * `del-baremetal.yml`
```
$ ansible-playbook -i hosts/production -e baremetal_mac=00:25:90:8f:51:a0 -e baremetal_name=compute-11 del-baremetal.yml 

PLAY [Poweroff and delete servers using Ironic] ******************************* 

TASK: [List the defined servers] ********************************************** 
changed: [pe-prod-ironic-01 -> localhost]

TASK: [Checking if server name exists] **************************************** 
skipping: [pe-prod-ironic-01]

TASK: [Power off the server] ************************************************** 
changed: [pe-prod-ironic-01 -> localhost]

TASK: [Pause 1 minute] ******************************************************** 
(^C-c = continue early, ^C-a = abort)
[pe-prod-ironic-01]
Pausing for 60 seconds
^C
Action? (a)bort/(c)ontinue: 
ok: [pe-prod-ironic-01 -> localhost]

TASK: [Delete the server] ***************************************************** 
changed: [pe-prod-ironic-01 -> localhost]

TASK: [Delete config-drive] *************************************************** 
changed: [pe-prod-ironic-01]

PLAY RECAP ******************************************************************** 
pe-prod-ironic-01          : ok=5    changed=4    unreachable=0    failed=0   
```


Variables
---------

Have a look at `site.yml` for vagrant setup and `setup-ironic.yml` with the 
inventory defined in `hosts/ironic` and `group_vars` folder for a real setup.
Monit is optional, if you do not need it, just remove the role.


License
-------
GPLv3

Author Information
------------------
José Riguera López <jose.riguera@springer.com>
