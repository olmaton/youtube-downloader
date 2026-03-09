/**
 * converter.js
 *
 * Módulo de conversión de video a MP4 compatible con la mayoría de reproductores.
 *
 * Preset de alta calidad con compatibilidad máxima:
 *   - Video : H.264 (libx264), CRF 18, preset slow, perfil High 4.1
 *   - Audio : AAC 256 kbps, estéreo
 *   - Pixel : yuv420p  (compatible con dispositivos móviles y reproductores básicos)
 *   - Flags : -movflags +faststart  (inicia reproducción sin esperar descarga completa)
 */

'use strict';

const { spawn } = require('child_process');
const path = require('path');

const FFMPEG_PATH = path.join(process.cwd(), 'ffmpeg.exe');

// Argumentos de ffmpeg para alta calidad con compatibilidad máxima
const COMPATIBLE_PRESET = [
  '-c:v', 'libx264',
  '-preset', 'slow',
  '-crf', '18',
  '-profile:v', 'high',
  '-level:v', '4.1',
  '-c:a', 'aac',
  '-b:a', '256k',
  '-ac', '2',
  '-pix_fmt', 'yuv420p',
  '-movflags', '+faststart',
];

/**
 * Convierte "HH:MM:SS.ss" a segundos totales.
 * @param {string} timeStr
 * @returns {number}
 */
function timeToSeconds(timeStr) {
  const parts = timeStr.split(':').map(parseFloat);
  return parts[0] * 3600 + parts[1] * 60 + parts[2];
}

/**
 * Parsea líneas de salida de ffmpeg y extrae datos de progreso.
 * ffmpeg escribe en stderr líneas como:
 *   frame=  500 fps=25 q=23.0 size=    8192kB time=00:00:20.00 bitrate=3355.4kbits/s speed=  1x
 *
 * @param {string} text      — bloque de texto de stderr
 * @param {number} totalSecs — duración total en segundos (ya conocida)
 * @returns {{ percent: number, fps: number, speed: string, time: string } | null}
 */
function parseProgressLine(text, totalSecs) {
  const timeMatch = text.match(/time=(\d{2}:\d{2}:\d{2}\.\d+)/);
  if (!timeMatch) return null;

  const currentSecs = timeToSeconds(timeMatch[1]);
  const percent = totalSecs > 0
    ? Math.min(100, parseFloat(((currentSecs / totalSecs) * 100).toFixed(1)))
    : 0;

  const fpsMatch   = text.match(/fps=\s*([\d.]+)/);
  const speedMatch = text.match(/speed=\s*([\d.x]+)/);
  const sizeMatch  = text.match(/size=\s*(\S+)/);

  return {
    percent,
    fps:   fpsMatch   ? parseFloat(fpsMatch[1])  : 0,
    speed: speedMatch ? speedMatch[1]              : '',
    size:  sizeMatch  ? sizeMatch[1]               : '',
    time:  timeMatch[1],
  };
}

/**
 * Convierte cualquier video al preset de MP4 compatible.
 *
 * @param {string}   inputPath   — ruta absoluta del archivo de entrada
 * @param {string}   outputPath  — ruta absoluta del archivo .mp4 de salida
 * @param {function} onProgress  — callback({ percent, fps, speed, size, time })
 *
 * @returns {{ proc: import('child_process').ChildProcess, promise: Promise<void> }}
 *   `proc`    — proceso de ffmpeg (permite cancelarlo con proc.kill())
 *   `promise` — resuelve al terminar, rechaza si ffmpeg falla
 */
function convertToCompatibleMp4(inputPath, outputPath, onProgress) {
  const args = [
    '-i', inputPath,
    ...COMPATIBLE_PRESET,
    '-y',          // sobreescribir sin preguntar
    outputPath,
  ];

  const proc = spawn(FFMPEG_PATH, args);
  let totalSecs = 0;
  let stderrBuffer = '';

  const promise = new Promise((resolve, reject) => {
    // ffmpeg escribe todo en stderr
    proc.stderr.on('data', (data) => {
      const text = data.toString();
      stderrBuffer += text;

      // Extraer duración total la primera vez que aparece
      if (totalSecs === 0) {
        const durMatch = stderrBuffer.match(/Duration:\s*(\d{2}:\d{2}:\d{2}\.\d+)/);
        if (durMatch) totalSecs = timeToSeconds(durMatch[1]);
      }

      // Notificar progreso si hay callback
      if (typeof onProgress === 'function') {
        const progress = parseProgressLine(text, totalSecs);
        if (progress) onProgress(progress);
      }
    });

    proc.on('exit', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`ffmpeg terminó con código ${code}`));
      }
    });

    proc.on('error', (err) => {
      reject(new Error(`No se pudo iniciar ffmpeg: ${err.message}`));
    });
  });

  return { proc, promise };
}

module.exports = { convertToCompatibleMp4 };
