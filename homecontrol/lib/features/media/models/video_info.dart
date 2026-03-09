class VideoInfo {
  final String title;
  final int duration;
  final String thumbnail;
  final List<String> formats;
  final List<String> qualities;

  const VideoInfo({
    required this.title,
    required this.duration,
    required this.thumbnail,
    required this.formats,
    required this.qualities,
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) => VideoInfo(
        title: json['title'] as String? ?? '',
        duration: json['duration'] as int? ?? 0,
        thumbnail: json['thumbnail'] as String? ?? '',
        formats: (json['formats'] as List?)?.cast<String>() ?? [],
        qualities: (json['qualities'] as List?)?.cast<String>() ?? [],
      );

  String get durationFormatted {
    final m = duration ~/ 60;
    final s = duration % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
