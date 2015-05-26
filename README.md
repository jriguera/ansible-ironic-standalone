Ironic-standalone
=================

A set of roles to setup an OpenStack Ironic node in standalone mode, 
just to be able to deploy servers like cobbler but based on images ...

Requirements
------------

It was tested on Ubuntu Trusty, but all roles run on Centos as well 
(to be tested!). Those roles install all requirements from the 
distribution repos and the official Kilo Ubuntu-Cloud repository,
so no development packages are installed, just official packages!

It uses those roles:

 * `roles/mysql` to setup a MySQL server and databases.
 * `roles/rabbitmq` to setup a message queue using RabbitMQ.
 * `roles/monit` (optional) to setup processes control with Monit.
 * `roles/ironic` to setup the OpenStack Ironic daemons.
 * `roles/dnsmasq` to setup a PXE server to use with Ironic.

Note that those roles have no dependecies between each other, so you 
can reuse them in other projects, they have more functionalities than 
the required for this setup. Also, they were created/adapted following 
devops practices.
 
The ironic client is not updated to the latest version (Kilo) on the
Ubuntu Cloud repository, you have to build it from source, but it is 
not part on this setup.

Howto Run
---------

Just type: `vagrant up` to run all the setup, after that just type
`vagrant ssh ironic` to have a look at the settings.

When vagrant will be finished, you will have those ports available:

 * http:/127.0.0.1:2812 - monit (admin:admin) 
 * http:/127.0.0.1:15672 - rabbitmq (ironic:rabbitmq)
 * mysql://127.0.0.1:3306 - mysql (ironic:mysql)
 * http://127.0.0.1:6385 - ironic api
 

Remember that the client needs those environment variables:
```
export OS_AUTH_TOKEN=" "
export IRONIC_URL=http://server:6385/
```

And remember you have to copy the images that you create and use for the 
clients (ramdisk and deploy) to a folder in the server and reference them as 
`file:///.../image.bin` (this is example with an updated client `pip install python-ironicclient`):

```
# Define the parameter for the new server
NAME=nettest1
MAC=00:25:90:8f:51:a0
IPMI=10.0.0.2
 
# Ironic in standalone mode!
export OS_AUTH_TOKEN=" "
export IRONIC_URL=http://localhost:6385/
 
# Define the new server
ironic node-create -n $NAME -d pxe_ipmitool -i ipmi_address=$IPMI -i ipmi_username=ADMIN -i ipmi_password=ADMIN -i deploy_kernel=file:///home/jriguera/images/my-deploy-ramdisk.kernel -i deploy_ramdisk=file:///home/jriguera/images/my-deploy-ramdisk.initramfs
 
UUID=$(ironic node-list | awk "/$NAME/ { print \$2 }")
 
# Define the MAC
ironic port-create -n $UUID -a $MAC
 
MD5=$(md5sum /home/jriguera/images/my-image.qcow2 | cut -d' ' -f 1)
 
# Define the rest of the parameters
ironic node-update $UUID  add instance_info/image_source=file:///home/jriguera/images/my-image.qcow2 instance_info/kernel=file:///home/jriguera/images/my-image.vmlinuz instance_info/ramdisk=file:///home/jriguera/images/my-image.initrd instance_info/root_gb=100 instance_info/image_checksum=$MD5
 
# Validate the node
ironic node-validate $UUID
 
# Create the config drive!!
 
# Deploy the node
ironic node-set-provision-state --config-drive /configdrive_$NAME $UUID active
```

To build the images (you will need `ramdisk-image-create` and `disk-image-create` -install them from source-):

```
# Create the initial ramdkisk
export ELEMENTS_PATH="/home/jriguera/diskimage-builder/elements" 
ramdisk-image-create ubuntu deploy-ironic grub-install -o my-deploy-ramdisk
 
# Create the image to deploy on disk (with ConfigDrive support)
DIB_CLOUD_INIT_DATASOURCES="ConfigDrive, OpenStack" disk-image-create ubuntu baremetal dhcp-all-interfaces -o my-image
```

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
