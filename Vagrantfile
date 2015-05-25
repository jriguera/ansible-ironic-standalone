# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  config.vm.define "ironic" do |master|
    # Every Vagrant development environment requires a box. You can search for
    # boxes at https://atlas.hashicorp.com/search.
    master.vm.box = "ubuntu/trusty64"

    # Disable automatic box update checking. If you disable this, then
    # boxes will only be checked for updates when the user runs
    # `vagrant box outdated`. This is not recommended.
    # master.vm.box_check_update = false

    # Create a forwarded port mapping which allows access to a specific port
    # within the machine from a port on the host machine. In the example below,
    # accessing "localhost:8080" will access port 80 on the guest machine.
    master.vm.network "forwarded_port", guest: 2812, host: 2812
    master.vm.network "forwarded_port", guest: 15672, host: 15672
    master.vm.network "forwarded_port", guest: 3306, host: 3306
    master.vm.network "forwarded_port", guest: 6385, host: 6385

    # Create a private network, which allows host-only access to the machine
    # using a specific IP.
    master.vm.network "private_network", ip: "10.0.0.10"

    # Create a public network, which generally matched to bridged network.
    # Bridged networks make the machine appear as another physical device on
    # your network.
    # master.vm.network "public_network"

    # Share an additional folder to the guest VM. The first argument is
    # the path on the host to the actual folder. The second argument is
    # the path on the guest to mount the folder. And the optional third
    # argument is a set of non-required options.
    # master.vm.synced_folder "../data", "/vagrant_data"

    # Provider-specific configuration so you can fine-tune various
    # backing providers for Vagrant. These expose provider-specific options.
    #
    master.vm.provider "virtualbox" do |vb|
      # Customize the amount of memory on the VM:
      vb.memory = "2048"
    end

    # Enable provisioning with a shell script. Additional provisioners such as
    # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
    # documentation for more information about their specific syntax and use.
    # master.vm.provision "shell", inline: <<-SHELL
    #   sudo apt-get update
    #   sudo apt-get install -y apache2
    # SHELL
    master.vm.provision "ansible" do |ansible|
  	ansible.playbook = "site.yml"
        #ansible.verbose = "vvv"
    end
  end

#  config.vm.define "client" do |slave|
#    ip = "10.0.0.100"
#    mac = "0800278E158A"
#
#    # Use a image designed for pxe boot.
#    slave.vm.box = "steigr/pxe"
#
#    # Give the host a bogus IP, otherwise vagrant will bail out.
#    # Static mac address match up with dnsmasq dhcp config
#    # The auto_config: false tells vagrant not to change the hosts ip to the bogus one.
#    slave.vm.network "private_network", :adapter=>1, ip: "10.0.0.100" , :mac => mac , auto_config: false
#
#    # We dont need no stinking synced folder.
#    config.vm.synced_folder '.', '/vagrant', disabled: true
#
#    slave.vm.provider "virtualbox" do |vb, override|
#        vb.gui = true
#        # Chipset needs to be piix3, otherwise the machine wont boot properly.
#        vb.customize ["modifyvm", :id, "--chipset", "piix3"]
#    end
#  end

end

