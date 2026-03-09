import 'package:flutter/material.dart';
import '../models/job_status.dart';

class ProgressTracker extends StatelessWidget {
  final String jobId;
  final JobStatus? status;
  final String? savingFileName;

  const ProgressTracker({
    super.key,
    required this.jobId,
    this.status,
    this.savingFileName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (savingFileName != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            'Guardando archivo...',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            savingFileName!,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    if (status == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            'Iniciando...',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    }

    final percent = status!.percent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              status!.statusLabel,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 10),
        if (status!.title.isNotEmpty)
          Text(
            status!.title,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (status!.speed.isNotEmpty) ...[
              Icon(Icons.speed, size: 14, color: theme.colorScheme.outline),
              const SizedBox(width: 4),
              Text(
                status!.speed,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(width: 12),
            ],
            if (status!.eta.isNotEmpty) ...[
              Icon(Icons.timer_outlined,
                  size: 14, color: theme.colorScheme.outline),
              const SizedBox(width: 4),
              Text(
                'ETA: ${status!.eta}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(width: 12),
            ],
            if (status!.totalSize.isNotEmpty) ...[
              Icon(Icons.folder_outlined,
                  size: 14, color: theme.colorScheme.outline),
              const SizedBox(width: 4),
              Text(
                status!.totalSize,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
