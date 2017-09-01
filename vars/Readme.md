Vars
====

Definition of variables for the playbooks. These files define the default variables
values in order to be loaded from the playbooks. Customizations can be done 
within the inventory for each host.

These files can be encrypted with ansible-vault.

Each folder defines a `deployment` so you could use this repo to maintain
different Ironics with different settings. Default deployment is defined in the
inventory file, and it is named "vbox" (just for testing with VirtualBox).

The folder `images` defines global images available for all environments,
but each environment can define its own images within its own folder. The
same applies for the inspector rules (see vbox folder).

