#!/bin/bash

echo "--- Atualizando o sistema operacional (Guest) ---"
sudo apt update -y

echo "--- Instalando GCC, Python3, Pip e MySQL ---"
sudo apt install -y build-essential python3 python3-pip mysql-server

echo "--- Instalando Flask e PyMySQL ---"
sudo pip3 install Flask pymysql

echo "--- Configurando MySQL ---"
sudo service mysql start

# Cria usuário e banco, se não existirem
sudo mysql -e "CREATE DATABASE IF NOT EXISTS execucoes;"
sudo mysql -e "CREATE USER IF NOT EXISTS 'flaskuser'@'localhost' IDENTIFIED BY 'flaskpass';"
sudo mysql -e "GRANT ALL PRIVILEGES ON execucoes.* TO 'flaskuser'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Cria tabela se não existir
sudo mysql -D execucoes -e "
CREATE TABLE IF NOT EXISTS resultados (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome_programa VARCHAR(255) NOT NULL,
    tempo_execucao FLOAT,
    codigo_c MEDIUMTEXT,
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);"

echo "--- Provisionamento concluído ---"
