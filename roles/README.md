About these roles
=================

A set of roles to setup an OpenStack Ironic node in standalone mode, 
just to be able to deploy servers like cobbler but based on images ...

Structure and Ansible Conventions
---------------------------------

**To sum up: make everything reusable and interchangeable.**


Because of the fact there is not ansible conventions, it is really difficult
to reuse the code, I have followed those conventions:

 * Each role should be independent and reusable -without dependencies- 
   except ofc, if you need something like java to run a service, in that
   case it should be a dependency, but not a DB, because it can be 
   running on a different server, or you could use SQLite. The dependencies 
   should be at playbook level, because Ansible is stateless, so it is 
   difficult to control when a role was called from others with different
   parameters. To sum up, keep the dependencies at the top level.

 * A role/playbook should be idempotent, that means, for example, if you 
   re-provision a server and there were no changes, it has no to restart 
   the service.

 * Divide the tasks in groups and use tags with the same name as the
   tasks file:
   * Install: in charge of installing the distro packages and after
   that the service should be stopped (unless if no configuration is 
   needed).
   * Configure: in charge of creating the configuration settings and
   make sure that the service is enabled.
   * Plugins, Cluster ... : in charge of additional setups.

 * Use `vars` for specific distribution parameters of your service, 
   think about something like a constants. Usually those parameters they 
   do not affect the functionality of the service you try to install,
   it is just about package names, location folders, ... nothing to do 
   with the real settings in the configuration files of the service. 
   There usually are Debian and RedHat files with specific parameters which
   they are going to be loaded in those cases. Do not go against 
   distribution philosophy
  
 * Use `defaults` as service parameters to get parameterized roles. 
   There you should define your service defaults settings (to use them in 
   the template), and the recommended defaults (from the owner/programmer) 
   should be defined in the template with `parameter | default()`. By 
   doing this, we could reuse those templates in other provisioning tools 
   different than Ansible.

 * Each task needs a name and it should be a block of code, do not put
   lines from diferent tasks together please.

 * Make it available for Centos and Debian distros.


License
-------

GPLv3

Author Information
------------------

José Riguera López <jose.riguera@springer.com>
