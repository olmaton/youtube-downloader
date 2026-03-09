const express = require('express');
const cors = require('cors');
const multer = require('multer');
const { spawn, exec } = require('child_process');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { convertToCompatibleMp4 } = require('./converter');
const db = require('./db');
const { saveEntry, getHistory, clearHistory, deleteEntry, renameEntry } = db;

// Añadir el directorio de trabajo al PATH para encontrar yt-dlp.exe y ffmpeg.exe
process.env.PATH += ';' + process.cwd();

const app = express();
const PORT = process.env.PORT || 4000;
const DOWNLOAD_DIR = path.join(process.cwd(), 'downloaded');
const UPLOADS_DIR  = path.join(process.cwd(), 'uploads');

app.use(cors());
app.use(express.json());

if (!fs.existsSync(DOWNLOAD_DIR)) {
  fs.mkdirSync(DOWNLOAD_DIR, { recursive: true });
}
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

// ─── Multer (recepción de archivos para conversión) ────────────────────────────
// Solo se aceptan archivos de video; nombre aleatorio para evitar colisiones.
const videoUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, cb) => cb(null, UPLOADS_DIR),
    filename:    (_req, _file, cb) => cb(null, `${crypto.randomUUID()}${path.extname(_file.originalname)}`),
  }),
  limits: { fileSize: 4 * 1024 * 1024 * 1024 }, // 4 GB máx
  fileFilter: (_req, file, cb) => {
    if (file.mimetype.startsWith('video/')) return cb(null, true);
    cb(new Error('Solo se permiten archivos de video'));
  },
});

// Almacenamiento en memoria de los jobs activos
// jobId → { status, percent, speed, eta, filePath, fileName, title, error, proc }
const jobs = new Map();

// ─── Utilidades ─────────────────────────────────────────────────────────────

function getYtDlpPath() {
  return path.join(process.cwd(), 'yt-dlp.exe');
}

/**
 * Valida y limpia la URL de YouTube.
 * Solo acepta URLs de youtube.com y youtu.be.
 * Devuelve null si la URL no es válida.
 */
function cleanYoutubeUrl(rawUrl) {
  try {
    const urlObj = new URL(rawUrl.trim());

    if (urlObj.hostname === 'youtu.be') {
      const id = urlObj.pathname.slice(1);
      if (/^[\w-]{11}$/.test(id)) return `https://www.youtube.com/watch?v=${id}`;
    }

    if (urlObj.hostname === 'www.youtube.com' || urlObj.hostname === 'youtube.com') {
      const id = urlObj.searchParams.get('v');
      if (id && /^[\w-]{11}$/.test(id)) return `https://www.youtube.com/watch?v=${id}`;
    }

    return null;
  } catch {
    return null;
  }
}

function cleanFilename(title) {
  return title
    .replace(/[\\/:*?"<>|]/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function getVideoFormat(quality) {
  const map = {
    '2160p': 'bestvideo[height<=2160][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=2160]+bestaudio/best',
    '1440p': 'bestvideo[height<=1440][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1440]+bestaudio/best',
    '1080p': 'bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1080]+bestaudio/best',
    '720p':  'bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=720]+bestaudio/best',
    '480p':  'bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=480]+bestaudio/best',
    '360p':  'bestvideo[height<=360][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=360]+bestaudio/best',
  };
  return map[quality] || 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best';
}

/**
 * Parsea una línea de progreso de yt-dlp:
 * [download]  45.3% of 50.23MiB at 2.34MiB/s ETA 00:22
 */
function parseProgress(line) {
  const match = line.match(
    /\[download\]\s+([\d.]+)%\s+of\s+([\d.]+\s*\S+)\s+at\s+([\d.]+\s*\S+)\s+ETA\s+(\S+)/
  );
  if (match) {
    return {
      percent: parseFloat(match[1]),
      totalSize: match[2],
      speed: match[3],
      eta: match[4],
    };
  }
  return null;
}

// ─── Endpoints ────────────────────────────────────────────────────────────────

/**
 * GET /
 * Documentación de la API en JSON.
 */
app.get('/', (_req, res) => {
  res.json({
    name: 'YouTube Downloader API',
    version: '1.0.0',
    endpoints: {
      'GET  /info?url=<youtube_url>':         'Información del video (título, miniatura, duración)',
      'POST /download':                        'Inicia descarga. Body: { url, format, quality }',
      'POST /convert':                         'Convierte un video subido a MP4 compatible (H.264+AAC). Form-data: video',
      'GET  /jobs':                            'Lista de todos los jobs activos',
      'GET  /progress/:jobId':                 'SSE — progreso en tiempo real',
      'GET  /status/:jobId':                   'Estado del job (JSON polling)',
      'GET  /file/:jobId':                     'Descarga el archivo terminado',
      'DELETE /job/:jobId':                    'Cancela y elimina el job',
      'GET  /history':                          'Historial de descargas y conversiones completadas',
      'DELETE /history':                        'Limpia todo el historial',
      'DELETE /history/:jobId':                 'Elimina una entrada del historial',
      'PATCH  /history/:jobId/rename':           'Renombra el archivo de una entrada del historial',
    },
    convertPreset: 'H.264 + AAC 192k + yuv420p + faststart',
    formats: ['mp3', 'mp4', 'webm'],
    qualities: ['360p', '480p', '720p', '1080p', '1440p', '2160p'],
  });
});

/**
 * GET /info?url=<youtube_url>
 * Devuelve: { title, duration, thumbnail, formats, qualities }
 */
app.get('/info', (req, res) => {
  const cleanUrl = cleanYoutubeUrl(req.query.url || '');
  if (!cleanUrl) {
    return res.status(400).json({ error: 'URL de YouTube inválida' });
  }

  const ytdlp = getYtDlpPath();
  // Usamos array de argumentos para evitar inyección de comandos
  const args = [
    '--no-playlist',
    '--print', '%(title)s|||%(duration)s|||%(thumbnail)s',
    cleanUrl,
  ];

  const proc = spawn(ytdlp, args);
  let output = '';
  let errOutput = '';

  proc.stdout.on('data', (d) => { output += d.toString(); });
  proc.stderr.on('data', (d) => { errOutput += d.toString(); });

  proc.on('exit', (code) => {
    if (code !== 0) {
      return res.status(500).json({ error: 'No se pudo obtener información del video', detail: errOutput.trim() });
    }
    const parts = output.trim().split('|||');
    res.json({
      title:     cleanFilename(parts[0] || ''),
      duration:  parseInt(parts[1]) || 0,  // segundos
      thumbnail: parts[2] || '',
      formats:   ['mp3', 'mp4', 'webm'],
      qualities: ['360p', '480p', '720p', '1080p', '1440p', '2160p'],
    });
  });
});

/**
 * GET /jobs
 * Devuelve la lista de todos los jobs con su estado actual.
 */
app.get('/jobs', (_req, res) => {
  const result = [];
  for (const [jobId, job] of jobs) {
    result.push({
      jobId,
      status:    job.status,
      percent:   job.percent,
      speed:     job.speed,
      eta:       job.eta,
      totalSize: job.totalSize,
      title:     job.title,
      fileName:  job.fileName,
      error:     job.error,
    });
  }
  res.json({ total: result.length, jobs: result });
});

/**
 * POST /download
 * Body: { url: string, format: 'mp3'|'mp4'|'webm', quality: '720p'|...  }
 * Respuesta: { jobId: string }
 */
app.post('/download', (req, res) => {
  const { url, format = 'mp4', quality = '720p' } = req.body;

  const cleanUrl = cleanYoutubeUrl(url || '');
  if (!cleanUrl) {
    return res.status(400).json({ error: 'URL de YouTube inválida' });
  }

  const validFormats = ['mp3', 'mp4', 'webm'];
  if (!validFormats.includes(format)) {
    return res.status(400).json({ error: 'Formato inválido. Use: mp3, mp4, webm' });
  }

  const jobId = crypto.randomUUID();
  jobs.set(jobId, {
    status: 'pending',
    percent: 0,
    speed: '',
    eta: '',
    totalSize: '',
    filePath: null,
    fileName: null,
    title: '',
    error: null,
    proc: null,
  });

  // Responder inmediatamente con el jobId
  res.status(202).json({ jobId });

  // Obtener título y arrancar descarga en segundo plano
  const ytdlp = getYtDlpPath();
  const titleProc = spawn(ytdlp, ['--no-playlist', '--print', '%(title)s', cleanUrl]);
  let titleOut = '';

  titleProc.stdout.on('data', (d) => { titleOut += d.toString(); });

  titleProc.on('exit', (code) => {
    const job = jobs.get(jobId);
    if (!job) return;

    if (code !== 0) {
      job.status = 'error';
      job.error = 'No se pudo obtener el título del video';
      return;
    }

    const title = cleanFilename(titleOut.trim());
    const label = (format !== 'mp3' && quality) ? ` [${quality}]` : '';
    const fileName = `${title}${label}.${format}`;
    const filePath = path.join(DOWNLOAD_DIR, fileName);

    job.title = title;
    job.fileName = fileName;
    job.status = 'downloading';

    let args = [];
    if (format === 'mp3') {
      args = ['-x', '--audio-format', 'mp3', '--audio-quality', '0',
              '--no-playlist', '--newline', '-o', filePath, cleanUrl];
    } else if (format === 'webm') {
      args = ['-f', getVideoFormat(quality), '--merge-output-format', 'webm',
              '--no-playlist', '--newline', '-o', filePath, cleanUrl];
    } else {
      args = ['-f', getVideoFormat(quality), '--merge-output-format', 'mp4',
              '--no-playlist', '--newline', '-o', filePath, cleanUrl];
    }

    const proc = spawn(ytdlp, args);
    job.proc = proc;

    const handleData = (data) => {
      data.toString().split('\n').forEach((line) => {
        const progress = parseProgress(line);
        if (progress) Object.assign(job, progress);
      });
    };

    proc.stdout.on('data', handleData);
    proc.stderr.on('data', handleData);

    proc.on('exit', (exitCode) => {
      if (!jobs.has(jobId)) return; // fue cancelado

      if (exitCode === 0 && fs.existsSync(filePath)) {
        job.status = 'done';
        job.percent = 100;
        job.filePath = filePath;
        db.saveEntry({ jobId, type: 'download', title, fileName, format, quality });
      } else {
        // yt-dlp a veces ajusta la extensión; buscar archivo más cercano
        const found = fs.readdirSync(DOWNLOAD_DIR)
          .find((f) => f.startsWith(title) && f.endsWith(`.${format}`));
        if (found) {
          job.status = 'done';
          job.percent = 100;
          job.filePath = path.join(DOWNLOAD_DIR, found);
          job.fileName = found;
          db.saveEntry({ jobId, type: 'download', title, fileName: found, format, quality });
        } else {
          job.status = 'error';
          job.error = 'La descarga falló o el archivo no pudo ser encontrado';
        }
      }
      job.proc = null;
    });
  });
});

/**
 * POST /convert
 * Acepta un archivo de video vía multipart/form-data (campo "video").
 * Lo convierte al preset MP4 de máxima compatibilidad usando ffmpeg.
 * Devuelve { jobId } — usar /progress/:jobId, /status/:jobId y /file/:jobId igual que en /download.
 */
app.post('/convert', videoUpload.single('video'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Se requiere un archivo de video en el campo "video"' });
  }

  const inputPath  = req.file.path;
  const baseName   = path.basename(req.file.originalname, path.extname(req.file.originalname));
  const safeBase   = baseName.replace(/[\\/:*?"<>|]/g, '').replace(/\s+/g, ' ').trim() || 'converted';
  const fileName   = `${safeBase} [compatible].mp4`;
  const outputPath = path.join(DOWNLOAD_DIR, fileName);
  const jobId      = crypto.randomUUID();

  jobs.set(jobId, {
    status:    'converting',
    percent:   0,
    speed:     '',
    eta:       '',
    totalSize: '',
    filePath:  null,
    fileName,
    title:     safeBase,
    error:     null,
    proc:      null,
  });

  res.status(202).json({ jobId });

  const { proc, promise } = convertToCompatibleMp4(inputPath, outputPath, (progress) => {
    const job = jobs.get(jobId);
    if (job) {
      job.percent   = progress.percent;
      job.speed     = progress.speed;
      job.totalSize = progress.size;
    }
  });

  const job = jobs.get(jobId);
  job.proc = proc;

  promise
    .then(() => {
      const j = jobs.get(jobId);
      if (!j) return; // fue cancelado
      j.status   = 'done';
      j.percent  = 100;
      j.filePath = outputPath;
      j.proc     = null;
      db.saveEntry({ jobId, type: 'convert', title: safeBase, fileName, format: 'mp4', quality: '' });
    })
    .catch((err) => {
      const j = jobs.get(jobId);
      if (!j) return;
      j.status = 'error';
      j.error  = err.message;
      j.proc   = null;
    })
    .finally(() => {
      // Limpiar el archivo de entrada temporal
      try { fs.unlinkSync(inputPath); } catch { /* ignorar */ }
    });
});

/**
 * PATCH /history/:jobId/rename
 * Renombra el archivo de una entrada del historial (en disco y en el registro).
 * Body: { name: string }  — solo el nombre base, sin extensión.
 * La extensión original se conserva automáticamente.
 */
app.patch('/history/:jobId/rename', (req, res) => {
  const { name } = req.body;

  if (!name || typeof name !== 'string' || !name.trim()) {
    return res.status(400).json({ error: 'Se requiere el campo "name" con el nuevo nombre' });
  }

  // Sanear: quitar caracteres inválidos y bloquear path traversal
  const safeName = name
    .replace(/[\\/:*?"<>|]/g, '')
    .replace(/\.\.+/g, '.')
    .replace(/\s+/g, ' ')
    .trim();

  if (!safeName) {
    return res.status(400).json({ error: 'El nombre resultante es inválido' });
  }

  // Buscar en historial para obtener el fileName actual
  const history = db.getHistory();
  const entry = history.find((e) => e.jobId === req.params.jobId);
  if (!entry) return res.status(404).json({ error: 'Entrada no encontrada en el historial' });

  const ext        = path.extname(entry.fileName);          // p.ej. ".mp4"
  const newFileName = `${safeName}${ext}`;
  const oldFilePath = path.join(DOWNLOAD_DIR, entry.fileName);
  const newFilePath = path.join(DOWNLOAD_DIR, newFileName);

  // Renombrar en disco solo si el archivo aun existe
  if (fs.existsSync(oldFilePath)) {
    try {
      fs.renameSync(oldFilePath, newFilePath);
    } catch (err) {
      return res.status(500).json({ error: 'No se pudo renombrar el archivo en disco', detail: err.message });
    }
  }

  // Actualizar la entrada persistida
  const updated = db.renameEntry(req.params.jobId, newFileName);

  // Actualizar el job en memoria si aun existe
  const job = jobs.get(req.params.jobId);
  if (job) {
    job.fileName = newFileName;
    if (job.filePath) job.filePath = newFilePath;
  }

  res.json({ ok: true, fileName: newFileName, entry: updated });
});

/**
 * GET /history
 * Devuelve el historial persistido de descargas y conversiones completadas.
 */
app.get('/history', (_req, res) => {
  const history = db.getHistory();
  res.json({ total: history.length, history });
});

/**
 * DELETE /history
 * Limpia todo el historial.
 */
app.delete('/history', (_req, res) => {
  db.clearHistory();
  res.json({ ok: true });
});

/**
 * DELETE /history/:jobId
 * Elimina una entrada específica del historial.
 */
app.delete('/history/:jobId', (req, res) => {
  const deleted = db.deleteEntry(req.params.jobId);
  if (!deleted) return res.status(404).json({ error: 'Entrada no encontrada en el historial' });
  res.json({ ok: true });
});

/**
 * GET /progress/:jobId
 * Server-Sent Events — el cliente recibe actualizaciones cada 500 ms hasta
 * que el job termina (status 'done' o 'error').
 */
app.get('/progress/:jobId', (req, res) => {
  const job = jobs.get(req.params.jobId);
  if (!job) {
    return res.status(404).json({ error: 'Job no encontrado' });
  }

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();

  const send = (data) => res.write(`data: ${JSON.stringify(data)}\n\n`);

  const interval = setInterval(() => {
    const j = jobs.get(req.params.jobId);
    if (!j) { clearInterval(interval); res.end(); return; }

    send({
      status:    j.status,
      percent:   j.percent,
      speed:     j.speed,
      eta:       j.eta,
      totalSize: j.totalSize,
      title:     j.title,
      fileName:  j.fileName,
      error:     j.error,
    });

    if (j.status === 'done' || j.status === 'error') {
      clearInterval(interval);
      res.end();
    }
  }, 500);

  req.on('close', () => clearInterval(interval));
});

/**
 * GET /status/:jobId
 * Polling simple — devuelve el estado actual del job como JSON.
 */
app.get('/status/:jobId', (req, res) => {
  const job = jobs.get(req.params.jobId);
  if (!job) return res.status(404).json({ error: 'Job no encontrado' });

  res.json({
    status:    job.status,
    percent:   job.percent,
    speed:     job.speed,
    eta:       job.eta,
    totalSize: job.totalSize,
    title:     job.title,
    fileName:  job.fileName,
    error:     job.error,
  });
});

/**
 * GET /file/:jobId
 * Descarga el archivo terminado. El archivo se elimina del servidor 5 s después.
 */
app.get('/file/:jobId', (req, res) => {
  const job = jobs.get(req.params.jobId);
  if (!job) return res.status(404).json({ error: 'Job no encontrado' });
  if (job.status !== 'done') return res.status(409).json({ error: 'La descarga aún no ha terminado' });
  if (!fs.existsSync(job.filePath)) return res.status(410).json({ error: 'Archivo no disponible en el servidor' });

  res.download(job.filePath, job.fileName, (err) => {
    if (!err) {
      setTimeout(() => {
        try { fs.unlinkSync(job.filePath); } catch { /* ya eliminado */ }
        jobs.delete(req.params.jobId);
      }, 5000);
    }
  });
});

/**
 * DELETE /job/:jobId
 * Cancela el proceso en curso (si existe) y elimina el job y su archivo.
 */
app.delete('/job/:jobId', (req, res) => {
  const jobId = req.params.jobId;
  const job = jobs.get(jobId);
  if (!job) return res.status(404).json({ error: 'Job no encontrado' });

  if (job.proc) {
    try { job.proc.kill(); } catch { /* ya terminado */ }
  }
  if (job.filePath && fs.existsSync(job.filePath)) {
    try { fs.unlinkSync(job.filePath); } catch { /* ignorar */ }
  }
  jobs.delete(jobId);
  res.json({ ok: true });
});

// ─── Inicio ───────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`\n🚀 Servidor corriendo en http://localhost:${PORT}\n`);
  console.log('  GET    /info?url=<yt_url>   → Información del video');
  console.log('  POST   /download            → Iniciar descarga { url, format, quality }');
  console.log('  POST   /convert             → Convertir video subido a MP4 compatible (form-data: video)');
  console.log('  GET    /jobs                → Lista de todos los jobs');
  console.log('  GET    /history             → Historial persistido');
  console.log('  DELETE /history             → Limpiar historial');
  console.log('  DELETE /history/:jobId      → Eliminar entrada del historial');
  console.log('  GET    /progress/:jobId     → Progreso en tiempo real (SSE)');
  console.log('  GET    /status/:jobId       → Estado JSON (polling)');
  console.log('  GET    /file/:jobId         → Descargar archivo');
  console.log('  DELETE /job/:jobId          → Cancelar / eliminar job\n');
});
