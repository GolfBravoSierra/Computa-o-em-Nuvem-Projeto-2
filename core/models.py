from django.db import models

class Ambiente(models.Model):
    STATUS_CHOICES = [
        ('PENDENTE', 'Pendente'),
        ('EXECUTANDO', 'Em Execução'),
        ('CONCLUIDO', 'Concluído'),
        ('ERRO', 'Erro'),
    ]

    nome = models.CharField(max_length=100, help_text="Um nome para identificar o ambiente.")
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDENTE')

    limite_cpu = models.IntegerField(default=10, help_text="Percentual máximo de CPU a ser alocado (ex: 10 para 10%).")
    limite_memoria = models.IntegerField(default=256, help_text="Memória máxima em MB a ser alocada (ex: 256).")

    comando = models.TextField(help_text="O programa, comando ou script a ser executado.")
    arquivo_saida = models.CharField(max_length=255, blank=True, null=True, help_text="Caminho do arquivo para onde a saída será redirecionada.")

    data_criacao = models.DateTimeField(auto_now_add=True)
    data_atualizacao = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.nome} ({self.get_status_display()})"

    class Meta:
        ordering = ['-data_criacao']