import 'package:flutter/material.dart';
import '../models/job_item.dart';

class JobTile extends StatelessWidget {
  final JobItem job;
  final bool isCancelling;
  final VoidCallback? onCancel;

  const JobTile({
    super.key,
    required this.job,
    this.isCancelling = false,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.title.isNotEmpty ? job.title : job.fileName,
                    style: textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(job: job),
              ],
            ),
            const SizedBox(height: 6),
            // Job ID
            Text(
              'ID: ${job.jobId}',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.outline,
                fontFamily: 'monospace',
              ),
            ),
            // Progress bar for active jobs
            if (job.isActive) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: job.percent > 0 ? job.percent / 100 : null,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (job.percent > 0)
                    Text(
                      '${job.percent.toStringAsFixed(1)}%',
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (job.speed.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    _InfoChip(icon: Icons.speed, label: job.speed),
                  ],
                  if (job.eta.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _InfoChip(icon: Icons.timer_outlined, label: job.eta),
                  ],
                  if (job.totalSize.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _InfoChip(icon: Icons.storage_outlined, label: job.totalSize),
                  ],
                  const Spacer(),
                  // Cancel button
                  if (isCancelling)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined),
                      iconSize: 20,
                      tooltip: 'Cancelar',
                      color: Theme.of(context).colorScheme.error,
                      onPressed: onCancel,
                    ),
                ],
              ),
            ],
            // Error message
            if (job.isError && job.error != null) ...[
              const SizedBox(height: 6),
              Text(
                job.error!,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Done: show file name
            if (job.isDone && job.fileName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                job.fileName,
                style: textTheme.bodySmall?.copyWith(color: scheme.outline),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final JobItem job;
  const _StatusChip({required this.job});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Color bg;
    Color fg;
    IconData icon;

    if (job.isDone) {
      bg = Colors.green.withValues(alpha: 0.15);
      fg = Colors.green.shade700;
      icon = Icons.check_circle_outline;
    } else if (job.isError) {
      bg = scheme.errorContainer;
      fg = scheme.onErrorContainer;
      icon = Icons.error_outline;
    } else {
      bg = scheme.primaryContainer;
      fg = scheme.onPrimaryContainer;
      icon = Icons.sync;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            job.statusLabel,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }
}
