echo "--> Iniciando configuracao da VM"
# --- 1. Atualizar o Sistema ---
echo ">>> Atualizando os pacotes do sistema..."
sudo apt-get update
sudo apt-get upgrade -y

# --- 2. Instalar Software Essencial ---
echo ">>> Instalando software base (python, pip, build tools)..."
sudo apt-get install -y python3-pip python3-dev build-essential pkg-config libmysqlclient-dev

# --- 3. Instalar e Configurar MySQL ---
echo ">>> Instalando e configurando o MySQL..."
sudo apt-get install -y mysql-server
sudo systemctl start mysql
sudo systemctl enable mysql

echo ">>> Criando banco de dados e usuario a partir do .env..."
# Adicionado IF NOT EXISTS para o script rodar várias vezes sem erros
sudo mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NOME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NOME.* TO '$DB_USER'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# --- 4. Instalar Pacotes Python a partir do requirements.txt ---
echo ">>> Instalando as bibliotecas Python do arquivo requirements.txt..."
# O -H previne problemas de permissão com o cache do pip
sudo -H pip3 install -r /vagrant/requirements.txt

# --- 5. Instalar e Configurar o Apache2 ---
echo ">>> Instalando e configurando o Apache2 para o projeto em /vagrant..."
sudo apt-get install -y apache2
sudo a2enmod proxy proxy_http

# MODIFICADO: Aponta para os arquivos estáticos dentro de /vagrant
sudo bash -c 'cat > /etc/apache2/sites-available/001-django-app.conf' <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
   
    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:8000/
    ProxyPassReverse / http://127.0.0.1:8000/

    Alias /static/ /vagrant/static/
    <Directory /vagrant/static>
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

sudo a2dissite 000-default.conf
sudo a2ensite 001-django-app.conf
sudo systemctl restart apache2
 

# sudo mkdir -p /vagrant/django_app
# sudo chown -R vagrant:vagrant /vagrant/django_app
# cd /vagrant/django_app
# django-admin startproject executor_project .
# mv /vagrant/settings.py /vagrant/django_app/executor_project/
# python3 manage.py migrate

echo ">>> termino da configuracao da VM"
echo ">>> Acesse a aplicacao em http://localhost:8081"