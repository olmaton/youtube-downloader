/**
 * logger.js — Sistema de logging para youtube-downloader
 *
 * Niveles : DEBUG < INFO < WARN < ERROR
 * Salida  : consola (con colores ANSI) + archivo server.log
 * Rotación: cuando server.log supera MAX_SIZE se mueve a server.old.log
 */

'use strict';

const fs   = require('fs');
const path = require('path');

// ─── Configuración ────────────────────────────────────────────────────────────

// Cuando corre como .exe compilado con pkg, process.pkg está definido y
// process.execPath apunta al propio ejecutable → usamos su carpeta.
// En desarrollo (node index.js) se usa process.cwd() como antes.
const BASE_DIR  = process.pkg ? path.dirname(process.execPath) : process.cwd();
const LOG_FILE  = path.join(BASE_DIR, 'server.log');
const MAX_SIZE  = 5 * 1024 * 1024; // 5 MB por archivo

const LEVEL_RANK = { DEBUG: 0, INFO: 1, WARN: 2, ERROR: 3 };

// Nivel mínimo de log: se puede sobreescribir con variable de entorno LOG_LEVEL
const MIN_LEVEL = LEVEL_RANK[(process.env.LOG_LEVEL || 'DEBUG').toUpperCase()] ?? 0;

// Colores ANSI para la consola
const C = {
  DEBUG : '\x1b[36m',   // cian
  INFO  : '\x1b[32m',   // verde
  WARN  : '\x1b[33m',   // amarillo
  ERROR : '\x1b[31m',   // rojo
  RESET : '\x1b[0m',
  DIM   : '\x1b[2m',
};

// ─── Utilidades internas ──────────────────────────────────────────────────────

function timestamp() {
  return new Date().toISOString();
}

/**
 * Convierte los argumentos de log a una cadena legible.
 * Los objetos/errores se serializan automáticamente.
 */
function argsToString(args) {
  return args
    .map((a) => {
      if (a instanceof Error) {
        return a.stack || `${a.name}: ${a.message}`;
      }
      if (typeof a === 'object' && a !== null) {
        try { return JSON.stringify(a); } catch { return String(a); }
      }
      return String(a);
    })
    .join(' ');
}

/**
 * Rota el archivo de log si supera MAX_SIZE.
 * El archivo anterior queda como server.old.log.
 */
function rotateIfNeeded() {
  try {
    const stat = fs.statSync(LOG_FILE);
    if (stat.size >= MAX_SIZE) {
      const backup = LOG_FILE.replace('.log', '.old.log');
      if (fs.existsSync(backup)) fs.unlinkSync(backup);
      fs.renameSync(LOG_FILE, backup);
    }
  } catch {
    // El archivo puede no existir aún — ignorar
  }
}

/**
 * Escribe una entrada de log en consola y en archivo.
 */
function write(level, args) {
  if (LEVEL_RANK[level] < MIN_LEVEL) return;

  const ts  = timestamp();
  const msg = argsToString(args);
  const line = `[${ts}] [${level.padEnd(5)}] ${msg}`;

  // ── Consola ──────────────────────────────────────────────────────────────
  const color = C[level] || '';
  const stream = level === 'ERROR' || level === 'WARN' ? process.stderr : process.stdout;
  try {
    stream.write(`${C.DIM}${ts}${C.RESET} ${color}[${level.padEnd(5)}]${C.RESET} ${msg}\n`);
  } catch (e) {
    // EPIPE u otro error de consola — ignorar, el log en archivo sigue funcionando
    if (e.code !== 'EPIPE') throw e;
  }

  // ── Archivo ──────────────────────────────────────────────────────────────
  rotateIfNeeded();
  try {
    fs.appendFileSync(LOG_FILE, line + '\n');
  } catch {
    // No podemos hacer nada si el sistema de archivos falla
  }
}

// ─── API pública ──────────────────────────────────────────────────────────────

const logger = {
  debug : (...args) => write('DEBUG', args),
  info  : (...args) => write('INFO',  args),
  warn  : (...args) => write('WARN',  args),
  error : (...args) => write('ERROR', args),

  /** Alias de info — facilita reemplazar console.log en otros módulos */
  log   : (...args) => write('INFO',  args),

  /**
   * Middleware Express que registra cada request HTTP.
   * Uso: app.use(logger.requestMiddleware)
   */
  requestMiddleware(req, res, next) {
    const start = Date.now();
    res.on('finish', () => {
      const ms      = Date.now() - start;
      const status  = res.statusCode;
      const level   = status >= 500 ? 'ERROR' : status >= 400 ? 'WARN' : 'INFO';
      write(level, [`HTTP ${req.method} ${req.originalUrl} → ${status} (${ms}ms)`]);
    });
    next();
  },

  /** Ruta del archivo de log activo */
  logFile: LOG_FILE,
};

module.exports = logger;
