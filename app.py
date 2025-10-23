from flask import Flask, request, render_template
import subprocess
import os
import tempfile
import time
import resource
import pymysql

app = Flask(__name__)

# --- CONFIGURAÇÃO PADRÃO DE SANDBOX ---
CPU_LIMIT = 5            # segundos
MEM_LIMIT = 134217728    # 128 MB (em bytes)
FSIZE_LIMIT = 1048576    # 1 MB
NPROC_LIMIT = 10         # processos filhos permitidos


def set_resource_limits():
    """Aplica limites de segurança (ulimit) ao processo filho."""
    resource.setrlimit(resource.RLIMIT_CPU, (CPU_LIMIT, CPU_LIMIT))
    resource.setrlimit(resource.RLIMIT_AS, (MEM_LIMIT, MEM_LIMIT))
    resource.setrlimit(resource.RLIMIT_FSIZE, (FSIZE_LIMIT, FSIZE_LIMIT))
    resource.setrlimit(resource.RLIMIT_NPROC, (NPROC_LIMIT, NPROC_LIMIT))


# --- FUNÇÃO PARA SALVAR NO MYSQL ---
def salvar_execucao(nome_programa, tempo_execucao, codigo_c, mem_limit_mb, cpu_limit_s):
    """Registra o nome, tempo, código e limites no banco MySQL."""
    try:
        conn = pymysql.connect(
            host='localhost',
            user='flaskuser',
            password='flaskpass',
            database='execucoes',
            cursorclass=pymysql.cursors.DictCursor
        )
        with conn:
            with conn.cursor() as cur:
                sql = """
                INSERT INTO resultados (nome_programa, tempo_execucao, codigo_c, mem_limit_mb, cpu_limit_s)
                VALUES (%s, %s, %s, %s, %s)
                """
                cur.execute(sql, (nome_programa, tempo_execucao, codigo_c, mem_limit_mb, cpu_limit_s))
                conn.commit()
    except Exception as e:
        print(f"[ERRO MYSQL] {e}")


# --- ROTA PRINCIPAL ---
@app.route('/', methods=['GET'])
def index():
    return render_template('index.html')


# --- EXECUÇÃO DO CÓDIGO ---
@app.route('/execute', methods=['POST'])
def execute_c_code():
    global MEM_LIMIT, CPU_LIMIT

    c_code = request.form.get('c_code')
    prog_name = request.form.get('prog_name', 'sem_nome')

    # Leitura dos limites personalizados via parâmetros GET
    mem_param = request.args.get('memory_limit')
    cpu_param = request.args.get('cpu_limit')

    mem_limit_mb = 128  # padrão
    cpu_limit_s = 5     # padrão

    if mem_param and mem_param.isdigit():
        mem_limit_mb = int(mem_param)
        MEM_LIMIT = mem_limit_mb * 1024 * 1024  # MB → bytes
    if cpu_param and cpu_param.isdigit():
        cpu_limit_s = int(cpu_param)
        CPU_LIMIT = cpu_limit_s

    if not c_code:
        return "Nenhum código C recebido.", 400, {'Content-Type': 'text/plain'}

    with tempfile.TemporaryDirectory() as temp_dir:
        c_file_path = os.path.join(temp_dir, 'code.c')
        binary_path = os.path.join(temp_dir, 'a.out')

        with open(c_file_path, 'w') as f:
            f.write(c_code)

        # --- Compilação ---
        compile_cmd = ['gcc', c_file_path, '-o', binary_path]
        try:
            compilation = subprocess.run(
                compile_cmd, capture_output=True, text=True, timeout=10, cwd=temp_dir
            )
            if compilation.returncode != 0:
                return f"Erro de compilação:\n{compilation.stderr}", 400, {'Content-Type': 'text/plain'}
        except subprocess.TimeoutExpired:
            return "Tempo limite de compilação excedido (10s).", 400, {'Content-Type': 'text/plain'}

        # --- Execução ---
        start_time = time.time()
        try:
            run = subprocess.run(
                [binary_path],
                capture_output=True,
                text=True,
                timeout=CPU_LIMIT + 1,
                cwd=temp_dir,
                preexec_fn=set_resource_limits
            )
            end_time = time.time()
            tempo_execucao = end_time - start_time

            salvar_execucao(prog_name, tempo_execucao, c_code, mem_limit_mb, cpu_limit_s)

            if run.returncode < 0:
                signal = abs(run.returncode)
                if signal == 9:
                    return f"Memory Limit Exceeded ({mem_limit_mb} MB)", 400, {'Content-Type': 'text/plain'}
                elif signal == 24:
                    return f"Time Limit Exceeded ({cpu_limit_s}s)", 400, {'Content-Type': 'text/plain'}
                else:
                    return f"Runtime Error (Killed by Signal {signal})", 400, {'Content-Type': 'text/plain'}

            return run.stdout, 200, {'Content-Type': 'text/plain; charset=utf-8'}

        except subprocess.TimeoutExpired:
            return f"Tempo limite de execução excedido ({cpu_limit_s}s).", 400, {'Content-Type': 'text/plain'}
        except Exception as e:
            return f"Erro em tempo de execução: {str(e)}", 500, {'Content-Type': 'text/plain'}


# --- HISTÓRICO (texto simples) ---
@app.route('/historico', methods=['GET'])
def historico():
    """Mostra histórico de execuções com limites."""
    try:
        conn = pymysql.connect(
            host='localhost',
            user='flaskuser',
            password='flaskpass',
            database='execucoes',
            cursorclass=pymysql.cursors.DictCursor
        )
        with conn:
            with conn.cursor() as cur:
                cur.execute("SELECT id, nome_programa, tempo_execucao, mem_limit_mb, cpu_limit_s, criado_em FROM resultados ORDER BY id DESC LIMIT 20")
                rows = cur.fetchall()
                saida = ""
                for row in rows:
                    saida += f"[{row['id']}] {row['nome_programa']} - {row['tempo_execucao']:.4f}s - Mem: {row['mem_limit_mb']}MB - CPU: {row['cpu_limit_s']}s - {row['criado_em']}\n"
                return saida, 200, {'Content-Type': 'text/plain'}
    except Exception as e:
        return f"Erro ao buscar histórico: {str(e)}", 500, {'Content-Type': 'text/plain'}


if __name__ == '__main__':
    print("Flask rodando em http://0.0.0.0:8080 (acesso via http://localhost:8080)")
    app.run(host='0.0.0.0', port=8080, debug=True)
