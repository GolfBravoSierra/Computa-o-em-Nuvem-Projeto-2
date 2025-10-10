echo "--> Iniciando configuracao da VM"
apt-get update

echo "--> Instalando MySQL"
apt-get install -y mysql

echo "--> Instalando Apache"
apt-get install -y apache

echo "-->termino da configuracao da VM"
echo "--> Acesse a aplicacao em http://localhost:8080"