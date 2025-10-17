echo "--> Iniciando configuracao da VM"
# --- 1. Atualizar o Sistema ---
echo ">>> Atualizando os pacotes do sistema..."
sudo apt-get update
sudo apt-get upgrade -y

# --- 2. Instalar Software Essencial e Dependências de Compilação ---
echo ">>> Instalando software base (python, pip)..."
sudo apt-get install -y python3-pip python3-dev build-essential
echo ">>> Instalando dependências de compilação para o MySQL..."
sudo apt-get install -y pkg-config libmysqlclient-dev

# --- 3. Instalar e Configurar MySQL ---
echo ">>> Instalando e configurando o MySQL..."
echo ">>> Nome da DB: $DB_NOME, Utilizador: $DB_USER"

sudo apt-get install -y mysql-server
sudo systemctl start mysql
sudo systemctl enable mysql

# Utiliza as variáveis de ambiente para criar a base de dados e o utilizador
sudo mysql -e "CREATE DATABASE $DB_NOME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NOME.* TO '$DB_USER'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# --- 4. Instalar Pacotes Python para o Projeto ---
echo ">>> Instalando as bibliotecas Python (Django, Gunicorn, MySQL-Client)..."
pip3 install django gunicorn mysqlclient

# --- 5. Instalar e Configurar o Apache2 ---
# (O resto do ficheiro continua igual...)
echo ">>> Instalando e configurando o Apache2 como Reverse Proxy..."
sudo apt-get install -y apache2

sudo a2enmod proxy
sudo a2enmod proxy_http

sudo bash -c 'cat > /etc/apache2/sites-available/001-django-app.conf' <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
   
    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:8000/
    ProxyPassReverse / http://127.0.0.1:8000/

    Alias /static/ /var/www/django_app/static/
    <Directory /var/www/django_app/static>
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

sudo a2dissite 000-default.conf
sudo a2ensite 001-django-app.conf
sudo systemctl restart apache2

echo ">>> termino da configuracao da VM"
echo ">>> Acesse a aplicacao em http://localhost:8081"