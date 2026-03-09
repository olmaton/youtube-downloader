import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../models/local_media_entry.dart';

class MediaTile extends StatelessWidget {
  final LocalMediaEntry entry;
  final VoidCallback onDelete;

  const MediaTile({
    super.key,
    required this.entry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAudio = entry.format == 'mp3';
    final isConvert = entry.type == 'convert';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isAudio
                ? Icons.music_note
                : isConvert
                    ? Icons.transform
                    : Icons.video_file,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          entry.title.isNotEmpty ? entry.title : entry.fileName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                _chip(
                  context,
                  entry.format.toUpperCase(),
                  theme.colorScheme.secondaryContainer,
                  theme.colorScheme.onSecondaryContainer,
                ),
                if (entry.quality != null &&
                    entry.quality!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _chip(
                    context,
                    entry.quality!,
                    theme.colorScheme.tertiaryContainer,
                    theme.colorScheme.onTertiaryContainer,
                  ),
                ],
                if (isConvert) ...[
                  const SizedBox(width: 6),
                  _chip(
                    context,
                    'Convertido',
                    theme.colorScheme.surfaceContainerHighest,
                    theme.colorScheme.onSurface,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(entry.completedAt),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Abrir archivo',
              onPressed: () => OpenFilex.open(entry.localPath),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar',
              color: theme.colorScheme.error,
              onPressed: () =>
                  _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
      BuildContext context, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: fg),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: Text(
            '¿Deseas eliminar "${entry.title.isNotEmpty ? entry.title : entry.fileName}" del dispositivo?'),
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
              onDelete();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
