from flask import Flask, jsonify, request, render_template
import subprocess
import os
import tempfile
import time
import resource
import pymysql  # para conexão com o MySQL

app = Flask(__name__)

# --- CONFIGURAÇÃO DE SANDBOX ---
CPU_LIMIT = 5           # tempo máximo de CPU (segundos)
MEM_LIMIT = 268435456   # 256 MB
FSIZE_LIMIT = 1048576   # 1 MB
NPROC_LIMIT = 10        # processos filhos permitidos


def set_resource_limits():
    """Aplica limites de segurança (ulimit) ao processo filho."""
    resource.setrlimit(resource.RLIMIT_CPU, (CPU_LIMIT, CPU_LIMIT))
    resource.setrlimit(resource.RLIMIT_AS, (MEM_LIMIT, MEM_LIMIT))
    resource.setrlimit(resource.RLIMIT_FSIZE, (FSIZE_LIMIT, FSIZE_LIMIT))
    resource.setrlimit(resource.RLIMIT_NPROC, (NPROC_LIMIT, NPROC_LIMIT))


# --- FUNÇÃO PARA SALVAR NO MYSQL ---
def salvar_execucao(nome_programa, tempo_execucao, codigo_c):
    """Registra o nome, tempo e código no banco MySQL."""
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
                INSERT INTO resultados (nome_programa, tempo_execucao, codigo_c)
                VALUES (%s, %s, %s)
                """
                cur.execute(sql, (nome_programa, tempo_execucao, codigo_c))
                conn.commit()
    except Exception as e:
        print(f"[ERRO MYSQL] {e}")


# --- ROTAS ---
@app.route('/', methods=['GET'])
def index():
    return render_template('index.html')


@app.route('/execute', methods=['POST'])
def execute_c_code():
    c_code = request.form.get('c_code')
    prog_name = request.form.get('prog_name', 'sem_nome')

    if not c_code:
        return jsonify({"status": "Error", "stderr": "Nenhum código C recebido"}), 400

    with tempfile.TemporaryDirectory() as temp_dir:
        c_file_path = os.path.join(temp_dir, 'code.c')
        binary_path = os.path.join(temp_dir, 'a.out')

        with open(c_file_path, 'w') as f:
            f.write(c_code)

        # Compila
        compile_cmd = ['gcc', c_file_path, '-o', binary_path]
        try:
            compilation = subprocess.run(
                compile_cmd, capture_output=True, text=True, timeout=10, cwd=temp_dir
            )
            if compilation.returncode != 0:
                return jsonify({
                    "status": "Compilation Error",
                    "stdout": compilation.stdout,
                    "stderr": compilation.stderr
                })
        except subprocess.TimeoutExpired:
            return jsonify({"status": "Compilation Timeout"})

        # Executa com limites
        start_time = time.time()
        try:
            run = subprocess.run(
                [binary_path],
                capture_output=True,
                text=True,
                timeout=10,
                cwd=temp_dir,
                preexec_fn=set_resource_limits
            )
            end_time = time.time()

            tempo_execucao = end_time - start_time
            salvar_execucao(prog_name, tempo_execucao, c_code)

            if run.returncode < 0:
                signal = abs(run.returncode)
                msg = f"Runtime Error (Killed by Signal {signal})"
                if signal == 24:
                    msg = f"Time Limit Exceeded ({CPU_LIMIT}s)"
                return jsonify({
                    "status": msg,
                    "stdout": run.stdout,
                    "stderr": run.stderr
                })

            return jsonify({
                "status": "Success",
                "stdout": run.stdout,
                "stderr": run.stderr,
                "time_elapsed_wall": f"{tempo_execucao:.4f}s"
            })

        except subprocess.TimeoutExpired:
            return jsonify({"status": "Execution Timeout"})
        except Exception as e:
            return jsonify({"status": "Runtime Error", "stderr": str(e)}), 500


@app.route('/historico', methods=['GET'])
def historico():
    """Retorna o histórico de execuções armazenadas no banco."""
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
                cur.execute("SELECT id, nome_programa, tempo_execucao, codigo_c, criado_em FROM resultados ORDER BY id DESC LIMIT 20")
                rows = cur.fetchall()
                return jsonify(rows)
    except Exception as e:
        return jsonify({"status": "Erro ao buscar histórico", "erro": str(e)}), 500


if __name__ == '__main__':
    print("Flask rodando em http://0.0.0.0:8080 (acesso via http://localhost:8080)")
    app.run(host='0.0.0.0', port=8080, debug=True)
