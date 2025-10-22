# -*- mode: ruby -*-
# vi: set ft=ruby :

env_vars = {}
if File.exist?('.env')
  File.foreach('.env') do |line|
    next if line.strip.empty? || line.start_with?('#')
    key, value = line.strip.split('=', 2)
    env_vars[key] = value
  end
end

Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "bento/ubuntu-22.04"
  
  # Define um nome para a nossa VM para fácil identificação
  config.vm.hostname = "web"

  # Redireciona a porta 8000 da VM para a porta 8080 da sua máquina
  config.vm.network "forwarded_port", guest: 80, host: 8081

  # Configura os recursos da máquina virtual
  config.vm.provider "virtualbox" do |vb|
    vb.gui = true
    vb.memory = "4096"
    vb.cpus = 2
  end

  config.vm.provision "shell", path: "webconfig.sh" do |s|
    s.env = env_vars
  end
end
