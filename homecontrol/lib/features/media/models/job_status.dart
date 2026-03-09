class JobStatus {
  final String status; // pending | downloading | converting | done | error
  final double percent;
  final String speed;
  final String eta;
  final String totalSize;
  final String title;
  final String fileName;
  final String? error;

  const JobStatus({
    required this.status,
    required this.percent,
    required this.speed,
    required this.eta,
    required this.totalSize,
    required this.title,
    required this.fileName,
    this.error,
  });

  factory JobStatus.fromJson(Map<String, dynamic> json) => JobStatus(
        status: json['status'] as String? ?? 'pending',
        percent: (json['percent'] as num?)?.toDouble() ?? 0,
        speed: json['speed'] as String? ?? '',
        eta: json['eta'] as String? ?? '',
        totalSize: json['totalSize'] as String? ?? '',
        title: json['title'] as String? ?? '',
        fileName: json['fileName'] as String? ?? '',
        error: json['error'] as String?,
      );

  bool get isDone => status == 'done';
  bool get isError => status == 'error';
  bool get isConverting => status == 'converting';

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
