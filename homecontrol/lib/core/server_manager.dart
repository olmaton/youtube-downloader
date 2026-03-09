import 'dart:io';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'constants.dart';

enum ServerState { checking, starting, running, error }

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

class ServerManager {
  Process? _process;
  bool _managed = false; // true if WE started the process

  /// Checks if the server is already up; if not, tries to launch the exe.
  /// Only acts on Windows desktop.
  Future<ServerState> ensureRunning() async {
    if (!Platform.isWindows) return ServerState.running;

    if (await ping()) return ServerState.running;

    final exePath = resolveExePath();
    if (exePath == null) {
      _log.w('youtube-downloader.exe not found');
      return ServerState.error;
    }

    _log.i('Starting server: $exePath');
    try {
      _process = await Process.start(
        exePath,
        [],
        workingDirectory: File(exePath).parent.path,
        mode: ProcessStartMode.detachedWithStdio,
      );
      _managed = true;

      // Wait up to 10 s for the server to be ready
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (await ping()) {
          _log.i('Server is ready (pid: ${_process!.pid})');
          return ServerState.running;
        }
      }

      _log.e('Server did not become ready in time');
      return ServerState.error;
    } catch (e) {
      _log.e('Failed to start server', error: e);
      return ServerState.error;
    }
  }

  Future<void> dispose() async {
    if (_managed && _process != null) {
      _log.i('Stopping managed server process');
      _process!.kill();
    }
  }

  Future<bool> ping() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 2),
        receiveTimeout: const Duration(seconds: 2),
      ));
      final res = await dio.get<dynamic>(AppConstants.baseUrl);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Search order:
  /// 1. Same folder as the running Flutter executable (distribution)
  /// 2. Parent of Flutter exe folder (common layout: app/ + server/)
  /// 3. Current working directory (development)
  String? resolveExePath() {
    const exeName = 'youtube-downloader.exe';
    final candidates = [
      File(pathJoin(File(Platform.resolvedExecutable).parent.path, exeName)),
      File(pathJoin(File(Platform.resolvedExecutable).parent.parent.path, exeName)),
      File(pathJoin(Directory.current.path, exeName)),
    ];
    for (final f in candidates) {
      if (f.existsSync()) return f.path;
    }
    return null;
  }

  String pathJoin(String dir, String file) =>
      '$dir${Platform.pathSeparator}$file';
}
