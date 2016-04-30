Servers
=======

Definition files for the baremetal servers managed by Ironic and used with the
 `add-baremetal.yml`, `add-vbox.yml` and `del-baremetal` playbooks.

These parameters are used in the previous roles, and the following ones are
mandatory (see `tasks/baremetal_prepare`):

* `baremetal_ipmi_ip` to be able to manage the power status of the server
* `baremetal_fqdn` to define the name of the server in Ironic (but without the domain)
* `baremetal_mac` to define the PXE port in Ironic (for PXE booting).
* `baremetal_ip`, `baremetal_netmask`, `baremetal_gw`. main network parameters.
* `baremetal_os` image name, defined in *images/<name>.yml*
* `baremetal_network_list`: network definition

Each file can have an optional cloudconfig file -with the same name but
*cloudconfig* extension- for cloud-init which is going to be automatically 
included in the configdrive (as *user_data* metadata) and executed once at 
boot time.

After define a host here, something like `NAME.yml` (and optionaly another 
file `NAME.cloudconfig`), run:

```
ansible-playbook -i hosts/ironic -e id=NAME add-baremetal.yml
```

To remove the server from Ironic:

```
ansible-playbook -i hosts/ironic -e id=NAME del-baremetal.yml
```
