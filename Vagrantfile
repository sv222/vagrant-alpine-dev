# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Use the official Alpine Linux box from generic (verified vendor)
  config.vm.box = "generic/alpine319"
  config.vm.box_version = "4.3.12"

  # VM Configuration
  config.vm.hostname = "alpine-dev"

  # Network Configuration
  config.vm.network "forwarded_port", guest: 22, host: 2222, id: "ssh"
  config.vm.network "forwarded_port", guest: 8080, host: 8080
  # config.vm.network "private_network", type: "dhcp"
  config.vm.network "private_network", ip: "192.168.56.100"

  # Shared Folder
  config.vm.synced_folder "./shared", "/vagrant/shared",
    type: "virtualbox",
    create: true,
    mount_options: ["dmode=755", "fmode=644"]

  # Provider-specific configuration
  config.vm.provider "virtualbox" do |vb|
    vb.name = "Alpine-Dev-Environment"
    vb.memory = "2048"
    vb.cpus = 2

    # Performance optimizations
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    vb.customize ["modifyvm", :id, "--accelerate3d", "off"]
    vb.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
    vb.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
  end

  # Shell provisioning - runs on every vagrant up/provision
  config.vm.provision "shell",
    path: "scripts/provision.sh",
    run: "always",
    privileged: true

  # Display success message
  config.vm.post_up_message = <<-MSG
    ╔══════════════════════════════════════════════════════════════╗
    ║                 🎉 VM SUCCESSFULLY STARTED! 🎉                ║
    ║                                                              ║
    ║  Alpine Linux Development Environment is ready!              ║
    ║                                                              ║
    ║  SSH Access: vagrant ssh                                     ║
    ║  Web Access: http://localhost:8080                           ║
    ║  Shared Folder: ./shared → /vagrant/shared                   ║
    ║                                                              ║
    ║  System has been checked for updates!                        ║
    ║  Docker is installed and running!                            ║
    ║                                                              ║
    ║  Run 'vagrant provision' to check for updates manually      ║
    ╚══════════════════════════════════════════════════════════════╝
  MSG
end