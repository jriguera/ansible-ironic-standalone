Ironic for dumies
=================

This guide is focused on Ironic as standalone service to deploy baremetal 
servers. It describes how it works and if you think that something is 
incomplete or incorrect, please feel free to create a PR (pull request) with 
your changes.

http://docs.openstack.org/developer/ironic/deploy/user-guide.html



Ironic Components
-----------------

Ironic is an OpenStack project with those components:

Ironic-API
  The Ironic RESTful API service is used to enroll hardware that Ironic will 
  manage. A cloud administrator using an Ironic client usually registers the 
  hardware, specifying their attributes such as MAC addresses and IPMI 
  credentials. There can be multiple instances of the API service. The API 
  exposes a list of supported drivers and the names of conductor hosts 
  servicing them.

Ironic-Conductor
  Ironic Conductor service does the bulk of the work. You can see it as a worker
  for the *ironic-api*. It is advisable to place the conductor service on an 
  isolated host, since it is the only service that requires access to both the 
  data plane and IPMI control plane. There can be multiple instances of the 
  conductor service to support various class of drivers and also to manage fail 
  over. Instances of the conductor service should be on separate nodes. Each 
  conductor can itself run many drivers to operate heterogeneous hardware. The
  commond drivers to use are *pxe_ipmitool* and the new and promissing 
  *agent_ipmitool*.

RabbitMQ
  All the OpenStack components need a messaging queue. AMQP is the messaging 
  technology chosen and the AMQP broker (RabbitMQ) allows all the componentes 
  communicate to one-another using Remote Procedure Calls (RPC) using a 
  publish/subscribe paradigm. Each service (no each process) creates the queues
  and use them to send and receive messages with routing keys for each 
  server/process. The API acts as a consumer when RPC calls are 
  request/response, otherwise it acts as a publisher only.

MySQL
  Most of the OpenStack components need a database to store the persistent data.
  Ironic will store all the data related to each object (node, chassis, ...). 
  That data is going to be accessed from the Conductors and API to read/write 
  the final status. SQLite is being used as default backend in all components, 
  just for testing purposes, it is hight advisable to setup an database server 
  as MySQL.

http://docs.openstack.org/developer/ironic/_images/deployment_architecture_2.png

Ironic can make use of other OpenStack components like *keystone* to control 
authority of the clients and allow/deny the use of the API, *glance* (or *swift* 
-object storage-) to store the images to use and deploy by the Conductor, 
*neutron* to setup the network (for example the ports on the switchs) ... 
This implementation does not make use of those componentes because:

 - All clients are allowed to enroll/deploy/decomission servers. The admin user
 just need to know the URL of the Ironic-api and provide an empty token.
 - The network is plain, there was no need of controlling switches and ports.
 The Ironic server and client are connected directly to the PXE network using
 one NIC. The same applies for the IPMI network, it is possible to setup another
 NIC to access that network. 
 - The images are saved on the Ironic server, on local disk, and are available to
 other servers by HTTP when using Ironic Python Agent driver (IPA) or by TFTP 
 when using PXE with the default driver (by Ironic-conductor).



Ansible implementation
----------------------

The implementation was made in Ansible as a set of roles that are located in 
this repository. Ansible is just the way to put some glue between all the
components. The code is following the convention described in --- . These
are the roles which have been created:

 - ``roles/mysql`` to setup a MySQL server and create the databases.
 - ``roles/rabbitmq`` to setup a message queue using RabbitMQ.
 - ``roles/ironic`` to setup the OpenStack Ironic daemons (API and Conductor).
 - ``roles/dnsmasq`` to setup a DHCP/PXE server for Ironic-Conductor.
 - ``roles/nginx`` (*optional*) to setup a HTTP server to serve images (for IPA).
 - ``roles/monit`` (*optional*) to setup process control with Monit.

Also, because the roles have no dependencies with others (internally an 
externally) you can choose which roles to apply. For example, if you already 
have a MySQL/RabbitMQ infrastructure (maybe because you are using OpenStak), you 
can skip those roles and use your current environment, the same applies for 
Nginx (HTTP server). Monit is just in charge of controling the processes, so you 
can also skip it. 

It is important to explain that this implementation is not ready to use iPXE 
protocol, Nginx is here because the driver *agent_ipmitool* needs an HTTP server 
for the IPA (Ironic Python Agent). Of course, setup iPXE should not be 
difficult, feel free to create a PR and if you do not want to use the driver 
*agent_ipmitool* you can skip the Ngnix role and its parameters.

The playbook ``setup-ironic.yml`` defines the roles (and variables) to apply to
4 groups of serves (``group_vars/database``, ``group_vars/messaging``, 
``group_vars/http``, ``group_vars/provisioning``). Each group can define a 
different server to apply the role/s. Depending of your infrastructure you may
need to change the NIC where the Conductor, Dnsmasq for DHCP/PXE and Nginx for 
HTTP serve of the images will be listening.

The aim of this implementation is to provide a cobbler substitute using 
OpenStack components:

  - Deterministic. Using the same deploy image and with the optional Cloud-Init 
  configuration, the user always will get the same result by re-deploying a 
  server.
  - IPMI Control. The Ironic-Conductor drivers support IPMI/ILO/... protocols so
  it is possible to control the hardware states and even get metrics.
  - Agnostic deploys. Ironic is able to deploy all Linux distros, even Windows
  servers since Cloud-Init is also supported on them.
  - Future integration with OpenStack infrastructure. In the future you can 
  reuse the same Database and Messaging Queue than the Openstack infrastructure. 
  Eventually you can implement a full integration within OpenStack by also using
  Identity, Glance, Swift ...


Using Ironic
============

The following section shows howto use Ironic from a client prespective, using 
the Ironic command line client and a server deployed by using the Ansible 
playbook provided. If you want to run the Ironic client on the server, you
should install the latest python-ironicclient package -at least version 0.5.0-.
At the moment of this writting it is not availabe on the official repo, so you
have to install it using pip::

sudo apt-get install python-pip
sudo pip install python-ironicclient

Now we can see how the client works, but first we have to define the URL of the 
Ironic-API where the client needs connect to, the best way is define some
environmet variables::

export IRONIC_URL=http://localhost:6385/
export OS_AUTH_TOKEN=" "

Because there is no Identity service running (*keystone*) the variable 
*OS_AUTH_TOKEN* contains a fake token to allow ironic client to operate.

Let's list the available drivers::

# ironic driver-list
+---------------------+----------------+
| Supported driver(s) | Active host(s) |
+---------------------+----------------+
| agent_ipmitool      | ironic         |
| pxe_ipmitool        | ironic         |
+---------------------+----------------+


There are two available drivers which are explained below, but first let's see 
how to create a chassis::

# ironic chassis-create -d "My test chassis" -e location=dogo -e env=test
+-------------+-----------------------------------------+
| Property    | Value                                   |
+-------------+-----------------------------------------+
| uuid        | 1eb3951f-2406-4cf1-b4a1-115e90a65480    |
| description | My test chassis                         |
| extra       | {u'location': u'dogo', u'env': u'test'} |
+-------------+-----------------------------------------+
# ironic chassis-list
+--------------------------------------+-------------------+
| UUID                                 | Description       |
+--------------------------------------+-------------------+
| 1eb3951f-2406-4cf1-b4a1-115e90a65480 | My test chassis   |
+--------------------------------------+-------------------+

A chassis is a logical agregation of baremetal servers and you can define and 
assign some variables to it. Now we know the infrastruture is working properly
so its time to review the Ironic object model:





There are Chassis, Nodes, Drivers and Ports. Nodes can be part of one Chassis,
a Node has Drivers and Ports. A port is an object to associate one or more
MAC addresses to a Node (for PXE booting in this case).


Ironic-Conductor drivers
------------------------

In this implementation, assuming the default settings defined in the playbook, 
two Ironic-Conductor drivers are enabled: *pxe_ipmitool* and *agent_ipmitool*. 
Both drivers use two kind of images: a *deploy_ramdisk* image as first image to 
boot the baremetal server and a final *image* to install the operating system 
on it. Ironic issues the baremetal server to boot with the deploy_ramdisk image 
and it is in charge of installing the final image on the server. The difference 
between those drivers is in the way they use the ramdisk image, let's see ...


Driver: *pxe_ipmitool*
----------------------

This is the default driver. It uses IPMI to control the power state of the 
baremetal server, first of all, it issues the baremetal server to re-boot
using PXE network. Then it creates the PXE configuration for the PXE server (in
this case for Dnsmasq) on --- . After those steps Ironic keeps waiting for
the server to boot up and run the ramdisk image. To sum up:

   1. Ironic reboots the server by issuing ipmi commands (using ipmitool) 
   to boot from the network using PXE.
   2. It creates the PXE boot configuration for the target baremetal server on 
   the Ironic-Conductor host: ramdisk, kernel and other boot parameters, using 
   the *deploy_ramdisk* and *deploy_kernel* images.
   3. Ironic-Conductor keeps waiting for the ramdisk operating system to boot.
   4. When the ramdisk kernel is running, it notifies Ironic and also exposes 
   the first hardisk (---) using the TGT iSCSI framework to the 
   Ironic-Conductor.
   5. Using local commands on the iSCSI target attached to the Ironic-Conductor
   host, the driver creates de partition schema and dumps the image on the 
   disk target. Also, if a Config-Drive was provided, Ironic will create another
   partition with a especial label to save that information.
   6. When the dump is done, it notifies the ramdisk/kernel operating system
   to run grub (only if it was a whole disk image) and to reboot the server. 
   7. Ironic-Conductor changes the PXE boot configuration on the hosts to boot 
   the baremetal server using the kernel/ramdisk provided (if it not a whole
   disk image) or to boot directly for the first disk (using ``local`` 
   parameter).
   8. When the local operating system boots on the node, due to the use of
   Cloud-Init with Config-Drive support, it scans all the partitions to try
   to find and apply its configuration.

The diagram below ilustrates the process:
   


There are some limitations on that way:

  - It is not able to create complex disk partitions. The partition scheme is 
  hardcoded in the driver. There are some parameters to control the size or
  which partitions to create (for example, ephemeral partitions). It is not 
  possible to setup LVM/SofwareRAID, though that is out of the Ironic scope.
  - It has problems to deploy whole image files on the baremetal server. For
  example, if the image is for a whole disk, it cannot find out the UUID of
  the root device to setup PXE to boot from that device. 
  - The host running Ironic-Conductor has to have installed all the needed 
  programs: issci, parted, dd, ... to operate directly on the target disk.


Create images to use *pxe_ipmitool*
-----------------------------------

The image creation process can be fully automated by using ``disk-image-create``
from Image building tools for OpenStack  https://github.com/openstack/diskimage-builder::

# Create the image to deploy on disk (with Config-Drive support)
DIB_CLOUD_INIT_DATASOURCES="ConfigDrive, OpenStack" disk-image-create ubuntu baremetal dhcp-all-interfaces -o ubuntu

Note the variable *DIB_CLOUD_INIT_DATASOURCES* which issues ``disk-image-create``
to include the Config-Drive provider of Cloud-Init. Also, note all the 
parameters of the program: ``ubuntu``, ``baremetal``, ``dhcp-all-interfaces``;
those are known as *elements* and you can include a lot of them, have a look 
here https://github.com/openstack/diskimage-builder/tree/master/elements
Of course, there are some elements mutually exclusive, for example ``ubuntu`` 
vs ``centos7``.``baremetal`` is needed to get the ramdisk and kernel files that 
Ironic needs to boot the image once it is installed, so 3 files will appear 
after run the command: the image ``ubuntu.qcow2``, the kernel ``ubuntu.vmlinuz`` 
and the ramdisk ``ubuntu.initrd``.

In the same way, it is needed to create a deploy ramdisk image::

ramdisk-image-create ubuntu deploy-ironic -o ubuntu-deploy-ramdisk

It will create a ramdisk image ``ubuntu-deploy-ramdisk.initramfs`` and a kernel 
``ubuntu-deploy-ramdisk.kernel``.

To operate with those images, copy all the generated files to the folder 
``/var/lib/ironic/images/`` on the Ironic server.


Operation
---------
 
Let's see how to use the *pxe_ipmitool* driver by defining a new baremetal 
server:

# UUID of the chassis defined above
CHASSIS=1eb3951f-2406-4cf1-b4a1-115e90a65480
# Name of the new server
NAME=test1
# MAC address for PXE
MAC=00:25:90:8f:51:a0
# IPMI ip with (ADMIN/ADMIN as user/password)
IPMI=10.0.0.2
# Define the new server on the chassis using the driver pxe_ipmitool
ironic node-create -c $CHASSIS -n $NAME -d pxe_ipmitool -i ipmi_address=$IPMI -i ipmi_username=ADMIN -i ipmi_password=ADMIN -i deploy_kernel=file:///var/lib/ironic/images/ubuntu-deploy-ramdisk.kernel" -i deploy_ramdisk=file:///var/lib/ironic/images/ubuntu-deploy-ramdisk.initramfs
+--------------+-----------------------------------------------------------------------------------+
| Property     | Value                                                                             |
+--------------+-----------------------------------------------------------------------------------+
| uuid         | 7cefe9c2-031e-4160-b42e-6a7035a7873b                                              |
| driver_info  | {u'deploy_kernel': u'file:///var/lib/ironic/images/ubuntu-deploy-ramdisk.kernel', |
|              | u'ipmi_address': u'10.0.0.2', u'ipmi_username': u'ADMIN',                         |
|              | u'ipmi_password': u'******', u'deploy_ramdisk': u'file:///var/lib/ironic          |
|              | /images/ubuntu-deploy-ramdisk.initramfs'}                                         |
| extra        | {}                                                                                |
| driver       | pxe_ipmitool                                                                      |
| chassis_uuid | 1eb3951f-2406-4cf1-b4a1-115e90a65480                                              |
| properties   | {}                                                                                |
| name         | test1                                                                             |
+--------------+-----------------------------------------------------------------------------------+
# Get the UUID of the new node
UUID=$(ironic node-list | awk "/$NAME/ { print \$2 }")
# Define the port: the link between the MAC and the server
ironic port-create -n $UUID -a $MAC
+-----------+--------------------------------------+
| Property  | Value                                |
+-----------+--------------------------------------+
| node_uuid | 7cefe9c2-031e-4160-b42e-6a7035a7873b |
| extra     | {}                                   |
| uuid      | 324a4602-8cec-47d7-b496-241c081cbcee |
| address   | 00:25:90:8f:51:a0                    |
+-----------+--------------------------------------+


Now it's time to define the final image to install on the baremetal server::

# Ironic needs the checksum of the image
MD5=$(md5sum /var/lib/ironic/images/ubuntu.qcow2 | cut -d' ' -f 1)
# Define the image to install on the server
ironic node-update $UUID add instance_info/image_source=file:///var/lib/ironic/images/ubuntu.qcow2 instance_info/kernel=file:///var/lib/ironic/images/ubuntu.vmlinuz instance_info/ramdisk=file:///var/lib/ironic/images/ubuntu.initrd instance_info/root_gb=10 instance_info/image_checksum=$MD5
+------------------------+------------------------------------------------------------------------+
| Property               | Value                                                                  |
+------------------------+------------------------------------------------------------------------+
| target_power_state     | None                                                                   |
| extra                  | {}                                                                     |
| last_error             | None                                                                   |
| updated_at             | 2015-05-28T12:53:23+00:00                                              |
| maintenance_reason     | None                                                                   |
| provision_state        | available                                                              |
| uuid                   | 7cefe9c2-031e-4160-b42e-6a7035a7873b                                   |
| console_enabled        | False                                                                  |
| target_provision_state | None                                                                   |
| maintenance            | False                                                                  |
| inspection_started_at  | None                                                                   |
| inspection_finished_at | None                                                                   |
| power_state            | power off                                                              |
| driver                 | pxe_ipmitool                                                           |
| reservation            | None                                                                   |
| properties             | {}                                                                     |
| instance_uuid          | None                                                                   |
| name                   | test1                                                                  |
| driver_info            | {u'ipmi_password': u'******', u'ipmi_address': u'10.0.0.2',            |
|                        | u'ipmi_username': u'ADMIN', u'deploy_kernel': u'file:///var/lib/ironic |
|                        | /images/ubuntu-deploy-ramdisk.kernel', u'deploy_ramdisk': u'file:///va |
|                        | r/lib/ironic/images/ubuntu-deploy-ramdisk.initramfs'}                  |
| created_at             | 2015-05-28T12:52:23+00:00                                              |
| driver_internal_info   | {}                                                                     |
| chassis_uuid           | 1eb3951f-2406-4cf1-b4a1-115e90a65480                                   |
| instance_info          | {u'ramdisk': u'file:///var/lib/ironic/images/ubuntu.initrd',           |
|                        | u'kernel': u'file:///var/lib/ironic/images/ubuntu.vmlinuz',            |
|                        | u'root_gb': 10, u'image_source': u'file:///var/lib/ironic/images/      |
|                        | ubuntu.qcow2', u'image_checksum': u'a2b651231f7cdd5fc45a3ce961b2b2da'} |
+------------------------+------------------------------------------------------------------------+
# Validate the node parameters
ironic node-validate $UUID
+------------+--------+---------------------------------------------------------------+
| Interface  | Result | Reason                                                        |
+------------+--------+---------------------------------------------------------------+
| console    | False  | Missing 'ipmi_terminal_port' parameter in node's driver_info. |
| deploy     | True   |                                                               |
| inspect    | None   | not supported                                                 |
| management | True   |                                                               |
| power      | True   |                                                               |
+------------+--------+---------------------------------------------------------------+

Remember you can define more parameters on the node: swap space, ephemeral
size and format, etc. In this example, the console is failing because the 
hardware that we are using does not support remote console, if your hardware 
supports that, you can define the UDP por using *ipmi_terminal_port* and by
issuing a command you could get a link to see the remote console (in the
current implementation it uses internally ``shellinabox`` program).

At this time we have to provide the node provisioning configuration by using
Config-Drive provider for Cloud-Init. More information about Cloud-Init here
but it is a program which run in the boot process to configure all the settings.
The Ironic client needs a parameter pointing to a folder with all Cloud-Drive
structure, then it will pack those files and write them in the step 5 (after 
creating the partitions and dump the final image on the baremetal server).
More information about Cloud-Drive on OpenStack here: 
Let's create manually those configuration files::

# Create a temp folder structure
mkdir -p /tmp/$NAME/latest /tmp/$NAME/content /tmp/$NAME/latest
# Create the main file
cat EOF >> /tmp/$NAME/latest
EOF
cp /tmp/$NAME/latest /tmp/$NAME/latest


Currently the community is working on a way to define the network information
(and much more) in an agnostic way, not depending on the distribution:



Ironic will assume that the image is not a whole disk image 
'is_whole_disk_image == False' (on *driver_internal_info*) because there are a
kernel and a ramdisk parameters defined. That is not a problem, because the
images were created using the Image building tools for OpenStack and those are
not whole disk images. If you want to deploy whole disk images, you have to
use the ``agent_ipmitool`` driver.












Thanks to: http://www.slideshare.net/enigmadragon/ironic
