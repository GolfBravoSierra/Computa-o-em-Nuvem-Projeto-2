echo "--> Iniciando configuracao da VM"
apt-get update

echo "--> Instalando MySQL"
apt-get install mysql-server -y

echo "--> Instalando Apache"
apt-get install apache2 -y

echo "-->termino da configuracao da VM"
echo "--> Acesse a aplicacao em http://localhost:8080"