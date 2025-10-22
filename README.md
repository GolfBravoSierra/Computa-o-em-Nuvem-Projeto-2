# Computa-o-em-Nuvem-Projeto-2

Esta pequena aplicação permite enviar um arquivo `.c`, escolher quantidade de CPU (0.5 - 2) e memória (10 - 4000 MB). O arquivo é compilado e executado em um namespace isolado na VM, com limites aplicados via cgroups. O tempo de execução e o nome do arquivo são registrados em um banco MySQL.

Pré-requisitos na VM (Ubuntu Server):
- root ou sudo
- gcc
- iproute2 (para `ip netns`)
- cgroup v1 montado em `/sys/fs/cgroup` com hierarquias `cpu` e `memory` (ou ajuste o script)
- Node.js (v16+)
- MySQL server

Instalação rápida:

```bash
# instalar dependências node
npm install

# ajustar variáveis de ambiente (opcional)
export DB_HOST=localhost; export DB_USER=root; export DB_PASS=yourpassword; export DB_NAME=submission_db

# tornar script executável (executar dentro da VM)
chmod +x scripts/run_in_namespace.sh

# iniciar servidor
node server.js
```

A aplicação expõe a página `index.html` na raiz (por padrão porta 3000). Submeta um `.c`, escolha CPU e memória e clique em executar.

Observações de segurança e limites:
- O script `scripts/run_in_namespace.sh` precisa ser executado como root porque usa `ip netns` e grava em `/sys/fs/cgroup`.
- Esta é uma implementação de exemplo. Executar código C arbitrário envolve riscos de segurança. Em produção, isolar ainda mais com namespaces, seccomp, usuários não privilegiados e timeouts rígidos.

Se precisar de ajuda com a configuração da VM (Vagrantfile), posso adicionar passos para provisionar as dependências automaticamente.