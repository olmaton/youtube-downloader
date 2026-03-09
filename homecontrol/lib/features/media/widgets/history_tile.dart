import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/history_item.dart';

class HistoryTile extends StatelessWidget {
  final HistoryItem item;
  final bool isDownloading;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const HistoryTile({
    super.key,
    required this.item,
    required this.isDownloading,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConvert = item.type == 'convert';
    final isAudio = item.format == 'mp3';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isConvert
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isAudio
                ? Icons.music_note
                : isConvert
                    ? Icons.transform
                    : Icons.video_file,
            color: isConvert
                ? theme.colorScheme.onSecondaryContainer
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          item.title.isNotEmpty ? item.title : item.fileName,
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
                  isConvert ? 'Conversión' : 'Descarga',
                  isConvert
                      ? theme.colorScheme.secondaryContainer
                      : theme.colorScheme.primaryContainer,
                  isConvert
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 6),
                _chip(
                  context,
                  item.format.toUpperCase(),
                  theme.colorScheme.surfaceContainerHighest,
                  theme.colorScheme.onSurface,
                ),
                if (item.quality != null && item.quality!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _chip(
                    context,
                    item.quality!,
                    theme.colorScheme.tertiaryContainer,
                    theme.colorScheme.onTertiaryContainer,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(item.completedAt),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDownloading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: 'Guardar en dispositivo',
                onPressed: onDownload,
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar del historial',
              color: theme.colorScheme.error,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm')
          .format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }
}
