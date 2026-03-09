import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/convert_bloc.dart';
import '../bloc/download_bloc.dart';
import '../bloc/history_bloc.dart';
import '../bloc/local_media_bloc.dart';
import '../bloc/server_bloc.dart';
import '../widgets/convert_manager_dialog.dart';
import '../widgets/download_manager_dialog.dart';
import '../widgets/history_tile.dart';
import '../widgets/media_tile.dart';
import '../widgets/server_status_badge.dart';

class MediaScreen extends StatelessWidget {
  const MediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: MultiBlocListener(
        listeners: [
          // When download completes, refresh local list + show snackbar
          BlocListener<DownloadBloc, DownloadState>(
            listener: (context, state) {
              if (state is DownloadCompleted) {
                context.read<LocalMediaBloc>().add(LoadLocalMediaEvent());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('✓ Guardado: ${state.fileName}'),
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              if (state is DownloadError) {
                // Only show if no dialog is showing the error
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${state.message}'),
                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          // Convert completed
          BlocListener<ConvertBloc, ConvertState>(
            listener: (context, state) {
              if (state is ConvertCompleted) {
                context.read<LocalMediaBloc>().add(LoadLocalMediaEvent());
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✓ Convertido: ${state.fileName}'),
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          // History file saved → refresh local list + snackbar
          BlocListener<HistoryBloc, HistoryState>(
            listener: (context, state) {
              if (state is HistoryLoaded &&
                  state.lastSavedJobId != null) {
                context.read<LocalMediaBloc>().add(LoadLocalMediaEvent());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Archivo guardado en dispositivo'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              if (state is HistoryError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${state.message}'),
                    backgroundColor:
                        Theme.of(context).colorScheme.errorContainer,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Media Manager'),
            actions: [
              const ServerStatusBadge(),
              // Retry button when server is not running
              BlocBuilder<ServerBloc, ServerBlocState>(
                builder: (context, state) {
                  if (state is ServerNotFound || state is ServerFailed) {
                    return IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Reintentar conexión',
                      onPressed: () =>
                          context.read<ServerBloc>().add(CheckServerEvent()),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.download_done_outlined), text: 'Descargas'),
                Tab(icon: Icon(Icons.history), text: 'Historial'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              _DownloadsTab(),
              _HistoryTab(),
            ],
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'convert_fab',
                tooltip: 'Convertir video',
                onPressed: () => _showConvertDialog(context),
                child: const Icon(Icons.transform),
              ),
              const SizedBox(height: 10),
              FloatingActionButton.extended(
                heroTag: 'download_fab',
                onPressed: () => _showDownloadDialog(context),
                icon: const Icon(Icons.download),
                label: const Text('Descargar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDownloadDialog(BuildContext context) {
    context.read<DownloadBloc>().add(ResetDownloadEvent());
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<DownloadBloc>(),
        child: const DownloadManagerDialog(),
      ),
    );
  }

  void _showConvertDialog(BuildContext context) {
    context.read<ConvertBloc>().add(ResetConvertEvent());
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<ConvertBloc>(),
        child: const ConvertManagerDialog(),
      ),
    );
  }
}

// ─── Downloads Tab ────────────────────────────────────────────────────────────

class _DownloadsTab extends StatelessWidget {
  const _DownloadsTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocalMediaBloc, LocalMediaState>(
      builder: (context, state) {
        if (state is LocalMediaLoading || state is LocalMediaInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is LocalMediaError) {
          return _ErrorView(
            message: state.message,
            onRetry: () =>
                context.read<LocalMediaBloc>().add(LoadLocalMediaEvent()),
          );
        }
        if (state is LocalMediaLoaded) {
          if (state.entries.isEmpty) {
            return _EmptyView(
              icon: Icons.download_done_outlined,
              title: 'Sin descargas',
              subtitle:
                  'Usa el botón "Descargar" para añadir videos a tu dispositivo.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                context.read<LocalMediaBloc>().add(LoadLocalMediaEvent()),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: state.entries.length,
              itemBuilder: (context, i) {
                final entry = state.entries[i];
                return MediaTile(
                  entry: entry,
                  onDelete: () => context.read<LocalMediaBloc>().add(
                        DeleteLocalMediaEvent(
                          jobId: entry.jobId,
                          localPath: entry.localPath,
                        ),
                      ),
                );
              },
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// ─── History Tab ──────────────────────────────────────────────────────────────

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<HistoryBloc>().add(LoadHistoryEvent());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<HistoryBloc, HistoryState>(
      builder: (context, state) {
        if (state is HistoryInitial || state is HistoryLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is HistoryError) {
          return _ErrorView(
            message: state.message,
            onRetry: () =>
                context.read<HistoryBloc>().add(LoadHistoryEvent()),
          );
        }
        if (state is HistoryLoaded) {
          if (state.data.history.isEmpty) {
            return _EmptyView(
              icon: Icons.history,
              title: 'Sin historial',
              subtitle: 'Aquí aparecerán tus descargas y conversiones.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                context.read<HistoryBloc>().add(LoadHistoryEvent()),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: state.data.history.length,
              itemBuilder: (context, i) {
                final item = state.data.history[i];
                return HistoryTile(
                  item: item,
                  isDownloading: state.downloadingIds.contains(item.jobId),
                  onDownload: () =>
                      context.read<HistoryBloc>().add(
                            DownloadHistoryFileEvent(
                              jobId: item.jobId,
                              fileName: item.fileName,
                            ),
                          ),
                  onDelete: () => _confirmDelete(context, item.jobId, item.title),
                );
              },
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  void _confirmDelete(BuildContext context, String jobId, String title) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar del historial'),
        content: Text('¿Eliminar "$title" del historial del servidor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              context
                  .read<HistoryBloc>()
                  .add(DeleteHistoryEntryEvent(jobId));
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No se pudo conectar',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
