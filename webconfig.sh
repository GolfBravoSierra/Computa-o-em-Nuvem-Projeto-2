echo "--> Iniciando configuracao da VM"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

echo "--> Instalando pacotes base (gcc, build-essential, iproute2, curl, git)"
apt-get install -y build-essential gcc iproute2 curl git

echo "--> Instalando MySQL"
apt-get install -y mysql-server

echo "--> Instalando Apache"
apt-get install -y apache2

echo "--> Instalando Node.js (via NodeSource)"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

echo "--> Instalando dependências do projeto (npm)"
if [ -d /vagrant ]; then
	cd /vagrant
	npm install || true
	# tornar script executável
	chmod +x scripts/run_in_namespace.sh || true
	# copiar index para apache (opcional)
	cp /vagrant/index.html /var/www/html/ || true
fi

echo "-->termino da configuracao da VM"
echo "--> Acesse a aplicacao em http://localhost:8080 (porta 80 do guest)"