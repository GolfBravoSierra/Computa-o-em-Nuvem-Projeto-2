echo "--> Iniciando configuracao da VM"
apt-get update

echo "--> Instalando MySQL"
apt-get install mysql-server -y

echo "--> Instalando Apache"
apt-get install apache2 -y

echo "--> Instalando PHP"
sudo apt install php-json
sudo systemctl restart apache2

echo "-->termino da configuracao da VM"
echo "--> Acesse a aplicacao em http://localhost:8080"