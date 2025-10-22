import subprocess
import os
from django.core.management.base import BaseCommand
from core.models import Ambiente

class Command(BaseCommand):
    help = 'Executa os ambientes com status PENDENTE em namespaces e cgroups.'

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('>>> Iniciando a verificação de ambientes pendentes...'))

        # 1. Buscar ambientes pendentes
        ambientes_pendentes = Ambiente.objects.filter(status='PENDENTE')

        if not ambientes_pendentes.exists():
            self.stdout.write(self.style.SUCCESS('Nenhum ambiente pendente encontrado.'))
            return

        for ambiente in ambientes_pendentes:
            self.stdout.write(f"--- Processando ambiente: {ambiente.nome} (ID: {ambiente.id}) ---")
            try:
                # Marcar como executando para evitar repetição
                ambiente.status = 'EXECUTANDO'
                ambiente.save()

                # 2. Lógica para criar Cgroup e Namespace
                self.executar_ambiente(ambiente)

                self.stdout.write(self.style.SUCCESS(f'Ambiente "{ambiente.nome}" iniciado com sucesso.'))

            except Exception as e:
                self.stderr.write(self.style.ERROR(f'Erro ao executar o ambiente "{ambiente.nome}": {e}'))
                ambiente.status = 'ERRO'
                ambiente.save()

    def executar_ambiente(self, ambiente):
        # --- Criação e Configuração do Cgroup (Modelo de Delegação) ---
        self.stdout.write('Configurando cgroups...')
        
        # 1. Definir um diretório pai para todos os nossos ambientes
        CGROUP_PARENT = '/sys/fs/cgroup/puc_ambientes'
        os.makedirs(CGROUP_PARENT, exist_ok=True)
    
        # 2. Ativar (delegar) os controladores de CPU e memória para o nosso diretório pai.
        #    Este comando diz ao kernel: "A pasta puc_ambientes agora pode controlar cpu e memória".
        try:
            subprocess.run(f'echo "+cpu +memory" > /sys/fs/cgroup/cgroup.subtree_control', shell=True, check=True)
        except subprocess.CalledProcessError:
            # Ignora o erro "Invalid argument" que acontece se os controllers já estiverem ativos
            pass
        
        # 3. Criar o cgroup específico para este ambiente DENTRO do nosso diretório pai
        cgroup_name = f'ambiente_{ambiente.id}'
        cgroup_path = os.path.join(CGROUP_PARENT, cgroup_name)
        os.makedirs(cgroup_path, exist_ok=True)
        self.stdout.write(f'Cgroup criado em: {cgroup_path}')
    
        # 4. Definir os limites de recursos para o cgroup específico
        # Definir limite de memória (em bytes)
        mem_bytes = ambiente.limite_memoria * 1024 * 1024
        with open(os.path.join(cgroup_path, 'memory.max'), 'w') as f:
            f.write(str(mem_bytes))
        self.stdout.write(f'Limite de memória definido para: {mem_bytes} bytes')
    
        # Definir limite de CPU (formato: quota/periodo)
        cpu_quota = ambiente.limite_cpu * 1000
        cpu_period = 100000
        with open(os.path.join(cgroup_path, 'cpu.max'), 'w') as f:
            f.write(f"{cpu_quota} {cpu_period}")
        self.stdout.write(f'Limite de CPU definido para: {cpu_quota}/{cpu_period}')
    
        # --- Execução do Comando no Namespace ---
        # O comando `unshare` cria os namespaces.
        comando_str = ambiente.comando
        
        # O comando cgexec roda um processo dentro de um cgroup específico.
        # A sintaxe é: cgexec -g <controladores>:<caminho_relativo> comando...
        comando_final_str = (
            f"cgexec -g cpu,memory:puc_ambientes/{cgroup_name} "
            f"unshare --fork --pid --net --uts --mount-proc "
            f"bash -c '{comando_str}'"
        )
        
        self.stdout.write(f'Executando comando: "{comando_final_str}"')
        
        # Abrir arquivos para redirecionar a saída padrão e o erro padrão
        # O caminho será /vagrant/saida_ambiente_2.log
        caminho_saida = os.path.join('/vagrant', f'saida_ambiente_{ambiente.id}.log')
        ambiente.arquivo_saida = caminho_saida # Salva o caminho no banco de dados
        ambiente.save()
        
        arquivo_log = open(caminho_saida, 'w')
        
        # Usamos Popen para rodar em segundo plano
        process = subprocess.Popen(
            comando_final_str,
            shell=True,
            stdout=arquivo_log,
            stderr=arquivo_log
        )
        # NOTA: Esta é uma implementação simplificada.
        # O output do processo e o monitoramento se ele terminou/falhou
        # precisariam de uma lógica mais avançada (ex: threads, ou salvar o PID no banco).
        # Por enquanto, apenas o iniciamos. O status CONCLUÍDO/ERRO teria que ser
        # atualizado por outro processo de monitoramento.