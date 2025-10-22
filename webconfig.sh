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
	# disable bin links to avoid symlink issues on VirtualBox shared folders
	npm config set bin-links false || true
	# install with unsafe-perm to avoid permission problems
	npm install --unsafe-perm || true
	# tornar script executável
	chmod +x scripts/run_in_namespace.sh || true
	# copiar index para apache (opcional)
	cp /vagrant/index.html /var/www/html/ || true

	# === Create DB and user (with defaults, can be overridden by env vars passed to vagrant) ===
	DB_NAME=${DB_NAME:-submission_db}
	DB_USER=${DB_USER:-nodeuser}
	DB_PASS=${DB_PASS:-changeme}

	# wait for mysql service to be active
	MAX_WAIT=60
	WAITED=0
	echo "--> waiting for mysql to be ready..."
	while ! mysqladmin ping >/dev/null 2>&1; do
	  sleep 1
	  WAITED=$((WAITED+1))
	  if [ $WAITED -ge $MAX_WAIT ]; then
	    echo "mysql did not become available after ${MAX_WAIT}s"
	    break
	  fi
	done

	# create database and user (use sudo mysql to run as root)
	sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;" || true
	sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" || true
	sudo mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;" || true

	# create a systemd service to run the node app on boot with DB envs
	cat <<SERVICE > /etc/systemd/system/c-runner.service
[Unit]
Description=C Runner Node App
After=network.target mysql.service

[Service]
Type=simple
WorkingDirectory=/vagrant
ExecStart=/usr/bin/node /vagrant/server.js
Restart=on-failure
User=vagrant
Environment=NODE_ENV=production
Environment=DB_HOST=localhost
Environment=DB_USER=${DB_USER}
Environment=DB_PASS=${DB_PASS}
Environment=DB_NAME=${DB_NAME}

[Install]
WantedBy=multi-user.target
SERVICE

	# reload systemd and enable/start the service
	systemctl daemon-reload || true
	systemctl enable c-runner.service || true
	systemctl restart c-runner.service || true
fi

# allow vagrant to run the runner script without password (for namespace/cgroup ops)
if [ -f /vagrant/scripts/run_in_namespace.sh ]; then
  echo "vagrant ALL=(root) NOPASSWD: /vagrant/scripts/run_in_namespace.sh" > /etc/sudoers.d/c_runner || true
  chmod 440 /etc/sudoers.d/c_runner || true
fi

echo "-->termino da configuracao da VM"
echo "--> Acesse a aplicacao em http://localhost:8080 (porta 80 do guest)"