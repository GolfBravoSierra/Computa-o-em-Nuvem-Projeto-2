echo ">>> Iniciando configuracao da VM"
apt-get update

echo ">>> Instalando MySQL"
apt-get install mysql-server -y

echo ">>> Criando banco de dados e usuario a partir do .env..."
sudo mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NOME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NOME.* TO '$DB_USER'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo ">>> Instalando Apache"
apt-get install apache2 -y

echo ">>> Instalando PHP e o modulo do Apache para PHP"
apt-get install php libapache2-mod-php -y

echo ">>> configurando HTML"
sudo cp -r /vagrant/* /var/www/html/

echo ">>> termino da configuracao da VM"
echo ">>> Acesse a aplicacao em http://localhost:8081"