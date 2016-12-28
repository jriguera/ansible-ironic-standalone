# Ansible-Ironic-Standalone

A set of roles to set-up an OpenStack Ironic node in standalone mode, 
just ready to deploy physical servers like other sofware (e.g. cobbler) 
but ... more powerful!

Have a look at the wiki to know more about this setup: 
https://github.com/jriguera/ansible-ironic-standalone/wiki

This repository uses tags!

| Tag  | Openstack Release | Ironic version |   Upgrade                  |
|------|-------------------|----------------|----------------------------|
| v1.x | Kilo (2015.4)     | 2015.1.n       |             -              |
| v2.x | Liberty (2015.10) | 4.2.n          |        v1.x -> v2.x        |
| v3.x | Mitaka (2016.5)   | 5.1.n          | v1.x -> v3.x, v2.x -> v3.x |
| v4.x | Newton (2016.10)  | 6.2.n          | v3.x -> v4.x               |

Since v4 (OpenStack Newton), only Ubuntu Xenial (16.04) and Centos 7.x are the
operating systems supported to run the Ansible roles/playbooks.


For more information about Ironic go to:
http://docs.openstack.org/developer/ironic/deploy/install-guide.html


## Thanks

Thanks to all OpenStack community for making this integration possible
by creating every piece of software used in this project!

This is a screenshot of [Ironic WebClient](https://github.com/openstack/ironic-webclient)
included with the role `webclient`.

![Ironic WebClient](https://github.com/jriguera/ansible-ironic-standalone/blob/master/doc/ironic_webclient.png)


# Requirements

Ansible 2.1. See `requirements.txt`.

There is no backwards compatibility with previous Ansible versions, but it is 
safe run the roles against a previous installation deployed with  Ansible 1.9. 
For the client playbooks `add-baremetal` and `del-baremetal` you also have to 
install the Ironic client package on the server where they will run. No local 
dependencies are required to run `setup-ironic` (except Ansible 2.0).

Every requirements on the server are managed by the roles, they were tested on
Ubuntu Xenial (16.04) and Centos 7. The roles use the official 
OpenStack repositories for each distribution (ubuntu-cloud and RDO, MySQL is not 
officially included in Centos 7, the official MySQL repository is used), no 
development packages are installed. The *mysql* role uses MySQL 5.7 .


# Project structure

The core of the project are the following roles:

 * `roles/mysql` to setup a MySQL server (versions 5.6 or 5.7) and databases.
 * `roles/rabbitmq` to setup a message queue using RabbitMQ.
 * `roles/monit` (optional) for basic monitoring of the system and controll 
    the processes with Monit.
 * `roles/ironic` to setup the OpenStack Ironic daemons.
 * `roles/inspector` to setup the Ironic-Inspector daemon.
 * `roles/dnsmasq` to setup a PXE server to use with Ironic.
 * `roles/nginx` (optional) to setup HTTP image repo server (for IPA).
 * `roles/webclient` (optional) to setup ironic_webclient application
 
These roles have no dependencies between each other, so you can reuse them in 
other projects, they have more functionalities than the required for this 
set-up. Moreover, you can easily add new roles here to offer more 
functionalities, for example, to give support for MariaDB, just create the new
role and call it from the playbook, if variables have changed repect to MySQL
you will need to touch the playbook, that's all. Those roles were 
created/adapted following devops practices in mind (idempotency, same 
structure, ...).

Also, be carefull with interrupting a role when is running. Those roles define
a sort of stateful functionality (setting facts within their internal tasks), 
ususally to check if the packages were (re)installed or upgraded or if there 
were a previous configuration file. The reason for this behaviour is to perform 
actions in special cases (e.g. create Ironic DB's for first time, run 
`myslq_upgrade` when a new version was reinstalled). If you run into problems 
when they run for first time, just uninstall the packages and delete the main 
configuration file to get a clean installation and try again.


There are 4 main playbooks here:

 * `setup.yml` to deploy a real server configuring all the software. 
 Probably you will have to adapt some parameters there like dnsmasq 
 interfaces (e.g. *eth1*, *em1* ...). The rest of the parameters 
 (IP's, DNS, ...) are defined in the Ansible inventory (see *inventory/inventory.ini*)
 and/or in *inventory/group_vars* folder.
 * `add-baremetal.yml` to manually define and deploy a server with Ironic. 
 When it runs, it will ask you for an id (name) which has to match to a file 
 with a server parameters definition (IPMI, networks, bonding ...) in *inventory/host_vars*
 folder (or using the symbolic link *servers*). Optionally you can also define 
 a *.cloudconfig* configuration in the same folder.
 * `del-baremetal.yml` to delete a server defined in Ironic with the previous
 playbook. When it runs, it will power off the server and remove it from Ironic.
 It does not trigger additional cleaning steps like wipe the disks.
 * `site.yml` is just for a demo playbook for Vagrant/VirtualBox, see below.


Notes:

 * Since version 4 (Newton) the structure of the repository has changed 
 according to the Ansible recommendations. *inventory* is a folder to keep
 the inventory(ies) with the main variables and the server(s) 
 involved in the deployment (see *inventory.ini*). The functionality is defined
 in 4 groups: `database`, `messaging`, `ironic-api`, `ironic-conductor` with 
 the variables for each group in *inventory/group_vars*. This setup allows you
 to add servers to each group and setup clusters for Ironic API and Conductor.
 The *vars* folder keeps the variables to define the images to deploy and the
 rules to enroll new discovered servers by inspector. Change the rules
 according to your infrastructure.
 
 * Ironic Python Agent has two official flavors Coreos IPA and Tiny IPA, both 
 are downloaded, but the one defined as default in the inventory 
 (*Ironic_deploy_kernel* and *Ironic_deploy_ramdisk* variables) is Coreos IPA.
 TinyIPA is also a good choice, it is really small and can speed up the
 baremetal deployments.
 
 * Although this set-up installs all the requirements for `pxe_ipmitool` driver, 
 now it is only focused on the `agent_ipmitool` driver, which requires a 
 HTTP server (*nginx* role) and a special deploy image running Ironic Python 
 Agent (IPA), which is downloaded automatically within the *ironic* role.
 
 * This version uses MySQL 5.7 for Centos and Ubuntu Xenial since the
 the previous versions of these operating systems is no longer supported.
 The *mysql* role is capable of migrating some versions (depending on the
 distribution), by deleting `ib_logfiles`, starting MySQL again and running
 `mysql_upgrade`. Anyway, is much safer doing an export of the databases, import 
 them again and manually run `ironic-dbsync` and `ironic-inspector-dbsync`.
 
 * There is a new web interface installed with the role `webclient`. It is taken
 from https://github.com/openstack/ironic-webclient , is not completely functional
 yet, but it helps showing the nodes currently defined in Ironic and it does not
 waste resources (it is only javascript running on your browser). With 
 Vagrant, go to http://localhost:8080/www (URI is /www).

 * `setup-ironic` configures the `nginx` role to support WebDAV on the HTTP
 repository for images and metadata, so you can `PUT` the files with curl,
 without connecting the server. The approach is just to have a kind of
 repository compatible with HTTP API calls. Of course it supports basic access 
 authentication. There is a preliminary setup of a reverse proxy to the Ironic
 API using the `/v1/` endpoint, but, because of some issues in Ironic client is 
 not used.

 * Since version 3 (Mitaka) supports the Ironic Inspector package (deployed 
 with the new role *inspector* ) which provides instropection and if the variable 
 *ironic_inspector_discovery_enroll* is True will also provide automatic 
 discovery for new baremetal servers. Of course, you can stil use the 
 `add-baremetal` or `del-baremetal` to manually define the nodes.
 
 * Support for *shellinabox*, it means you can open web console using a web 
 browser to see the installation process after requesting it 
 `ironic node-get-console <node-uuid>`. The ports are automatically assigned
 by `add-baremetal` playbook based on the last part of the IPMI IP address
 plus 10000 (e.g. a server with IPMI IP address: 10.100.200.33 will get
 defined its port as 10033). This funcion is automatically defined with
 `add-baremetal`.

 * The two playbooks to define and delete servers in Ironic are completely 
 functional but, the main purpose of them is to make easy and show the entire 
 process. You can use them in production, but they are not *elegant*, they 
 depend on the Ironic client locally installed to do all the actions but you 
 could use the new Ansible modules for that!).

 * The services installed by `setup` are managed with Monit (yes even on 
 the systemd systems!). So when you stop a process not via Monit, it'll be 
 started again!, use the command line and remember, Monit has a web interface ... 
 use it!

 * Because of the amount of packages and also because it downloads the official
 Coreos IPA image automatically (~250 MB) you will need a decent internet 
 connection and about 30 minutes to get everything deployed. Be patient.

 * [BOSH](https://bosh.io) Registry support via Nginx Lua (using the inventory
 variables *Ironic_bosh_registry* and *Ironic_bosh_registry_password* for
 the *nginx* role and `files/bosh_webdav_lua_registry` Lua files). It offers a BOSH 
 Registry API to store the BOSH Agent settings using the WebDAV *metadata* 
 location. More details in the section below and in 
 https://github.com/jriguera/bosh-ironic-cpi-release. This implementation 
 relies on Nginx compiled with Lua, so in case of Debian distributions, 
 `nginx-extras` from the official repositories will be installed, for 
 Centos/RedHat the `nginx` role will define the [OpenResty](https://openresty.org/en/)
 repository and it will install the package. OpenResty is compatible with Nginx, 
 but the location of the binaries and configuration files is different in 
 Centos/RH. If you do not use BOSH you do not need to run this playbook. 
 Those packages will be installed only if the parameter `nginx_lua` is True 
 (defined on the `nginx` role).


## Running on Vagrant

There is a Vagrantfile to demo the entire sofware using VM's in your computer.
First of all, be patient. Then, due to the fact that this software was created
to manage physical servers, it is a bit difficult to simulate the behaviour with
VM's -have a look at the Vagrantfile-. The automatic enrollment of nodes does 
not work properly on VirtualBox because the client VM (*baremetal*) has no IPMI
settings and no real memory (*dmidecode* fails on the IPA image) and without 
those parameters Ironic Inspector refuses to apply the enrollment rules. 

If you want to test the traditional functionality: defining all the baremetal
parameters and deploy with configdrive, you can use `add-baremetal.yml` 
playbook with the id `vbox` (already defined in the inventory). Be aware it will 
create two VMs: one with 2GB (called *ironic*) and other with 2GB (called 
*baremetal*, the pxe client). Vagrant will define the internal network and will
try to launch locally the VboxService to allow Ironic controlling the baremetal 
client (in the same way as IPMI works). Also, because the baremetal VM is empty,
vagrant will fail saying that it was not able to ssh it.

Ready?


### `vagrant up`

Type `vagrant up` to run all the setup (playbook and roles: `site.yml`), 
after that just launch `vagrant ssh ironic` to have a look at the configuration.

Vagrant tries to update the VM and install some python dependencies for 
VirtualBox driver (*agent_vbox*), after that, it runs the roles and finally 
it configures Python Ironic client and Ansible inside the VM. Those tasks are 
not included in the `setup.yml` playbook because they are not needed in a 
real production server.

Vagrant will launch two VM's, first the Ironic server and then a PXE client
(called *baremetal*), when the last one boots it will ask you something about
a start-up disk on a CDROM drive, just click start and after that just power off
the VM (it is not needed at this time, it will be automatically launched by 
Ironic when needed).

When vagrant finish, you will have those enpoints available:

 * http://127.0.0.1:15672 - RabbitMQ (ironic:rabbitmq)
 * mysql://127.0.0.1:3306 - MySQL (ironic:mysql)
 * http://127.0.0.1:6385 - Ironic API
 * http://127.0.0.1:8080/www - Ironic WebClient
 * http://127.0.0.1:8080/images - Image HTTP repository (WebDAV)
 * http://127.0.0.1:8080/metadata - ConfigDrive HTTP repository (WebDAV)
 * http://127.0.0.1:2812 - Monit (admin:admin) 


Remember you also have to create the images (see below) and copy them to 
`ironic_pxe_images_path` (`/var/lib/ironic/http/images/` or just use
curl with PUT -it is a webdav repository!) on the server and reference them 
as `http://<server>/images/image.bin`. These references are managed in the 
`add-baremetal.yml`, and `del-baremetal.yml` playbooks together with the 
local references to the IPA images on the Ironic Conductor (they have to be 
referenced locally).

Also remember that the client needs these environment variables to get it
working:
```
export OS_AUTH_TOKEN="fake"
export IRONIC_URL=http://localhost:6385/
```
They are automatically defined by in the vagrant provisioning (but not on the
roles/playbooks!), so you can log in `vagrant ssh ironic` and then type 
`ironic driver-list` to check if it is working.


## Creating Images

If you want to easily create QCOW2 images with LVM and network bonding support,
have a look to: https://github.com/jriguera/packer-ironic-images. Once the 
images are created, just *PUT* them to the HTTP repository (pay attention to 
the change on the file extension for the md5 checksum, created with: 
`md5sum trusty.qcow2 > trusty.meta`):

 * `curl -T trusty.qcow2 http://localhost:8080/images/`
 * `curl -T trusty.meta http://localhost:8080/images/`


Otherwise, you can also build images using the OpenStack tools 
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

Once the images were created, copy them to the HTTP server, so in this example,
copy `trusty.*` (image, ramdisk and kernel) to `/var/lib/ironic/http/images/`
on the Ironic server, and the deploy ramdisk kernel and image to 
`/var/lib/ironic/http/deploy/`. Remember you can also just use curl to *PUT*
the files.


## Production set-up

Deploying this setup on a physical server was the main reason to create this
project. Get to a datacenter, take a server, install Ubuntu and run the playbook. 
Define the Ansible inventory file in `inventory` folder and run `setup.yml` 
using it. *inventory.ini* is a good example for inventory, just change the
the names and IP's. 

The setup was created to work with two network interfaces: one for public
API's (*Ironic_public_ip*) and the other one for PXE baremetal deployment 
(*Ironic_private_ip*), but you can manage everything with one network 
interface by using the same IP in both variables. You could also enable a third
interface to offer DHCP for IPMI, which, together with Ironic Inspector can 
make the job of add new physical servers in a datacenter really easy (well, 
there are some issues with Inspector to get/set the IPMI address: it does not 
work on all brands, but you can give a try ;-)

Ironic Inspector is a daemon to provide automatic server discovery, enrollment 
and hardware inspection. You can disable automatic discovery and enroll by 
switching the variable `ironic_inspector_enabled: false` (which only defines a 
default PXE entry). The variable `ironic_inspector_discovery_enroll: True` 
defines a set of Inspector rules to apply to new discovered servers (see 
`vars/inspector/discovery_rules*`). You can disable whenever you want 
Ironic Inspector by just changing to the variable `ironic_inspector_enabled` 
and re-run the playbook.

The settings for MySQL are good enough for a normal server nowadays, taking into
account the workload of the databases, but you can fine tune them. Moreover, if
you already have a external MySQL and/or RabbitMQ, you can remove each those
roles from the playbook and change the database and/or RabbitMQ variables to 
point to the proper server. In the same way, you can split the API vs Conductor
services in different servers to create a cluster of Conductors.

To sum up; update the file *inventory/inventory.ini* according to your needs 
(pay attention to the IP addresses and ranges and network interfaces), 
change the inventory hosts for all groups (*database*, *messaging*, *ironic-api* and
*ironic-conductor*) and run:

`ansible-playbook -i inventory/inventory.ini setup.yml`


## About BOSH

BOSH is an open source tool for release engineering, deployment, lifecycle 
management, and monitoring of distributed systems (taken from http://bosh.io/)
BOSH makes possible managing software in a completely abstract way from
the underlaying infrastructure. The same BOSH release is valid on OpenStack,
VMware, AWS, CloudStack, ... which is pretty awesome. The idea is having
a deterministic way to define and deploy distributed software in the new
cloud infrastructures.

The integration is done by implementing the BOSH Registry API in Lua with a
WebDAV backend on the `/metadata` location, where the ConfigDrive is saved.
Registry provides the persistent configuration needed by the BOSH Agent      
to setup/configure the server, in the same way that Cloud-Init does (it is a
similar idea, but BOSH Agent is limited, while Cloud-Init is a flexible 
general purpose tool). Also, the cloud config format for the BOSH Agent is not 
compatible with Cloud-Init, it is really simple, the most important field is 
the URL to the Registry. The registry is a JSON structure (`settings` file) 
specifying the networking, the disks, the NATS queue ... for example, every 
time BOSH creates a disk for a server it writes the configuration in the 
Registry (for the server) and tells the agent (via NATS) to read it.

A Cloud Provider Interface (CPI) is an API that BOSH uses to interact with
the underlaying infrastructue to manage the resources. The CPI
https://github.com/jriguera/bosh-ironic-cpi-release is a Python program
which translates BOSH requests in Ironic requests and uses Nginx as
WebDAV backend to store the Stemcells (QCOW2 Images with BOSH Agent
installed). To run it:

 1. Adjust the Registry password defined in the inventory variable
  `Ironic_bosh_registry_password` (and also enable `Ironic_bosh_registry`).

 2. Run `ansible-playbook -i inventory/<inventory.ini> setup.yml`

The implementation is in `files/bosh_webdav_lua_registry/webdav-registry.lua`
an it relies on Nginx with Lua support. For Debian/Ubuntu is already provided 
via `nginx-extras` package from the official repositories. Centos/RHEL does 
not provide Nignx with Lua support directly, so the Nginx role will define 
[OpenResty](https://openresty.org) (an Nginx compilation with Lua support) 
repositories and it will install it.

Note: Be carefull defining Auth Basic for */metadata* endpoint. It is used
by the Ironic IPA process while a server is being deployed to get the 
Config-Drive configuration. If Auth Basic is defined, you have to make aware the
IPA client of the authentication process. Also, in this situation you have
to define the following *allow* rules to permit the `webdav-registry.lua` reach 
the local metadata endpoint (because it does not support authentication):

```
            - name: "/metadata/"
              autoindex: "on"
              client_body_buffer_size: "16k" 
              client_max_body_size: "100M"
              create_full_put_path: "on"
              dav_access: "user:rw group:rw all:r"
              dav_methods: "PUT DELETE MKCOL COPY MOVE"
              default_type: "application/octet-stream"
              satisfy: "any"
              allow:
                - "127.0.0.0/24"
                - "{{ ansible_default_ipv4.address }}"
              auth:
                title: "Restricted Metadata"
                users:
                  metadatauser: "{PLAIN}password"
            - name: "/registry/"
              autoindex: "off"
              default_type: "application/json"
              client_max_body_size: "10M"
              content_by_lua_file: "webdav-registry.lua"
              auth:
                title: "BOSH Registry Auth"
                users:
                  registry: "{PLAIN}password"
```

More information about the CPI in https://github.com/jriguera/bosh-ironic-cpi-release


## About RedHat Enterprise Linux

Due to the fact EPEL repositories are needed in the installation, on RedHat is 
needed to enable the *optional* repository to use EPEL packages as they depend 
on packages in that repository. This can be done by enabling the RHEL 
optional subchannel for RHN-Classic. For certificate-based subscriptions see 
Red Hat Subscription Management Guide. For EPEL 7, in addition to the 
*optional* repository (`rhel-7-server-optional-rpms`), you also need to enable 
the *extras* repository (`rhel-7-server-extras-rpms`).

List all available repos for the system, including disabled repos.
```
$ subscription-manager repos --list

$ subscription-manager repos --enable rhel-7-server-optional-rpms
$ subscription-manager repos --enable rhel-7-server-extras-rpms
```


## Ironic Client Playbooks

To automatically define (and delete) baremetal host using the driver
`agent_ipmitool` (which allows deploy full disk images, for example with LVM),
There are two playbooks which are using the `configdrive` role to create
the initial Cloud-Init configuration with the correct network definition.
Have a look at the playbooks and at the `/vars` folder to see how to define the 
variables for new images and enrollment rules for your infrastructure.

The configdrive volume generated is provided to the IPA clients from the HTTP 
server running on the Ironic server.

To understand Ironic states: http://docs.openstack.org/developer/ironic/dev/states.html


### Example workflow

Here you can see the typical workflow with the client playbooks. The playbooks
do not need environment variables, but the Ironic client does:

```
export OS_AUTH_TOKEN="fake"
export IRONIC_URL=http://<server>:6385/
```

First, create a Trusty image as described previously and upload to 
*http://<server>/images*, then check the definition files in `images` and 
`servers` folders to match the correct settings of your infrastructure.


#### Deploying a baremetal server

Create the definition of the new server in `inventory/host_vars` folder (or via
the `servers` symlink) and add it to the Ansible inventory under the `[baremetal]`
section. Run the playbook:

```
# ansible-playbook -i inventory/production.ini add-baremetal.yml 
Server Name: test-server-01
Deploy the server (y) or just just define it (n)? [y]:

PLAY [Define and deploy physical servers using Ironic] *************************

TASK [setup] *******************************************************************
ok: [ironic]

...

TASK [Active and deploy the server] ********************************************
changed: [ironic -> localhost]

PLAY RECAP *********************************************************************
ironic                     : ok=42   changed=19   unreachable=0    failed=0   
```

After a while it will be installed and rebooting running Ubuntu. If you do not type
*y* (or enter) the server will not be deployed, it will remain as *available*,
ready to deploy. Be aware that from this situation is not enough telling Ironic
to deploy the server, you have to provide the link to the Config-drive volume
on the HTTP repository (to do it quickly, just run again the playbook ;-)

```
# ironic node-list
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name              | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| 9d97a5e8-bb1c-48a1-afae-8f1d249ee37a | pe-test-server-01 | None          | power on    | active             | False       |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
```

If you want to redeploy the node to get a fresh install, just do it!:

```
# ironic node-set-provision-state pe-test-server-01 rebuild
# ironic node-list
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name              | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| 9d97a5e8-bb1c-48a1-afae-8f1d249ee37a | pe-test-server-01 | None          | power on    | deploying          | False       |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
# ironic node-list
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name              | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| 9d97a5e8-bb1c-48a1-afae-8f1d249ee37a | pe-test-server-01 | None          | power on    | wait call-back     | False       |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+

[ after 10 minutes ... ]

# ironic node-list
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name              | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| 9d97a5e8-bb1c-48a1-afae-8f1d249ee37a | pe-test-server-01 | None          | power on    | wait call-back     | False       |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+

[ ... ]

# ironic node-list
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name              | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| 9d97a5e8-bb1c-48a1-afae-8f1d249ee37a | pe-test-server-01 | None          | power on    | deploying          | False       |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+

[ ... ]

# ironic node-list
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name              | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| 9d97a5e8-bb1c-48a1-afae-8f1d249ee37a | pe-test-server-01 | None          | power on    | active             | False       |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
```

While the server is being deployed you can request a SOL console to see the
output (this functionality depends on your the capabilities/properties of your
hardware):

```
# ironic node-set-console-mode pe-test-server-01 on
# ironic node-get-console pe-test-server-01
+-----------------+------------------------------------------------------------------+
| Property        | Value                                                            |
+-----------------+------------------------------------------------------------------+
| console_enabled | True                                                             |
| console_info    | {u'url': u'http://10.230.44.252:10204', u'type': u'shellinabox'} |
+-----------------+------------------------------------------------------------------+
```
Open the link in your browser and you should see the output of the console.


Now, you can move the status to *deleted*, to make the server *available* again
(which is different than removing the server from Ironic):

```
# ironic node-set-provision-state pe-test-server-01 deleted
# ironic node-list
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name              | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| 9d97a5e8-bb1c-48a1-afae-8f1d249ee37a | pe-test-server-01 | None          | power on    | deleting           | False       |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+

[ after a couple of minutes ... ]

# ironic node-list
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name              | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| 9d97a5e8-bb1c-48a1-afae-8f1d249ee37a | pe-test-server-01 | None          | power off   | cleaning           | False       |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
# ironic node-list
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name              | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| 9d97a5e8-bb1c-48a1-afae-8f1d249ee37a | pe-test-server-01 | None          | power off   | available          | False       |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
```

The server does a intermediate transition to the cleaning state (which is disabled
by default in this setup, because of the amount of time that some operations can
take, e.g wiping the disks).

From the *available* state you can move to *manageable* state in order to launch
a hardware inspection:

```
# ironic node-set-provision-state pe-test-server-01 manage
# ironic node-list
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name              | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| 9d97a5e8-bb1c-48a1-afae-8f1d249ee37a | pe-test-server-01 | None          | power off   | manageable         | False       |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
# ironic node-set-provision-state pe-test-server-01 inspect
# ironic node-list
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name              | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| 9d97a5e8-bb1c-48a1-afae-8f1d249ee37a | pe-test-server-01 | None          | power off   | inspecting         | False       |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+

[ after about 6 minutes, automatically switch back to the state ... ]

# ironic node-list
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name              | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
| 9d97a5e8-bb1c-48a1-afae-8f1d249ee37a | pe-test-server-01 | None          | power off   | manageable         | False       |
+--------------------------------------+-------------------+---------------+-------------+--------------------+-------------+
```

... and now the *properties* field has been populated. You could get more server
properties in the extra section (not showed here) depending on the introspection
rules defined on the Ironic Inspector service:

```
# ironic node-show pe-test-server-01
+------------------------+-------------------------------------------------------------------------+
| Property               | Value                                                                   |
+------------------------+-------------------------------------------------------------------------+
| chassis_uuid           |                                                                         |
| clean_step             | {}                                                                      |
| console_enabled        | True                                                                    |
| created_at             | 2016-05-02T11:22:46+00:00                                               |
| driver                 | agent_ipmitool                                                          |
| driver_info            | {u'ipmi_terminal_port': 10204, u'ipmi_username': u'ADMIN',              |
|                        | u'deploy_kernel':                                                       |
|                        | u'file:///var/lib/ironic/http/deploy/coreos_production_pxe.vmlinuz',    |
|                        | u'ipmi_address': u'10.230.40.204', u'deploy_ramdisk':                   |
|                        | u'file:///var/lib/ironic/http/deploy/coreos_production_pxe_image-       |
|                        | oem.cpio.gz', u'ipmi_password': u'******'}                              |
| driver_internal_info   | {u'agent_url': u'http://10.230.44.159:9999', u'is_whole_disk_image':    |
|                        | True, u'agent_last_heartbeat': 1462190484}                              |
| extra                  | {u'deploy_host': u'pe-prod-dogo-ironic-01', u'deploy_date':             |
|                        | u'2016-05-02T11:22:43Z', u'configdrive':                                |
|                        | u'http://10.230.44.252//metadata/9d97a5e8-bb1c-48a1-afae-8f1d249ee37a'} |
| inspection_finished_at | 2016-05-02T12:18:49+00:00                                               |
| inspection_started_at  | None                                                                    |
| instance_info          | {}                                                                      |
| instance_uuid          | None                                                                    |
| last_error             | None                                                                    |
| maintenance            | False                                                                   |
| maintenance_reason     | None                                                                    |
| name                   | pe-test-server-01                                                       |
| power_state            | power off                                                               |
| properties             | {u'memory_mb': u'73728', u'cpu_arch': u'x86_64', u'local_gb': u'277',   |
|                        | u'cpus': u'16'}                                                         |
| provision_state        | manageable                                                              |
| provision_updated_at   | 2016-05-02T12:18:49+00:00                                               |
| raid_config            |                                                                         |
| reservation            | None                                                                    |
| target_power_state     | None                                                                    |
| target_provision_state | None                                                                    |
| target_raid_config     |                                                                         |
| updated_at             | 2016-05-02T12:18:52+00:00                                               |
| uuid                   | 9d97a5e8-bb1c-48a1-afae-8f1d249ee37a                                    |
+------------------------+-------------------------------------------------------------------------+
```

#### Removing a baremetal server from Ironic

In the *available* and *enroll* states you can definitely remove the server
from Ironic by using the `del-baremetal.yml` playbook:

```
# ansible-playbook -i inventory/production.ini del-baremetal.yml
Server Name: test-server-01

PLAY [Poweroff and delete servers using Ironic] ********************************

TASK [setup] *******************************************************************
ok: [ironic]

...

PLAY RECAP *********************************************************************
ironic                     : ok=9    changed=3    unreachable=0    failed=0   

# ironic node-list
+------+------+---------------+-------------+--------------------+-------------+
| UUID | Name | Instance UUID | Power State | Provisioning State | Maintenance |
+------+------+---------------+-------------+--------------------+-------------+
+------+------+---------------+-------------+--------------------+-------------+
```

### Automatic enrollment with Ironic Inspector

That means that the DHCP server will reply to every request, if the MAC address
is already defined the node will be managed by Ironic in the same way as always,
otherwise it will boot in *discovered* mode. When the baremetal VM boots, it 
will load the Coreos IPA ramdisk with the instropection mode enabled. With this 
feature,the *enroll* modes checks all valid MAC's to check node existence, if 
it is not found, after a couple of minutes, the node will be automatically 
defined in Ironic:

```
# ironic node-list
+--------------------------------------+------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+------+---------------+-------------+--------------------+-------------+
| 16510bce-3ebd-4588-bc84-640f0da5f1b2 | None | None          | None        | enroll             | False       |
+--------------------------------------+------+---------------+-------------+--------------------+-------------+

```

The inspector role defines a set of rules automatically apply after the 
inspection. You can modify or add more by re-defining the variables defined 
in the files `vars/inspector/discovery_rules*.yml`. Be aware If you change
a rule but not its name, it wont be applied because the Ansible task only 
checks if it exists by name, not by the content. You can delete all the 
rules before running ansible with `curl -X DELETE http://<server>:5050/v1/rules`
or fill the UUID of the rules in the variable defined at the bottom of the 
file `discovery_rules.yml` (the intention behind that file -and their variables-
is offering a way define your custom rules). You can check the rules defined 
with `curl -X GET http://<server>:5050/v1/rules`


Let's how it works. Given our node in *manageable* status:

```
# ironic node-show test-server-01
+------------------------+-------------------------------------------------------------------------+
| Property               | Value                                                                   |
+------------------------+-------------------------------------------------------------------------+
| chassis_uuid           |                                                                         |
| clean_step             | {}                                                                      |
| console_enabled        | False                                                                   |
| created_at             | 2016-05-03T10:43:55+00:00                                               |
| driver                 | agent_ipmitool                                                          |
| driver_info            | {u'ipmi_terminal_port': 10204, u'ipmi_username': u'ADMIN',              |
|                        | u'deploy_kernel':                                                       |
|                        | u'file:///var/lib/ironic/http/deploy/coreos_production_pxe.vmlinuz',    |
|                        | u'ipmi_address': u'10.230.40.204', u'deploy_ramdisk':                   |
|                        | u'file:///var/lib/ironic/http/deploy/coreos_production_pxe_image-       |
|                        | oem.cpio.gz', u'ipmi_password': u'******'}                              |
| driver_internal_info   | {u'agent_url': u'http://10.230.44.150:9999', u'is_whole_disk_image':    |
|                        | True, u'agent_last_heartbeat': 1462272997}                              |
| extra                  | {u'deploy_host': u'pe-prod-dogo-ironic-01', u'deploy_date':             |
|                        | u'2016-05-03T10:43:53Z', u'configdrive':                                |
|                        | u'http://10.230.44.252//metadata/8f246784-d499-41c2-9a42-63b1f487fde9'} |
| inspection_finished_at | None                                                                    |
| inspection_started_at  | None                                                                    |
| instance_info          | {}                                                                      |
| instance_uuid          | None                                                                    |
| last_error             | None                                                                    |
| maintenance            | False                                                                   |
| maintenance_reason     | None                                                                    |
| name                   | test-server-01                                                          |
| power_state            | power off                                                               |
| properties             | {}                                                                      |
| provision_state        | manageable                                                              |
| provision_updated_at   | 2016-05-03T11:19:54+00:00                                               |
| raid_config            |                                                                         |
| reservation            | None                                                                    |
| target_power_state     | None                                                                    |
| target_provision_state | None                                                                    |
| target_raid_config     |                                                                         |
| updated_at             | 2016-05-03T11:19:57+00:00                                               |
| uuid                   | 8f246784-d499-41c2-9a42-63b1f487fde9                                    |
+------------------------+-------------------------------------------------------------------------+
```

We can tell ironic to do the inspection:

```
# ironic node-set-provision-state test-server-01 inspect
# ironic node-list
+--------------------------------------+----------------+---------------+-------------+--------------------+-------------+
| UUID                                 | Name           | Instance UUID | Power State | Provisioning State | Maintenance |
+--------------------------------------+----------------+---------------+-------------+--------------------+-------------+
| 8f246784-d499-41c2-9a42-63b1f487fde9 | test-server-01 | None          | power on    | inspecting         | False       |
+--------------------------------------+----------------+---------------+-------------+--------------------+-------------+
```


After a while, the node will be rebooted, it will run the introspection
task, the data will be collected and the rules will be applied, after
that the server will remain powered off. If you ask ironic to show the
node, you will see a lot of new stuff in the `extra` field and the basic
attributes in the `properties` field. Also, all the MAC addresses of
the server were assigned to each port.

```
# ironic node-show test-server-01
+------------------------+-------------------------------------------------------------------------+
| Property               | Value                                                                   |
+------------------------+-------------------------------------------------------------------------+
| chassis_uuid           |                                                                         |
| clean_step             | {}                                                                      |
| console_enabled        | False                                                                   |
| created_at             | 2016-05-03T10:43:55+00:00                                               |
| driver                 | agent_ipmitool                                                          |
| driver_info            | {u'ipmi_terminal_port': 10204, u'ipmi_username': u'ADMIN',              |
|                        | u'deploy_kernel':                                                       |
|                        | u'file:///var/lib/ironic/http/deploy/coreos_production_pxe.vmlinuz',    |
|                        | u'ipmi_address': u'10.230.40.204', u'deploy_ramdisk':                   |
|                        | u'file:///var/lib/ironic/http/deploy/coreos_production_pxe_image-       |
|                        | oem.cpio.gz', u'ipmi_password': u'******'}                              |
| driver_internal_info   | {u'agent_url': u'http://10.230.44.150:9999', u'is_whole_disk_image':    |
|                        | True, u'agent_last_heartbeat': 1462272997}                              |
| extra                  | {u'disks': u"[{u'rotational': True, u'vendor': u'IBM-ESXS', u'name':    |
|                        | u'/dev/sda', u'wwn_vendor_extension': None, u'wwn_with_extension':      |
|                        | u'0x5000c500680510cb', u'model': u'ST600MM0006', u'wwn':                |
|                        | u'0x5000c500680510cb', u'serial': u'5000c500680510cb', u'size':         |
|                        | 600127266816}, {u'rotational': True, u'vendor': u'IBM', u'name':        |
|                        | u'/dev/sdb', u'wwn_vendor_extension': u'0x1b9a4cce1d70c9c5',            |
|                        | u'wwn_with_extension': u'0x600605b0060547c01b9a4cce1d70c9c5', u'model': |
|                        | u'ServeRAID M1015', u'wwn': u'0x600605b0060547c0', u'serial':           |
|                        | u'600605b0060547c01b9a4cce1d70c9c5', u'size': 298999349248}]",          |
|                        | u'system_vendor': u"{u'serial_number': u'KQ280RG', u'product_name':     |
|                        | u'System x3650 M3 -[7945AC1]-', u'manufacturer': u'IBM'}", u'cpu':      |
|                        | u"{u'count': 16, u'frequency': u'2133.598', u'model_name': u'Intel(R)   |
|                        | Xeon(R) CPU           L5630  @ 2.13GHz', u'architecture': u'x86_64'}",  |
|                        | u'deploy_host': u'pe-prod-dogo-ironic-01', u'deploy_date':              |
|                        | u'2016-05-03T10:43:53Z', u'configdrive':                                |
|                        | u'http://10.230.44.252//metadata/8f246784-d499-41c2-9a42-63b1f487fde9'} |
| inspection_finished_at | 2016-05-03T11:29:29+00:00                                               |
| inspection_started_at  | None                                                                    |
| instance_info          | {}                                                                      |
| instance_uuid          | None                                                                    |
| last_error             | None                                                                    |
| maintenance            | False                                                                   |
| maintenance_reason     | None                                                                    |
| name                   | test-server-01                                                          |
| power_state            | power off                                                               |
| properties             | {u'memory_mb': u'73728', u'cpu_arch': u'x86_64', u'local_gb': u'277',   |
|                        | u'cpus': u'16'}                                                         |
| provision_state        | manageable                                                              |
| provision_updated_at   | 2016-05-03T11:29:29+00:00                                               |
| raid_config            |                                                                         |
| reservation            | None                                                                    |
| target_power_state     | None                                                                    |
| target_provision_state | None                                                                    |
| target_raid_config     |                                                                         |
| updated_at             | 2016-05-03T11:29:31+00:00                                               |
| uuid                   | 8f246784-d499-41c2-9a42-63b1f487fde9                                    |
+------------------------+-------------------------------------------------------------------------+
# ironic node-port-list test-server-01
+--------------------------------------+-------------------+
| UUID                                 | Address           |
+--------------------------------------+-------------------+
| 91849094-8a10-48b0-bd0c-d99963459999 | e4:1f:13:e6:d6:d4 |
| 17ba3d74-358d-4324-a18a-ea31a67e0681 | 00:0a:cd:26:f1:7a |
| 1c39125c-f97b-4281-9a1b-409efe116d46 | 00:0a:cd:26:f1:79 |
| 18519e74-7f59-4037-ba28-f85f07102e16 | e4:1f:13:e6:d6:d6 |
+--------------------------------------+-------------------+
```

If you do it on VirtualBox, because of the limitations of the virtual environment 
it will not work. The node does not has all the properties of a real server 
(IPMI) and the enroll process does not work properly. 



### Testing with Vagrant

The static variables are defined in `Vagrantfile` and `site.yml`, pay attention
to the local IP and MAC addresses.

Then, `vagrant ssh ironic` and become root `sudo -s` and go to `/vagrant` and
run `ansible-playbook -i inventory/inventory.ini -e id=vbox add-baremetal.yml`

Ironic will contact with `VBXWebSrv` and start the VM called *baremetal*. After
a while it will be installed and rebooting running Ubuntu. If you do not type
*y* (or enter) the server will not be deployed, it will remain as *available*,
ready to deploy. Be aware, from this situation is not enough telling Ironic
to deploy the server, you have to provide the link to the Config-drive volume
on the HTTP repository.


# License

Apache 2.0



# Author Information

José Riguera López <jose.riguera@springer.com>

