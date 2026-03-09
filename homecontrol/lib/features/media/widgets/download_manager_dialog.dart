import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/download_bloc.dart';
import '../models/job_status.dart';
import 'progress_tracker.dart';

class DownloadManagerDialog extends StatefulWidget {
  const DownloadManagerDialog({super.key});

  @override
  State<DownloadManagerDialog> createState() => _DownloadManagerDialogState();
}

class _DownloadManagerDialogState extends State<DownloadManagerDialog> {
  final _urlController = TextEditingController();
  String _selectedFormat = 'mp4';
  String? _selectedQuality = '720p';
  bool _convert = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  bool _isActiveState(DownloadState state) =>
      state is DownloadValidating ||
      state is DownloadStarting ||
      state is DownloadInProgress ||
      state is DownloadSaving;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DownloadBloc, DownloadState>(
      listener: (context, state) {
        if (state is DownloadCompleted) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        return PopScope(
          canPop: !_isActiveState(state),
          child: Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildContent(context, state),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, DownloadState state) {
    if (state is DownloadInitial || state is DownloadValidating) {
      return _buildUrlInput(context, state);
    }
    if (state is DownloadInfoLoaded) {
      return _buildVideoForm(context, state);
    }
    if (state is DownloadStarting ||
        state is DownloadInProgress ||
        state is DownloadSaving) {
      return _buildProgress(context, state);
    }
    if (state is DownloadError) {
      return _buildError(context, state);
    }
    return const SizedBox.shrink();
  }

  // ── Step 1: URL Input ──────────────────────────────────────────────────────

  Widget _buildUrlInput(BuildContext context, DownloadState state) {
    final isLoading = state is DownloadValidating;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dialogTitle('Descargar video'),
        const SizedBox(height: 20),
        TextField(
          controller: _urlController,
          autofocus: true,
          enabled: !isLoading,
          decoration: const InputDecoration(
            labelText: 'URL de YouTube',
            hintText: 'https://www.youtube.com/watch?v=...',
            prefixIcon: Icon(Icons.link),
          ),
          onSubmitted: (_) => _validate(context),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed:
                  isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: isLoading ? null : () => _validate(context),
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: const Text('Validar'),
            ),
          ],
        ),
      ],
    );
  }

  void _validate(BuildContext context) {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    context.read<DownloadBloc>().add(ValidateUrlEvent(url));
  }

  // ── Step 2: Video Info + Form ──────────────────────────────────────────────

  Widget _buildVideoForm(BuildContext context, DownloadInfoLoaded state) {
    final info = state.info;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dialogTitle('Datos del video'),
          const SizedBox(height: 16),
          // Thumbnail
          if (info.thumbnail.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: info.thumbnail,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 160,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 80,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            info.title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Duración: ${info.durationFormatted}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 20),
          // Format dropdown
          DropdownButtonFormField<String>(
            value: _selectedFormat,
            decoration: const InputDecoration(
              labelText: 'Formato',
              prefixIcon: Icon(Icons.video_file),
            ),
            items: info.formats
                .map((f) => DropdownMenuItem(value: f, child: Text(f.toUpperCase())))
                .toList(),
            onChanged: (v) => setState(() {
              _selectedFormat = v!;
              if (_selectedFormat != 'mp4') _selectedQuality = null;
            }),
          ),
          const SizedBox(height: 12),
          // Quality dropdown (mp4 only)
          if (_selectedFormat == 'mp4')
            DropdownButtonFormField<String>(
              value: _selectedQuality,
              decoration: const InputDecoration(
                labelText: 'Calidad',
                prefixIcon: Icon(Icons.hd),
              ),
              items: info.qualities
                  .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedQuality = v),
            ),
          if (_selectedFormat == 'mp4') const SizedBox(height: 12),
          // Convert toggle (mp4 only)
          if (_selectedFormat == 'mp4')
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _convert,
              onChanged: (v) => setState(() => _convert = v),
              title: const Text('Convertir a MP4 compatible'),
              subtitle: const Text('H.264 + AAC para máxima compatibilidad'),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => context
                    .read<DownloadBloc>()
                    .add(ResetDownloadEvent()),
                child: const Text('Atrás'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _startDownload(context, state),
                icon: const Icon(Icons.download),
                label: const Text('Descargar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _startDownload(BuildContext context, DownloadInfoLoaded state) {
    context.read<DownloadBloc>().add(StartDownloadEvent(
          url: state.url,
          format: _selectedFormat,
          quality: _selectedFormat == 'mp4' ? _selectedQuality : null,
          convert: _selectedFormat == 'mp4' ? _convert : false,
        ));
  }

  // ── Step 3: Progress ──────────────────────────────────────────────────────

  Widget _buildProgress(BuildContext context, DownloadState state) {
    JobStatus? status;
    String? savingFileName;
    if (state is DownloadInProgress) status = state.jobStatus;
    if (state is DownloadSaving) savingFileName = state.fileName;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dialogTitle('Descargando...'),
        const SizedBox(height: 20),
        ProgressTracker(
          jobId: state is DownloadInProgress ? state.jobId : '',
          status: status,
          savingFileName: savingFileName,
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar (continúa en fondo)'),
          ),
        ),
      ],
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError(BuildContext context, DownloadError state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dialogTitle('Error'),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.message,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                context.read<DownloadBloc>().add(ResetDownloadEvent());
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () =>
                  context.read<DownloadBloc>().add(ResetDownloadEvent()),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dialogTitle(String title) => Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      );
}
