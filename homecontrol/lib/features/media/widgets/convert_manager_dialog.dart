import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/convert_bloc.dart';
import 'progress_tracker.dart';

class ConvertManagerDialog extends StatefulWidget {
  const ConvertManagerDialog({super.key});

  @override
  State<ConvertManagerDialog> createState() => _ConvertManagerDialogState();
}

class _ConvertManagerDialogState extends State<ConvertManagerDialog> {
  String? _selectedFilePath;
  String? _selectedFileName;

  bool _isActiveState(ConvertState state) =>
      state is ConvertInProgress || state is ConvertSaving;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConvertBloc, ConvertState>(
      listener: (context, state) {
        if (state is ConvertCompleted) {
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

  Widget _buildContent(BuildContext context, ConvertState state) {
    if (state is ConvertInitial) {
      return _buildForm(context);
    }
    if (state is ConvertInProgress || state is ConvertSaving) {
      return _buildProgress(context, state);
    }
    if (state is ConvertError) {
      return _buildError(context, state);
    }
    return const SizedBox.shrink();
  }

  // ── Form ──────────────────────────────────────────────────────────────────

  Widget _buildForm(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Convertir video',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Convierte cualquier video a MP4 compatible (H.264 + AAC)',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 20),
        // File picker
        InkWell(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            decoration: BoxDecoration(
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedFilePath != null
                      ? Icons.video_file
                      : Icons.upload_file,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedFileName != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFileName!,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Toca para cambiar',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                          ],
                        )
                      : Text(
                          'Seleccionar archivo de video',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed:
                  _selectedFilePath != null ? () => _startConvert(context) : null,
              icon: const Icon(Icons.transform),
              label: const Text('Convertir'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _selectedFileName = result.files.single.name;
      });
    }
  }

  void _startConvert(BuildContext context) {
    if (_selectedFilePath == null) return;
    context.read<ConvertBloc>().add(StartConvertEvent(
          filePath: _selectedFilePath!,
          originalFileName: _selectedFileName ?? '',
        ));
  }

  // ── Progress ──────────────────────────────────────────────────────────────

  Widget _buildProgress(BuildContext context, ConvertState state) {
    ConvertInProgress? inProgress;
    ConvertSaving? saving;
    if (state is ConvertInProgress) inProgress = state;
    if (state is ConvertSaving) saving = state;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Convirtiendo...',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        ProgressTracker(
          jobId: inProgress?.jobId ?? '',
          status: inProgress?.jobStatus,
          savingFileName: saving?.fileName,
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

  Widget _buildError(BuildContext context, ConvertError state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Error',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.message,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
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
                context.read<ConvertBloc>().add(ResetConvertEvent());
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () =>
                  context.read<ConvertBloc>().add(ResetConvertEvent()),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ],
    );
  }
}
