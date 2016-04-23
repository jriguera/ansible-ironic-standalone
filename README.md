# Ansible-Ironic-Standalone

A set of roles to set-up an OpenStack Ironic node in standalone mode, 
just ready to deploy servers like cobbler but more powerful!

Have a look at the wiki to know more about this setup: 
https://github.com/jriguera/ansible-ironic-standalone/wiki

This repository uses tags!

| Tag  | Openstack Release | Ironic version |   Upgrade    |
|------|-------------------|----------------|--------------|
| v1.x | Kilo (2015.4)     | 2015.1.n       | -            |
| v2.x | Liberty (2015.10) | 4.2.n          | v1.x -> v2.x |



# Requirements

Ansible 2.0. There is no backwards compatibility with previous ansible versions,
but it is safe running the roles against a previous installation deploy with 
Ansible 1.9

The rest requirements are managed by the roles, they were tested on Ubuntu 
Trusty (14.04) and Centos 7.2. They use the official repos, so no development 
packages are installed, just official packages!

Roles used:

 * `roles/mysql` to setup a MySQL server (version 5.6) and databases.
 * `roles/rabbitmq` to setup a message queue using RabbitMQ.
 * `roles/monit` (optional) for basic monitoring of the system and controll 
    the processes with Monit.
 * `roles/ironic` to setup the OpenStack Ironic daemons.
 * `roles/dnsmasq` to setup a PXE server to use with Ironic.
 * `roles/nginx` (optional) to setup HTTP image repo server (for IPA).
 * `roles/webclient` (optional) to setup ironic_webclient application
 
Notice that those roles have no dependecies between each other, so you 
can reuse them in other projects, they have more functionalities than 
the required for this setup. Also, they were created/adapted following 
devops practices.



# Running it

There are 4 main playbooks defined in the repo

 * `setup-ironic` to deploy a real server to configure all the software. 
 Probably you will have to adapt some parameters there like dnsmasq 
 interfaces (e.g. *eth0* vs *em1*). The rest of the parameters 
 (IPs, DNS, ...) are defined in the ansible inventory (*hosts/ironic*) and/or 
 in *group_vars* files.
 * `add-baremetal` to manually define and deploy a server with Ironic. 
 When it runs, it will ask you for an id (name) which has to match to a file 
 with the server parameters (IPMI, networks, bonding ...) in *servers* folder 
 (optionally you can also define a *.cloudconfig* configuration in the same 
 way).
 * `del-baremetal` to delete a server defined in Ironic. When it runs, it will 
 halt the server and remove it from Ironic. It does not trigger additional 
 cleaning steps like wipe the disks.
 * `site.yml` and `add-vbox.yml` just for a demo with Vagrant, see `Vagrantfile`


Notices:

 * This set-up is installing all the requirements for `pxe_ipmitool` driver, 
 but now it is only focused on the `agent_ipmitool` driver, it requires a 
 HTTP server (*nginx* role) and a speciall image called Ironic Python Agent 
 (IPA), which is downloaded automatically.
 
 * This version switched to MySQL 5.6 instead of MySQL 5.5. The migration is
 safe, because the *mysql* role stops the previous version, deletes 
 *ib_logfiles* and it starts MySQL again. Next version will use MySQL 5.7 as 
 it becomes the default version in most of the recent distributions.
 
 * There is a new web interface installed with the role `webclient`. It 
 is https://github.com/openstack/ironic-webclient , is not completely functional
 but it helps showing the nodes currently defined in Ironic and it does not
 waste resources (it is javascript running on your browser).

 * `setup-ironic` configures the `nginx` role to support webdav on the HTTP
 repos for images and metadata, so you can `PUT` the files with curl,
 without connecting the server. The approach is just to have a kind of
 repository compatible with HTTP API calls.

 * The next version (3.x from Mitaka) supports the Ironic Inspector package 
 (deployed with a new role) which provides automatic discovery for new baremetal
 servers, of course, you can stil use the `add-baremetal` or `del-baremetal` 
 with your servers.

 * The two playbooks to define and delete servers in Ironic are completely 
 functional but, the main purpose of them is to make easy and show the entire 
 process. You can use them in production, but they are not *elegant*, they 
 depend on the Ironic client locally installed to do all the actions but you 
 could use the ansible modules for that!).


Remember that all the services installed by `setup-ironic` are managed with 
Monit (yes even on the systemd systems!). So if you stop a process, 
Monit will start it again!. Monit has a web interface ... just use it!


There is a Vagrantfile to demo the entire sofware using VMs in your computer. 
In this case, instead of using the `add-baremetal` playbook you have to use 
`add-vbox` (only because of the conductor driver type: IPMI for real servers vs 
VBoxService for Virtualbox). Be aware it will create two VMs: one with 2GB 
(called *ironic*) and other with 6GB (called *baremetal*, the pxe client), yes! 
6GB for the client, due to the fact IPA stores the image in tmpfs in memory ...).
Do not worry, the second server wont get the 6GB inmediatelly, so you can stop 
it if you do not want to entirely run the demo (only the Ironic server). Vagrant 
will define the internal network and will try to launch locally the VboxService
to allow Ironic to controll the client baremetal (in the same way as IPMI works).
Aslo, because the baremetal VM client is empty, vagrant will fail saying that
it was not able to ssh it.



## Vagrant

Just type: `vagrant up` to run all the setup (playbook and roles: `site.yml`), 
after that just launch `vagrant ssh ironic` to have a look at the configuration.

Vagrant tries to update the VM and install some python dependencies for vbox 
driver, after that, it runs the roles and finally it configures ironic client
and ansible inside the vm. Those tasks are not included in the `setup-ironic` 
playbook because they are not needed in a real production server.

Vagrant will launch 2 VMs, first the Ironic server and then a PXE client
(called `baremetal`), when the last one boots it will ask you something about
a start-up disk on a CDROM drive, just click start and after that just power off
 the VM (it is not needed at this time, it will be automatically launched by 
Ironic when needed).


When vagrant will be finished, you will have those ports available:

 * http://127.0.0.1:15672 - RabbitMQ (ironic:rabbitmq)
 * mysql://127.0.0.1:3306 - MySQL (ironic:mysql)
 * http://127.0.0.1:6385 - Ironic API
 * http://127.0.0.1:8080 - Nginx http image repository
 * http://127.0.0.1:2812 - Monit (admin:admin) 


Remember you also have to create the images (see below) and copy them to 
`{{ ironic_pxe_images_path }}` (`/var/lib/ironic/http/images/` or just use
curl with PUT -it is a webdav repository!) on the server and reference them 
as `http://server/images/image.bin`. These references are managed in the 
`add-baremetal`, `add-vbox` and `del-baremetal` playbooks together with the 
local references to the IPA images on the Ironic Conductor (they have to be 
referenced locally).

Also remember that the client needs these environment variables to get it
working:
```
export OS_AUTH_TOKEN=" "
export IRONIC_URL=http://localhost:6385/
```
They are automatically defined by in the vagrant provisioning (but not on the
roles/playbooks!), so you can log in `vagrant ssh ironic` and then type 
`ironic driver-list` to check if it is working.



## Creating Images

If you want to create images easily with LVM and bonding support, have a look 
to: https://github.com/jriguera/packer-ironic-images. Create the images and
`PUT` to the HTTP repository:

 * `curl -T trusty.qcow2 http://localhost:8080/images/`
 * `curl -T trusty.md5 http://localhost:8080/images/`


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

Once the images were created, copy them to the HTTP server, so in this example,
copy `trusty.*` (image, ramdisk and kernel) to `/var/lib/ironic/http/images/`
on the Ironic server, and the deploy ramdisk kernel and image to 
`/var/lib/ironic/http/deploy/`. Remember you can also just use curl to *PUT*
the files.



## Ironic Client Playbooks

To automatically define (and delete) baremetal servers using the driver
`agent_ipmitool` (which allows deploy full disk images -with lvm, for example),
I have created two playbooks which are using the `configdrive` role to create
the initial cloud-init configuration with the proper network definition. Have a
look at the playbooks and at the `/vars` folder to see how to define the 
variables for your infrastructure.

Together with the qcow2 disk images, the configdrive definition is provided to
the clients via URL, by using the HTTP server running on the Ironic server.



### With Vagrant

The static variables are defined in `Vagrantfile` and `site.yml`, pay attention
to the local IPs and MAC addresses.

First, create a Trusty image as described previously and upload to 
`http://localhost:8080/images`, then check if the variables defined in 
`vars/vbox.yml` match the internal IPs of Ironic server. 

Then, `vagrant ssh ironic` and become root `sudo -s` and go to `/vagrant` and
run `ansible-playbook -i hosts/vbox add-vbox.yml`:

```
root@vagrant-ubuntu-trusty-64:/vagrant# ansible-playbook -i hosts/vbox add-vbox.yml 
Server Name: vbox

PLAY [Define and deploy physical servers using Ironic] *************************

TASK [setup] *******************************************************************
ok: [localhost]

TASK [Include network definitions] *********************************************
ok: [localhost]

TASK [Include image definitions] ***********************************************
ok: [localhost]

TASK [include] *****************************************************************
included: /vagrant/tasks/baremetal_md5.yml for localhost

TASK [Define the MD5 checksum URI if needed] ***********************************
ok: [localhost]

TASK [Get the url image MD5 checksum if needed] ********************************
changed: [localhost]
 [WARNING]: Consider using get_url module rather than running curl


TASK [Load the previous MD5 checksum] ******************************************
ok: [localhost]

TASK [Workout the checksum with the image url if needed] ***********************
skipping: [localhost]

TASK [Load the previous MD5 checksum] ******************************************
skipping: [localhost]

TASK [Check if servername configdrive exists] **********************************
ok: [localhost -> localhost]

TASK [Load servername configdrive] *********************************************
skipping: [localhost]

TASK [include] *****************************************************************
included: /vagrant/tasks/baremetal_prepare.yml for localhost

TASK [Define the server domain] ************************************************
skipping: [localhost]

TASK [Define the server name] **************************************************
ok: [localhost]

TASK [Define the server name as MAC] *******************************************
skipping: [localhost]

TASK [Get the current date] ****************************************************
changed: [localhost]

TASK [Define the date] *********************************************************
ok: [localhost]

TASK [Assign network parameters] ***********************************************
ok: [localhost]

TASK [Assign network parameters with DHCP] *************************************
skipping: [localhost]

TASK [Check if the network needs an IP address for the server] *****************
skipping: [localhost]

TASK [Checking if MAC address is correct] **************************************
skipping: [localhost]

TASK [Define the IPMI console port] ********************************************
ok: [localhost]

TASK [Check MD5 image checksum defined] ****************************************
skipping: [localhost]

TASK [Check if the new node was defined] ***************************************
changed: [localhost -> localhost]

TASK [Checking if server name is already used] *********************************
skipping: [localhost]

TASK [Define the new baremetal node] *******************************************
changed: [localhost -> localhost]

TASK [Get the server UUID] *****************************************************
ok: [localhost]

TASK [configdrive : Install required packages to create the images] ************
ok: [localhost] => (item={'value': {u'state': u'latest'}, 'key': u'gzip'})
ok: [localhost] => (item={'value': {u'state': u'latest'}, 'key': u'coreutils'})
ok: [localhost] => (item={'value': {u'state': u'latest'}, 'key': u'genisoimage'})

TASK [configdrive : Include OS specific variables] *****************************
ok: [localhost]

TASK [configdrive : Setup configdrive instance folder] *************************
ok: [localhost]

TASK [configdrive : Create configdrive metadata folders] ***********************
changed: [localhost] => (item=openstack/2012-08-10)
changed: [localhost] => (item=openstack/latest)
changed: [localhost] => (item=openstack/content)

TASK [configdrive : include] ***************************************************
included: /vagrant/roles/configdrive/tasks/configdrive.yml for localhost

TASK [configdrive : Create configdrive temporary metadata folder] **************
changed: [localhost] => (item=openstack/_)

TASK [configdrive : Setup temporary folder for include files] ******************
ok: [localhost]

TASK [configdrive : include] ***************************************************
skipping: [localhost]

TASK [configdrive : include] ***************************************************
included: /vagrant/roles/configdrive/tasks/network.yml for localhost

TASK [configdrive : Get a list the backend devices] ****************************
ok: [localhost] => (item=eth0)

TASK [configdrive : Create network_info.json] **********************************
changed: [localhost] => (item=openstack/2012-08-10)
changed: [localhost] => (item=openstack/latest)

TASK [configdrive : Create the network configuration folders] ******************
changed: [localhost] => (item=/etc/network/interfaces.d/)

TASK [configdrive : Setup resolver file resolv.conf] ***************************
skipping: [localhost]

TASK [configdrive : Setup static hosts file] ***********************************
skipping: [localhost]

TASK [configdrive : Setup network/interfaces for Debian] ***********************
changed: [localhost]

TASK [configdrive : Setup undefined backend devices] ***************************
changed: [localhost] => (item=eth0)

TASK [configdrive : Setup all defined devices] *********************************
changed: [localhost] => (item={u'domain': u'vbox.local', u'nameservers': [u'8.8.8.8'], u'bond_mode': u'1', u'netmask': u'255.255.255.0', u'address': u'10.100.100.10', u'device': u'bond0', u'type': u'bond', u'gateway': u'10.100.100.1', u'backend': [u'eth0']})

TASK [configdrive : Setup route configuration for RedHat] **********************
skipping: [localhost] => (item={u'domain': u'vbox.local', u'nameservers': [u'8.8.8.8'], u'bond_mode': u'1', u'netmask': u'255.255.255.0', u'address': u'10.100.100.10', u'device': u'bond0', u'type': u'bond', u'gateway': u'10.100.100.1', u'backend': [u'eth0']}) 

TASK [configdrive : List the include files on temporary folder] ****************
changed: [localhost]

TASK [configdrive : Get the list of include files on temporary folder] *********
ok: [localhost]

TASK [configdrive : Move files to destination from temporary folder] ***********
changed: [localhost] => (item=(0, u'/etc/network/interfaces.d/ifcfg-bond0'))
changed: [localhost] => (item=(1, u'/etc/network/interfaces.d/ifcfg-eth0'))
changed: [localhost] => (item=(2, u'/etc/network/interfaces'))

TASK [configdrive : Delete temporary folder] ***********************************
changed: [localhost]

TASK [configdrive : Create meta_data.json] *************************************
changed: [localhost] => (item=openstack/2012-08-10)
changed: [localhost] => (item=openstack/latest)

TASK [configdrive : Copy metadata file user_data] ******************************
skipping: [localhost] => (item=openstack/2012-08-10) 
skipping: [localhost] => (item=openstack/latest) 

TASK [configdrive : Create configdrive volume file] ****************************
changed: [localhost]

TASK [configdrive : Cleanup instance configdrive folder] ***********************
skipping: [localhost]

TASK [Define the install image for the node] ***********************************
changed: [localhost -> localhost]

TASK [Define the kernel and ramdisk for the image] *****************************
skipping: [localhost]

TASK [Create the MAC address ports for the new node] ***************************
changed: [localhost -> localhost]

TASK [Add reference to config-drive in metadata info] **************************
changed: [localhost -> localhost]

TASK [Define the configdrive parameter] ****************************************
ok: [localhost -> localhost]

TASK [Define the configdrive parameter when enabled configdrive] ***************
ok: [localhost -> localhost]

TASK [Active and deploy the server] ********************************************
changed: [localhost -> localhost]

PLAY RECAP *********************************************************************
localhost                  : ok=43   changed=20   unreachable=0    failed=0   
```

Ironic will contact with VBXWebSrv and start theVM called baremetal. After a
while it will be installed and rebooting running Ubuntu.


### Physical servers

Just run those playbooks:

 * `add-baremetal.yml`: To add a new baremetal server. It will ask for the 
 required parameters.
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


## Variables

Have a look at `site.yml` for vagrant setup and `setup-ironic.yml` with the 
inventory defined in `hosts` and `group_vars` folders for a real setup.
Monit is optional, if you do not need it, just remove the role.



# Bugs

On Centos 7.2, depeding on the repositories you are using, Ironic daemons can
fail to start, showing:

```
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: Traceback (most recent call last):
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: File "/usr/bin/ironic-api", line 6, in <module>
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: from ironic.cmd.api import main
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: File "/usr/lib/python2.7/site-packages/ironic/cmd/api.py", line 28, in <module>
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: from ironic.api import app
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: File "/usr/lib/python2.7/site-packages/ironic/api/app.py", line 22, in <module>
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: from ironic.api import acl
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: File "/usr/lib/python2.7/site-packages/ironic/api/acl.py", line 19, in <module>
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: from ironic.api.middleware import auth_token
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: File "/usr/lib/python2.7/site-packages/ironic/api/middleware/__init__.py", line 15, in <module>
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: from ironic.api.middleware import auth_token
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: File "/usr/lib/python2.7/site-packages/ironic/api/middleware/auth_token.py", line 17, in <module>
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: from keystonemiddleware import auth_token
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: File "/usr/lib/python2.7/site-packages/keystonemiddleware/auth_token/__init__.py", line 217, in <modul
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: from keystoneclient import discover
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: File "/usr/lib/python2.7/site-packages/keystoneclient/discover.py", line 22, in <module>
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: from keystoneclient import session as client_session
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: File "/usr/lib/python2.7/site-packages/keystoneclient/session.py", line 27, in <module>
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: import requests
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: File "/usr/lib/python2.7/site-packages/requests/__init__.py", line 58, in <module>
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: from . import utils
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: File "/usr/lib/python2.7/site-packages/requests/utils.py", line 26, in <module>
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: from .compat import parse_http_list as _parse_list_header
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: File "/usr/lib/python2.7/site-packages/requests/compat.py", line 7, in <module>
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: from .packages import chardet
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: File "/usr/lib/python2.7/site-packages/requests/packages/__init__.py", line 29, in <module>
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: import urllib3
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: File "/usr/lib/python2.7/site-packages/urllib3/__init__.py", line 8, in <module>
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: from .connectionpool import (
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: File "/usr/lib/python2.7/site-packages/urllib3/connectionpool.py", line 33, in <module>
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: from .packages.ssl_match_hostname import CertificateError
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: File "/usr/lib/python2.7/site-packages/urllib3/packages/__init__.py", line 3, in <module>
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: from . import ssl_match_hostname
abr 17 14:04:00 localhost.localdomain ironic-api[19549]: ImportError: cannot import name ssl_match_hostname
```

This is because the proper version of urllib3 was not installed, to fix it,
upgrade the library using pip and restart the daemons with Monit.

```
# pip install --upgrade urllib3
Collecting urllib3
  Downloading urllib3-1.15.1-py2.py3-none-any.whl (92kB)
    100% |████████████████████████████████| 102kB 3.1MB/s 
Installing collected packages: urllib3
  Found existing installation: urllib3 1.13.1
    Uninstalling urllib3-1.13.1:
      Successfully uninstalled urllib3-1.13.1
Successfully installed urllib3-1.15.1
```


# License

Apache 2.0



# Author Information

José Riguera López <jose.riguera@springer.com>

