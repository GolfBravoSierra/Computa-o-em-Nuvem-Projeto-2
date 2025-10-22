const express = require('express');
const multer = require('multer');
const path = require('path');
const os = require('os');
const { execFile } = require('child_process');
const fs = require('fs');
const mysql = require('mysql2/promise');

// Use a temp directory outside the /vagrant shared folder to avoid VirtualBox vboxsf ETXTBSY errors
const UPLOAD_DIR = process.env.UPLOAD_DIR || path.join(os.tmpdir(), 'c_runner_uploads');
if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const app = express();
const upload = multer({ dest: UPLOAD_DIR });

// DB config from env
const DB_HOST = process.env.DB_HOST || 'localhost';
const DB_USER = process.env.DB_USER || 'root';
const DB_PASS = process.env.DB_PASS || '';
const DB_NAME = process.env.DB_NAME || 'submission_db';

let pool;

async function ensureDb() {
  pool = mysql.createPool({ host: DB_HOST, user: DB_USER, password: DB_PASS, waitForConnections: true, connectionLimit: 5 });
  const conn = await pool.getConnection();
  await conn.query(`CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\``);
  await conn.query(`USE \`${DB_NAME}\``);
  await conn.query(`CREATE TABLE IF NOT EXISTS submissions (id INT AUTO_INCREMENT PRIMARY KEY, filename VARCHAR(255) NOT NULL, execution_time_secs DOUBLE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)`);
  conn.release();
}

app.post('/upload', upload.single('cfile'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ message: 'Nenhum arquivo enviado' });
    const cpu = parseFloat(req.body.cpu);
    const mem = parseInt(req.body.mem, 10);
    if (isNaN(cpu) || cpu < 0.5 || cpu > 2) return res.status(400).json({ message: 'CPU inválida' });
    if (isNaN(mem) || mem < 10 || mem > 4000) return res.status(400).json({ message: 'Memória inválida' });

    const originalName = req.file.originalname;
    const savedPath = path.join(UPLOAD_DIR, req.file.filename + path.extname(originalName));
    fs.renameSync(req.file.path, savedPath);

    // call the script that will compile and run inside namespace
    // script will print EXECUTION_TIME:<secs> on stdout
  const scriptPath = path.join(__dirname, 'scripts', 'run_in_namespace.sh');
  // determine timeout (use env or default)
  const timeoutSecs = parseInt(process.env.DEFAULT_TIMEOUT_SECS || '10', 10);
  const args = [savedPath, cpu.toString(), mem.toString(), timeoutSecs.toString()];

  const start = Date.now();
  // set execFile timeout slightly above the internal timeout (ms)
  const execTimeoutMs = (timeoutSecs + 5) * 1000;
  // run the script via sudo so the script can perform privileged operations (namespaces, cgroups)
  execFile('sudo', [scriptPath, ...args], { maxBuffer: 10 * 1024 * 1024, timeout: execTimeoutMs }, async (err, stdout, stderr) => {
      const duration = (Date.now() - start) / 1000; // fallback duration
      if (err) {
        console.error('exec error', err);
        console.error('stderr', stderr);
        // if execFile timed out, include that info
        const details = stderr || err.message;
        return res.status(500).json({ message: 'Erro ao executar o programa', details });
      }
      // try to parse execution time from script output
      let execTime = duration;
      const m = stdout.match(/EXECUTION_TIME:([0-9.]+)/);
      if (m) execTime = parseFloat(m[1]);

      // insert into DB
      try {
        const conn = await pool.getConnection();
        await conn.query(`USE \`${DB_NAME}\``);
        await conn.query('INSERT INTO submissions (filename, execution_time_secs) VALUES (?, ?)', [originalName, execTime]);
        conn.release();
      } catch (dbErr) {
        console.error('DB error', dbErr);
      }

      return res.json({ message: 'Execução completa', filename: originalName, execution_time_secs: execTime, raw_output: stdout });
    });

  } catch (e) {
    console.error(e);
    res.status(500).json({ message: 'Erro no servidor' });
  }
});

app.use(express.static(path.join(__dirname)));

const PORT = process.env.PORT || 3000;
// default timeout for program execution (seconds)
const DEFAULT_TIMEOUT_SECS = parseInt(process.env.DEFAULT_TIMEOUT_SECS || '10', 10);

// route to list submissions
app.get('/submissions', async (req, res) => {
  try {
    const conn = await pool.getConnection();
    await conn.query(`USE \`${DB_NAME}\``);
    const [rows] = await conn.query('SELECT id, filename, execution_time_secs, created_at FROM submissions ORDER BY created_at DESC LIMIT 100');
    conn.release();
    res.json({ submissions: rows });
  } catch (e) {
    console.error('error fetching submissions', e);
    res.status(500).json({ message: 'Erro ao recuperar submissões' });
  }
});
ensureDb().then(() => {
  app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
}).catch(err => {
  console.error('DB init error', err);
  process.exit(1);
});
