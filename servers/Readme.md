Servers
=======

Definitions of the baremetal hosts managed by Ironic, to
be used by the `add-baremetal.yml` and `del-baremetal` playbooks.

Each defintion can have an optional cloudconfig file for cloud-init 
which is going to be automatically included in the configdrive (as user_data) 
and executed once at boot time.

After define a host here, something like `NAME.yml` (and optionaly another 
file `NAME.cloudconfig`), run:

```
ansible-playbook -i hosts/ironic -e id=NAME add-baremetal.yml
```

To remove the server from Ironic:

```
ansible-playbook -i hosts/ironic -e id=NAME del-baremetal.yml
```
