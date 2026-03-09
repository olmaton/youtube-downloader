import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/server_bloc.dart';

class ServerStatusBadge extends StatelessWidget {
  const ServerStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServerBloc, ServerBlocState>(
      builder: (context, state) {
        return Tooltip(
          message: _tooltip(state),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIndicator(context, state),
                const SizedBox(width: 6),
                Text(
                  _label(state),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIndicator(BuildContext context, ServerBlocState state) {
    if (state is ServerChecking || state is ServerStarting) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    Color color;
    if (state is ServerRunning) {
      color = Colors.green;
    } else if (state is ServerNotFound || state is ServerFailed) {
      color = Theme.of(context).colorScheme.error;
    } else {
      color = Colors.orange;
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  String _label(ServerBlocState state) {
    if (state is ServerChecking) return 'Verificando';
    if (state is ServerStarting) return 'Iniciando';
    if (state is ServerRunning) return 'Servidor OK';
    if (state is ServerNotFound) return 'Servidor no encontrado';
    if (state is ServerFailed) return 'Error servidor';
    return '';
  }

  String _tooltip(ServerBlocState state) {
    if (state is ServerChecking) return 'Comprobando conexión con el servidor...';
    if (state is ServerStarting) return 'Lanzando youtube-downloader.exe...';
    if (state is ServerRunning) return 'Servidor corriendo en localhost:4000';
    if (state is ServerNotFound) {
      return 'youtube-downloader.exe no encontrado.\nColócalo junto al ejecutable de la app.';
    }
    if (state is ServerFailed) {
      return 'El servidor no pudo iniciar. Verifica youtube-downloader.exe';
    }
    return '';
  }
}
