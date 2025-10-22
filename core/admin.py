from django.contrib import admin
from .models import Ambiente  # 1. Importa o nosso modelo

# 2. Registra o modelo na interface de administração
@admin.register(Ambiente)
class AmbienteAdmin(admin.ModelAdmin):
    # 3. Configura como queremos que a lista seja exibida
    list_display = ('nome', 'status', 'limite_cpu', 'limite_memoria', 'data_criacao')

    # 4. Adiciona filtros na barra lateral
    list_filter = ('status', 'data_criacao')

    # 5. Adiciona uma barra de busca
    search_fields = ('nome', 'comando')