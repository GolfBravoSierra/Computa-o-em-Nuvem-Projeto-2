Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"

  config.vm.network "forwarded_port", guest: 8080, host: 8080
  config.vm.network "private_network", ip: "192.168.56.10"

  config.vm.provision "shell", path: "bootstrap.sh"

  config.vm.synced_folder ".", "/vagrant"
end
