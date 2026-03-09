class HistoryItem {
  final String jobId;
  final String type; // download | convert
  final String title;
  final String fileName;
  final String format;
  final String? quality;
  final String completedAt;

  const HistoryItem({
    required this.jobId,
    required this.type,
    required this.title,
    required this.fileName,
    required this.format,
    this.quality,
    required this.completedAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        jobId: json['jobId'] as String? ?? '',
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        fileName: json['fileName'] as String? ?? '',
        format: json['format'] as String? ?? '',
        quality: json['quality'] as String?,
        completedAt: json['completedAt'] as String? ?? '',
      );
}

class HistoryResponse {
  final int total;
  final List<HistoryItem> history;

  const HistoryResponse({required this.total, required this.history});

  factory HistoryResponse.fromJson(Map<String, dynamic> json) =>
      HistoryResponse(
        total: json['total'] as int? ?? 0,
        history: (json['history'] as List?)
                ?.map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
