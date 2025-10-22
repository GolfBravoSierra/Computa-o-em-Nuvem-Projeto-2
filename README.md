# Computa-o-em-Nuvem-Projeto-2

Esta pequena aplicação permite enviar um arquivo `.c`, escolher quantidade de CPU (0.5 - 2) e memória (10 - 4000 MB). O arquivo é compilado e executado em um namespace isolado na VM, com limites aplicados via cgroups. O tempo de execução e o nome do arquivo são registrados em um banco MySQL.

Pré-requisitos na VM (Ubuntu Server):
- root ou sudo
- gcc
- iproute2 (para `ip netns`)
- cgroup v1 montado em `/sys/fs/cgroup` com hierarquias `cpu` e `memory` (ou ajuste o script)
- Node.js (v16+)
- MySQL server

Instalação e provisão via Vagrant (recomendado)

O `webconfig.sh` (usado pelo `Vagrantfile`) já instala dependências básicas (gcc, iproute2, Node.js, MySQL, Apache) e executa `npm install` com ajustes para a pasta compartilhada.

Provisione/roda a VM a partir do diretório do projeto (onde está o `Vagrantfile`):

```powershell
cd 'c:\Users\Giovani\Documents\Computacao-em-Nuvem-Projeto-2'
vagrant up
```

Após o provisionamento automático:
- O Node app será instalado e um serviço systemd chamado `c-runner` será criado e iniciado automaticamente dentro da VM.
- As portas encaminhadas são:
	- host:8080 -> guest:80 (Apache)
	- host:3000 -> guest:3000 (Node app)

Entrando na VM (opcional) e verificações rápidas:

```bash
vagrant ssh
# ver arquivos do projeto montados em /vagrant
ls -la /vagrant
# ver status do serviço
systemctl status c-runner
```

Se preferir rodar manualmente (sem systemd):

```bash
cd /vagrant
npm install --unsafe-perm
chmod +x scripts/run_in_namespace.sh
node server.js
```

A aplicação expõe a página `index.html` na raiz da aplicação Node (porta 3000) e também o `index.html` foi copiado para o Apache (porta 80) durante a provisão. Para acessar:

- No host, acesse http://localhost:3000 para a aplicação Node (caso prefira executar Node diretamente)
- No host, acesse http://localhost:8080 para a cópia do `index.html` servida pelo Apache

Observações de segurança e limites:
- O script `scripts/run_in_namespace.sh` precisa ser executado como root porque usa `ip netns` e grava em `/sys/fs/cgroup`.
- Esta é uma implementação de exemplo. Executar código C arbitrário envolve riscos de segurança. Em produção, isolar ainda mais com namespaces, seccomp, usuários não privilegiados e timeouts rígidos.

Se precisar de ajuda com a configuração da VM (Vagrantfile), posso adicionar passos para provisionar as dependências automaticamente.

Nota sobre banco de dados:
- O `webconfig.sh` agora cria automaticamente o banco `submission_db` e um usuário padrão `nodeuser` com senha padrão `changeme` durante a provisão.
- Você pode alterar esses valores definindo variáveis de ambiente ao chamar o `vagrant` provision (exemplo):

```powershell
# no host, ao iniciar/provisionar a VM você pode passar env vars para o script
DB_USER=myuser DB_PASS=mysecret DB_NAME=mydb vagrant up --provision
```

Ou depois, edite `/etc/systemd/system/c-runner.service` dentro da VM para ajustar `DB_*` se preferir.

Uploads e diretório temporário:
- Para evitar problemas de sistema de arquivos compartilhado (VirtualBox shared folders), os arquivos enviados são armazenados por padrão em um diretório temporário do sistema (por exemplo `/tmp/c_runner_uploads`).
- Você pode sobrescrever o diretório definindo a variável de ambiente `UPLOAD_DIR` ao iniciar o serviço (ou no unit systemd). Por exemplo, no systemd unit: `Environment=UPLOAD_DIR=/var/uploads`.