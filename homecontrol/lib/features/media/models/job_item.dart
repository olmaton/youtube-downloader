class JobItem {
  final String jobId;
  final String status; // pending | downloading | converting | done | error
  final double percent;
  final String speed;
  final String eta;
  final String totalSize;
  final String title;
  final String fileName;
  final String? error;

  const JobItem({
    required this.jobId,
    required this.status,
    required this.percent,
    required this.speed,
    required this.eta,
    required this.totalSize,
    required this.title,
    required this.fileName,
    this.error,
  });

  factory JobItem.fromJson(Map<String, dynamic> json) => JobItem(
        jobId: json['jobId'] as String? ?? '',
        status: json['status'] as String? ?? '',
        percent: (json['percent'] as num?)?.toDouble() ?? 0,
        speed: json['speed'] as String? ?? '',
        eta: json['eta'] as String? ?? '',
        totalSize: json['totalSize'] as String? ?? '',
        title: json['title'] as String? ?? '',
        fileName: json['fileName'] as String? ?? '',
        error: json['error'] as String?,
      );

  bool get isActive =>
      status == 'pending' || status == 'downloading' || status == 'converting';
  bool get isDone => status == 'done';
  bool get isError => status == 'error';

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'downloading':
        return 'Descargando';
      case 'converting':
        return 'Convirtiendo';
      case 'done':
        return 'Completado';
      case 'error':
        return 'Error';
      default:
        return status;
    }
  }
}

class JobsResponse {
  final int total;
  final List<JobItem> jobs;

  const JobsResponse({required this.total, required this.jobs});

  factory JobsResponse.fromJson(Map<String, dynamic> json) => JobsResponse(
        total: json['total'] as int? ?? 0,
        jobs: (json['jobs'] as List?)
                ?.map((e) => JobItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
