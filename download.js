const readline = require('readline');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');

process.env.PATH += ';' + process.cwd(); // incluir ffmpeg.exe y yt-dlp.exe si están al lado

const isPkg = typeof process.pkg !== 'undefined';

// Función que limpia la URL
function cleanYoutubeUrl(fullUrl) {
  try {
    const urlObj = new URL(fullUrl.trim());
    if (urlObj.hostname.includes('youtube.com') || urlObj.hostname.includes('youtu.be')) {
      const videoId = urlObj.searchParams.get('v');
      if (videoId) {
        return `https://www.youtube.com/watch?v=${videoId}`;
      }
    }
    return fullUrl;
  } catch (e) {
    return fullUrl;
  }
}

function getYtDlpPath() {
  if (isPkg) {
    const tempPath = path.join(process.cwd(), 'yt-dlp.exe');
    const assetPath = path.join(__dirname, 'yt-dlp.exe');
    if (!fs.existsSync(tempPath)) {
      fs.copyFileSync(assetPath, tempPath);
    }
    return tempPath;
  } else {
    return path.join(process.cwd(), 'yt-dlp.exe');
  }
}

function cleanFilename(title) {
  return title
    .replace(/[\\/:*?"<>|]/g, '') // caracteres inválidos para Windows
    .replace(/\s+/g, ' ')         // múltiples espacios -> 1 espacio
    .trim();
}

function getVideoFormatByQuality(quality) {
  switch (quality) {
    case '1080p': return { format: 'bestvideo[height<=1080]+bestaudio/best', label: '1080p' };
    case '720p': return { format: 'bestvideo[height<=720]+bestaudio/best', label: '720p' };
    case '480p': return { format: 'bestvideo[height<=480]+bestaudio/best', label: '480p' };
    case '360p': return { format: 'bestvideo[height<=360]+bestaudio/best', label: '360p' };
    default: return { format: 'best', label: '' };
  }
}

const getTitle = async (url, ytdlpPath) => {
  return new Promise((resolve, reject) => {
    exec(`"${ytdlpPath}" --no-playlist --print "%(title)s" "${url}"`, (error, stdout) => {
      if (error) return reject('Error al obtener título');
      const title = cleanFilename(stdout.toString().trim());

      if (!title || /^youtube video/i.test(title)) {
        return reject('⚠️ No se pudo obtener un título válido.');
      }

      resolve(title);
    });
  });
};


const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function ask(question) {
  return new Promise(resolve => rl.question(question, resolve));
}

(async () => {
  try {
    const inputUrl = await ask('🔗 Ingresa la URL del video de YouTube: ');
    const url = cleanYoutubeUrl(inputUrl);

    if (!url || !url.startsWith('http')) {
      console.log('❌ URL inválida');
      rl.close();
      return;
    }

    const formatInput = await ask('🎵 Formato (mp4/mp3): ');
    const format = formatInput.trim().toLowerCase() === 'mp3' ? 'mp3' : 'mp4';

    const folderPathInput = await ask('📁 Carpeta donde guardar (deja vacío para usar "./downloaded"): ');
    const folderPath = folderPathInput.trim() || path.join(process.cwd(), 'downloaded');

    if (!fs.existsSync(folderPath)) {
      fs.mkdirSync(folderPath, { recursive: true });
      console.log(`📁 Carpeta creada: ${folderPath}`);
    }

    let quality = 'best';
    let qualityLabel = '';

    if (format === 'mp4') {
      const qualityInput = await ask('📺 Calidad deseada (1080p/720p/480p/360p) o enter para la mejor: ');
      const result = getVideoFormatByQuality(qualityInput.trim().toLowerCase());
      quality = result.format;
      qualityLabel = result.label;
    }

    const ytdlpPath = getYtDlpPath();
    const rawTitle = await getTitle(url, ytdlpPath);
    const videoTitle = cleanFilename(rawTitle);

    const extension = format;
    const label = qualityLabel ? ` [${qualityLabel}]` : '';
    const fileName = `${videoTitle}${label}.${extension}`;
    const output = path.join(folderPath, fileName);

    let command = '';

    if (format === 'mp3') {
      command = `"${ytdlpPath}" -x --audio-format mp3 --audio-quality 0 --no-playlist -o "${output}" "${url}"`;
      console.log('🎧 Descargando audio en mp3...');
    } else {
      command = `"${ytdlpPath}" -f "${quality}" --merge-output-format mp4 --no-playlist -o "${output}" "${url}"`;
      console.log(`🎬 Descargando video en mp4 (${qualityLabel || 'mejor calidad'})...`);
    }

    const proc = exec(command);

    proc.stdout.on('data', (data) => {
      console.log(data.toString());
    });

    proc.stderr.on('data', (data) => {
      console.error(data.toString());
    });

    proc.on('exit', (code) => {
      if (code === 0) {
        console.log(`✅ Descarga finalizada: ${fileName}`);
        // Limpia archivos sobrantes de fragmentos
        fs.readdirSync(folderPath).forEach(file => {
          if (
            file.includes(videoTitle) &&
            (file.endsWith('.webm') || file.match(/\.f\d+\.(mp4|webm)$/))
          ) {
            fs.unlinkSync(path.join(folderPath, file));
          }
        });
      } else {
        console.log('❌ Ocurrió un error durante la descarga.');
      }
      rl.close();
    });

  } catch (err) {
    console.error('⚠️ Error:', err);
    rl.close();
  }
})();
