# -*- mode: ruby -*-
# vi: set ft=ruby :

# This is just to be able to run the ansible playbooks within the VM,
# just go to /vagrant and run the add-vbox.yml playbook
$script = <<"SCRIPT"
echo "export IRONIC_URL=http://localhost:6385/" > /etc/profile.d/ironic.sh
echo "export OS_AUTH_TOKEN='fake'" >> /etc/profile.d/ironic.sh
chmod +x /etc/profile.d/ironic.sh
pip install python-ironicclient 
pip install ansible 
SCRIPT


# Run local commands
module LocalCommand
    class Config < Vagrant.plugin("2", :config)
        attr_accessor :command
    end
    class Plugin < Vagrant.plugin("2")
        name "local_shell"

        config(:local_shell, :provisioner) do
            Config
        end
        provisioner(:local_shell) do
            Provisioner
        end
    end
    class Provisioner < Vagrant.plugin("2", :provisioner)
        def provision
            result = system "#{config.command}"
        end
    end
end


Vagrant.configure(2) do |config|

  config.vm.define "ironic" do |master|
    # Every Vagrant development environment requires a box. You can search for
    # boxes at https://atlas.hashicorp.com/search.
    master.vm.box = "bento/ubuntu-16.04"
    # On Centos the interfaces are not eth0 ... change the playbooks!
    #master.vm.box = "bento/centos-7.2"

    # Disable automatic box update checking. If you disable this, then
    # boxes will only be checked for updates when the user runs
    # `vagrant box outdated`. This is not recommended.
    # master.vm.box_check_update = false

    # Create a forwarded port mapping which allows access to a specific port
    # within the machine from a port on the host machine. In the example below,
    # accessing "localhost:8080" will access port 80 on the guest machine.
    master.vm.network "forwarded_port", guest: 80, host: 8080
    master.vm.network "forwarded_port", guest: 2812, host: 2812
    master.vm.network "forwarded_port", guest: 15672, host: 15672
    master.vm.network "forwarded_port", guest: 3306, host: 3306
    master.vm.network "forwarded_port", guest: 6385, host: 6385
    master.vm.network "forwarded_port", guest: 5050, host: 5050

    # Create a private network, which allows host-only access to the machine
    # using a specific IP.
    master.vm.network "private_network", ip: "10.0.0.10", virtualbox__intnet: "intnet"
    # With Xenial the previous setting does not work, so, when vagrant up fails ... comment it out
    # and try this is the workaround:
    #master.vm.network "private_network", ip: "10.0.0.10", virtualbox__intnet: "intnet", auto_config: false

    # Create a public network, which generally matched to bridged network.
    # Bridged networks make the machine appear as another physical device on
    # your network.
    # master.vm.network "public_network"

    # Share an additional folder to the guest VM. The first argument is
    # the path on the host to the actual folder. The second argument is
    # the path on the guest to mount the folder. And the optional third
    # argument is a set of non-required options.
    #master.vm.synced_folder ".", "/vagrant", type: "rsync", rsync__exclude: ".vagrant/"

    # Provider-specific configuration so you can fine-tune various
    # backing providers for Vagrant. These expose provider-specific options.
    #
    master.vm.provider "virtualbox" do |vb|
      # Customize the amount of memory on the VM:
      #vb.gui = true
      vb.memory = "2048"
    end

    # This script just install the python package for the agent_vbox driver
    # which is only required for testing purposes with VirtualBox. In a production
    # server such driver is not needed neither these pre-install tasks
    master.vm.provision "shell", inline: <<-SHELL
	if [ -f /etc/debian_version ]; then
                export DEBIAN_FRONTEND=noninteractive
                apt-get update
                sudo apt-get upgrade -y
                apt-get install -y python python-pip
	elif [ -f /etc/redhat-release ]; then
                yum -y install epel-release
                yum -y update
                yum -y install python-pip
	fi
        # Otherwise ironic-conductor fails to start
        pip install --upgrade pyremotevbox
    SHELL

    # Start the VirtualBox web service with null authentication for the agent_vbox driver
    # call with: vagrant provision --provision-with vbox
    config.vm.provision "vbox", type: "local_shell", command: "VBoxManage setproperty websrvauthlibrary null && pgrep vboxwebsrv || vboxwebsrv &> /dev/null"

    master.vm.provision "ansible" do |ansible|
        ansible.playbook = "site.yml"
        #ansible.verbose = "vvvv"
        #ansible.raw_arguments = "--list-task"
    end

    # Enable provisioning with a shell script. Additional provisioners such as
    # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
    # documentation for more information about their specific syntax and use.
    master.vm.provision "shell" do |s|
        s.inline = $script
    end
  end

  config.vm.define "baremetal" do |slave|
    # If you change this, change also the servers/vbox.yml settings!
    mac = "08002726008E"
    name = "baremetal"

    # Use a image designed for pxe boot.
    slave.vm.box = "c33s/empty"

    # Give the host a bogus IP, otherwise vagrant will bail out.
    # Static mac address match up with dnsmasq dhcp config
    # The auto_config: false tells vagrant not to change the hosts ip to the bogus one.
    slave.vm.network "private_network", :adapter=>1, :mac => mac, auto_config: false, virtualbox__intnet: "intnet"

    # We dont need no stinking synced folder.
    slave.vm.synced_folder '.', '/vagrant', disabled: true
    slave.ssh.insert_key = false
    slave.ssh.proxy_command = "true"
    slave.vm.boot_timeout = 2 
    slave.vm.provider "virtualbox" do |vb, override|
       vb.gui = true
       vb.name = name
       vb.memory = "2000"
       # piix3 chipset
       #vb.customize ["modifyvm", :id, "--chipset", "piix3"]
       # Disable USB
       vb.customize ["modifyvm", :id, "--usb", "on"]
       vb.customize ["modifyvm", :id, "--usbehci", "off"]
       #vb.customize ["modifyvm", :id, "--boot1", "net", "--boot2", "disk"]
    end
    slave.vm.post_up_message = "Hola mundo"
  end
end
