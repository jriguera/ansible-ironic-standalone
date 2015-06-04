Ironic-standalone
=================

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
(`/var/lib/ironic/images/`) in the server and reference them as
`file:///var/lib/images/ironic/image.bin` on the client. Let's see an example 
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
       -i deploy_kernel=file:///var/lib/ironic/images/my-deploy-ramdisk.kernel \
       -i deploy_ramdisk=file:///var/lib/ironic/images/my-deploy-ramdisk.initramfs

# Get the UUID of the new host
UUID=$(ironic node-list | awk "/$NAME/ { print \$2 }")
 
# Define the link between the baremetal server and the PXE MAC address
ironic port-create -n $UUID -a $MAC

# Ironic needs the MD5 checksum, otherwise the deploy will fail
MD5=$(md5sum /var/lib/ironic/images/my-image.qcow2 | cut -d' ' -f 1)
 
# Define the rest of the parameters, like the final image to
# install on the baremetal host
ironic node-update $UUID add \
       instance_info/image_source=file:///var/lib/ironic/images/my-image.qcow2 \
       instance_info/kernel=file:///var/lib/ironic/images/my-image.vmlinuz \
       instance_info/ramdisk=file:///var/lib/ironic/images/my-image.initrd \
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

Copy all created images, ramdisk and kernels to `/var/lib/ironic/images/`
on the Ironic server.


Variables
---------

Have a look at `site.yml` for vagrant setup and `ironic.yml` with the 
inventory defined in `hosts/ironic` and `group_vars` folder for a real setup.
Monit is optional, if you do not need it, just remove the role.


License
-------
GPLv3

Author Information
------------------
José Riguera López <jose.riguera@springer.com>
