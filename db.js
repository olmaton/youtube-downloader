/**
 * db.js
 *
 * Persistencia simple en disco usando un archivo JSON (history.json).
 * Cada entrada representa un video descargado o convertido exitosamente.
 *
 * Estructura de cada entrada:
 * {
 *   jobId:       string   — identificador único del job
 *   type:        string   — 'download' | 'convert'
 *   title:       string   — título del video / nombre base del archivo
 *   fileName:    string   — nombre del archivo resultante con extensión
 *   format:      string   — mp3 | mp4 | webm
 *   quality:     string   — 720p | 1080p | … (vacío en conversiones y mp3)
 *   completedAt: string   — fecha ISO 8601
 * }
 */

'use strict';

const fs   = require('fs');
const path = require('path');

const HISTORY_FILE = path.join(process.cwd(), 'history.json');

// Cargar historial desde disco al arrancar; si el archivo no existe, empezar vacío.
let _history = [];
if (fs.existsSync(HISTORY_FILE)) {
  try {
    _history = JSON.parse(fs.readFileSync(HISTORY_FILE, 'utf8'));
    if (!Array.isArray(_history)) _history = [];
  } catch {
    _history = [];
  }
}

/** Escribe el array completo al disco de forma síncrona. */
function _persist() {
  fs.writeFileSync(HISTORY_FILE, JSON.stringify(_history, null, 2), 'utf8');
}

/**
 * Guarda una entrada en el historial.
 * @param {{ jobId, type, title, fileName, format, quality }} entry
 */
function saveEntry({ jobId, type, title, fileName, format = '', quality = '' }) {
  const record = {
    jobId,
    type,
    title,
    fileName,
    format,
    quality,
    completedAt: new Date().toISOString(),
  };
  _history.push(record);
  _persist();
  return record;
}

/**
 * Devuelve una copia del historial completo (más reciente primero).
 * @returns {Array}
 */
function getHistory() {
  return [..._history].reverse();
}

/**
 * Elimina todas las entradas del historial.
 */
function clearHistory() {
  _history = [];
  _persist();
}

/**
 * Elimina una entrada por jobId.
 * @param {string} jobId
 * @returns {boolean} true si fue encontrada y eliminada
 */
function deleteEntry(jobId) {
  const before = _history.length;
  _history = _history.filter((e) => e.jobId !== jobId);
  if (_history.length !== before) {
    _persist();
    return true;
  }
  return false;
}

/**
 * Renombra una entrada del historial y devuelve el registro actualizado.
 * No toca el disco; el renombrado del archivo lo maneja el llamador.
 * @param {string} jobId
 * @param {string} newFileName  — nombre de archivo completo con extensión
 * @returns {object|null} registro actualizado, o null si no se encontró
 */
function renameEntry(jobId, newFileName) {
  const entry = _history.find((e) => e.jobId === jobId);
  if (!entry) return null;
  entry.fileName = newFileName;
  _persist();
  return { ...entry };
}

module.exports = { saveEntry, getHistory, clearHistory, deleteEntry, renameEntry };
