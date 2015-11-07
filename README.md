Ansible-Ironic-Standalone
=========================

A set of roles to setup an OpenStack Ironic node in standalone mode, 
just to be able to deploy servers like cobbler but based on images ...

Have a look at the wiki to know more about this setup: 
https://github.com/jriguera/ansible-ironic-standalone/wiki

This repository uses tags!

| Tag  | Openstack Release | Ironic version |   Upgrade    |  
|------|-------------------|----------------|--------------|
| v1.x | Kilo (2015.4)     | 2015.1.n       | -            |
| v2.x | Liberty (2015.10) | 4.2.n          | v1.x -> v2.x |


Requirements
------------

It was tested on Ubuntu Trusty, but all roles run on Centos as well 
(to be tested!). These roles install all requirements from the 
distribution repos and the official Liberty Ubuntu-Cloud repository,
so no development packages are installed, just official packages!

Roles used:

 * `roles/mysql` to setup a MySQL server and databases.
 * `roles/rabbitmq` to setup a message queue using RabbitMQ.
 * `roles/monit` (optional) to setup processes control with Monit.
 * `roles/ironic` to setup the OpenStack Ironic daemons.
 * `roles/ironic-inspector` to setup the Ironic-Inspector daemon.
 * `roles/dnsmasq` to setup a PXE server to use with Ironic.
 * `roles/nginx` (optional) to setup HTTP image repo server (for IPA).

Note that those roles have no dependecies between each other, so you 
can reuse them in other projects, they have more functionalities than 
the required for this setup. Also, they were created/adapted following 
devops practices.
 
The Ironic client package is not updated to the latest version on the
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
with a client running on the server (installed with 
`pip install python-ironicclient`):

```
# This example uses the agent_ipmitool driver!

# Define the parameter for the new server
NAME=test1
MAC=00:25:90:8f:51:a0
IPMI=10.0.0.2
 
# Ironic in standalone mode!
export OS_AUTH_TOKEN=" "
export IRONIC_URL=http://localhost:6385/
 
# Define the new server using the pxe_ipmitool driver
ironic node-create -n $NAME \
       -d agent_ipmitool \
       -i ipmi_address=$IPMI \
       -i ipmi_username=ADMIN \
       -i ipmi_password=ADMIN \
       -i deploy_kernel=file:///var/lib/ironic/http/deploy/coreos_production_pxe.vmlinuz \
       -i deploy_ramdisk=file:///var/lib/ironic/http/deploy/coreos_production_pxe_image-oem.cpio.gz

# Get the UUID of the new host
UUID=$(ironic node-list | awk "/$NAME/ { print \$2 }")
 
# Define the link between the baremetal server and the PXE MAC address
ironic port-create -n $UUID -a $MAC

# Ironic needs the MD5 checksum, otherwise the deploy will fail
MD5=$(md5sum /var/lib/ironic/http/images/my-image.qcow2 | cut -d' ' -f 1)
 
# Define the rest of the parameters, like the final image to
# install on the baremetal host
# To create the image: https://github.com/jriguera/packer-ironic-images
ironic node-update $UUID add \
       instance_info/image_source=http://localhost/images/trusty.qcow2
       instance_info/image_checksum=$MD5
 
# Validate the node
ironic node-validate $UUID
 
# Create the config drive!!
# See the documentation about how to do it!
CONFIG_DRIVE=/path/to/folder
 
# Deploy the node, set state to active
ironic node-set-provision-state --config-drive $CONFIG_DRIVE $UUID active
```

Images
------

If you want to create images easily, have a look to:
https://github.com/jriguera/packer-ironic-images

Otherwise, you can also build images using the Openstack tools 
`ramdisk-image-create` and  `disk-image-create` (install them from the 
repo: https://github.com/openstack/diskimage-builder ):

```
# Create the initial ramdkisk (not needed with agent_ipmitool driver)
# Just useful for pxe_ipmitool driver!
export ELEMENTS_PATH="/home/jriguera/diskimage-builder/elements" 
ramdisk-image-create ubuntu deploy-ironic grub-install -o my-deploy-ramdisk
 
# Create the final Ubuntu image to deploy on baremetal host disk 
# (with ConfigDrive support!!)
DIB_CLOUD_INIT_DATASOURCES="ConfigDrive, OpenStack" \
disk-image-create ubuntu baremetal dhcp-all-interfaces -o trusty
```

Copy `trusty.*` (image, ramdisk and kernel) to `/var/lib/ironic/http/images/`
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
$ ansible-playbook -i hosts/ironic -e id=test-server-01 add-baremetal.yml
Server Name: test-server-01

PLAY [Define and deploy physical servers using Ironic] ************************ 

TASK: [Include network definitions] ******************************************* 
ok: [provisioning]

TASK: [Include image definitions] ********************************************* 
ok: [provisioning]

TASK: [Define the MD5 checksum URI if needed] ********************************* 
ok: [provisioning]

TASK: [Get the url image MD5 checksum if needed] ****************************** 
changed: [provisioning]

TASK: [Load the previous MD5 checksum] **************************************** 
ok: [provisioning]

TASK: [Workout the checksum with the image url if needed] ********************* 
skipping: [provisioning]

TASK: [Load the previous MD5 checksum] **************************************** 
skipping: [provisioning]

TASK: [Get the file image MD5 checksum if needed] ***************************** 
skipping: [provisioning]

TASK: [Load the url MD5 checksum is needed] *********************************** 
skipping: [provisioning]

TASK: [Workout the checksum with the image if needed] ************************* 
skipping: [provisioning]

TASK: [Load the url MD5 checksum is needed] *********************************** 
skipping: [provisioning]

TASK: [Check if servername configdrive exists] ******************************** 
ok: [provisioning -> 127.0.0.1]

TASK: [Load servername configdrive] ******************************************* 
ok: [provisioning]

TASK: [Define the server domain] ********************************************** 
skipping: [provisioning]

TASK: [Define the server name] ************************************************ 
ok: [provisioning]

TASK: [Define the server name as MAC] ***************************************** 
skipping: [provisioning]

TASK: [Get the current date] ************************************************** 
changed: [provisioning]

TASK: [Define the date] ******************************************************* 
ok: [provisioning]

TASK: [Assign network parameters] ********************************************* 
ok: [provisioning]

TASK: [Assign network parameters with DHCP] *********************************** 
skipping: [provisioning]

[...]
```
 
 * `del-baremetal.yml`
```
$ ansible-playbook -i hosts/ironic -e id=test-server-01 del-baremetal.yml 

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
