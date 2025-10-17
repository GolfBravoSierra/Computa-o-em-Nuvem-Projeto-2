# -*- mode: ruby -*-
# vi: set ft=ruby :

# Lê as variáveis do ficheiro .env e carrega-as num hash chamado 'env_vars'
env_vars = {}
if File.exist?('.env')
  File.foreach('.env') do |line|
    next if line.strip.empty? || line.start_with?('#')
    key, value = line.strip.split('=', 2)
    env_vars[key] = value
  end
end

Vagrant.configure("2") do |config|
  # Define a imagem do sistema operativo a ser usada
  config.vm.box = "ubuntu/focal64"
  
  # Define um nome para a nossa VM para fácil identificação
  config.vm.hostname = "web"

  # Redireciona a porta 8000 da VM para a porta 8080 da sua máquina
  config.vm.network "forwarded_port", guest: 8000, host: 8081

  # Configura os recursos da máquina virtual
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"
    vb.cpus = 2
  end

  # Define o script de provisionamento e passa as variáveis de ambiente
  config.vm.provision "shell", path: "scripts/webconfig.sh" do |s|
    s.env = env_vars
  end
end