# Projeto Computação em Nuvem — Execução de C com Flask e MySQL

Este projeto permite ao usuário:
- Enviar um código em C via interface web;
- Escolher um nome para o programa;
- Compilar e executar o código em um ambiente seguro;
- Registrar no banco MySQL:
  - Nome do programa,
  - Tempo de execução,
  - Código-fonte completo.

## 🚀 Como usar

```
vagrant up
```

```
vagrant ssh
```

```
cd /vagrant
```

```
python3 app.py
```

## Para checar os códigos armazaenados

#### Dentro da VM, executar:

```
sudo mysql -u flaskuser -p
```

#### No mysql:

```
USE execucoes;
```
```
SELECT id, nome_programa, tempo_execucao, LENGTH(codigo_c) AS tamanho FROM resultados;
```

Você verá algo como:
```
+----+---------------+----------------+----------+
| id | nome_programa | tempo_execucao | tamanho  |
+----+---------------+----------------+----------+
|  1 | teste.c       | 0.0023         | 124      |
|  2 | exemplo.c     | 0.0031         | 210      |
+----+---------------+----------------+----------+
```
