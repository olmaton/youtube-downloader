import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/history_item.dart';
import '../models/job_item.dart';
import '../models/job_status.dart';
import '../models/video_info.dart';

class MediaApi {
  final Dio _dio;

  MediaApi(this._dio);

  Future<VideoInfo> getVideoInfo(String url) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/info',
      queryParameters: {'url': url},
    );
    return VideoInfo.fromJson(res.data!);
  }

  Future<String> startDownload({
    required String url,
    required String format,
    String? quality,
    bool convert = false,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/download',
      data: {
        'url': url,
        'format': format,
        if (quality != null && quality.isNotEmpty) 'quality': quality,
        'convert': convert,
      },
    );
    return res.data!['jobId'] as String;
  }

  Future<String> startConvert(String filePath) async {
    final formData = FormData.fromMap({
      'video': await MultipartFile.fromFile(filePath),
    });
    final res = await _dio.post<Map<String, dynamic>>('/convert', data: formData);
    return res.data!['jobId'] as String;
  }

  Future<JobStatus> getStatus(String jobId) async {
    final res =
        await _dio.get<Map<String, dynamic>>('/status/$jobId');
    return JobStatus.fromJson(res.data!);
  }

  Future<String> downloadFile(
    String jobId,
    String fileName, {
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final saveDir =
        Directory('${dir.path}${Platform.pathSeparator}homecontrol${Platform.pathSeparator}downloads');
    if (!saveDir.existsSync()) {
      saveDir.createSync(recursive: true);
    }
    final savePath =
        '${saveDir.path}${Platform.pathSeparator}$fileName';
    await _dio.download(
      '/file/$jobId',
      savePath,
      onReceiveProgress: onProgress,
    );
    return savePath;
  }

  Future<HistoryResponse> getHistory() async {
    final res = await _dio.get<Map<String, dynamic>>('/history');
    return HistoryResponse.fromJson(res.data!);
  }

  Future<void> deleteHistoryEntry(String jobId) async {
    await _dio.delete('/history/$jobId');
  }

  Future<void> cancelJob(String jobId) async {
    await _dio.delete('/job/$jobId');
  }

  Future<JobsResponse> getJobs() async {
    final res = await _dio.get<Map<String, dynamic>>('/jobs');
    return JobsResponse.fromJson(res.data!);
  }
}
