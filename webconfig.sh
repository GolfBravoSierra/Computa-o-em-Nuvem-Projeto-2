echo ">>> Iniciando configuracao da VM"
apt-get update

echo ">>> Instalando MySQL"
apt-get install mysql-server -y

echo ">>> Criando banco de dados e usuario a partir do .env..."
sudo mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NOME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NOME.* TO '$DB_USER'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo ">>> Instalando Apache e PHP"
apt-get install apache2 php libapache2-mod-php -y

echo ">>> Configurando o Apache para usar a pasta 'public'"
sudo sed -i 's|/var/www/html|/var/www/html/public|g' /etc/apache2/sites-available/000-default.conf

# --- ADICIONE ESTA NOVA SEÇÃO ---
echo ">>> Configurando Alias para a API"
# Cria um novo arquivo de configuração para nossa API
sudo tee /etc/apache2/conf-available/api.conf > /dev/null <<'EOF'
Alias /api.php /var/www/html/src/api.php
<Directory /var/www/html/src/>
    Require all granted
</Directory>
EOF
# Habilita a nossa nova configuração
sudo a2enconf api
# ---------------------------------

# Reinicia o Apache para aplicar TODAS as configurações (DocumentRoot e Alias)
sudo systemctl restart apache2

echo ">>> Limpando pasta padrao e copiando arquivos do projeto"
sudo cp -r /vagrant/* /var/www/html/

echo ">>> Termino da configuracao da VM"
echo ">>> Acesse a aplicacao em http://localhost:8081"