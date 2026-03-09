class LocalMediaEntry {
  final String jobId;
  final String type; // download | convert
  final String title;
  final String fileName;
  final String format;
  final String? quality;
  final String completedAt;
  final String localPath;

  const LocalMediaEntry({
    required this.jobId,
    required this.type,
    required this.title,
    required this.fileName,
    required this.format,
    this.quality,
    required this.completedAt,
    required this.localPath,
  });

  Map<String, dynamic> toJson() => {
        'jobId': jobId,
        'type': type,
        'title': title,
        'fileName': fileName,
        'format': format,
        'quality': quality,
        'completedAt': completedAt,
        'localPath': localPath,
      };

  factory LocalMediaEntry.fromJson(Map<String, dynamic> json) =>
      LocalMediaEntry(
        jobId: json['jobId'] as String? ?? '',
        type: json['type'] as String? ?? '',
        title: json['title'] as String? ?? '',
        fileName: json['fileName'] as String? ?? '',
        format: json['format'] as String? ?? '',
        quality: json['quality'] as String?,
        completedAt: json['completedAt'] as String? ?? '',
        localPath: json['localPath'] as String? ?? '',
      );
}
