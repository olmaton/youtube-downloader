import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'constants.dart';

final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

Dio createDioClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 15),
      sendTimeout: const Duration(minutes: 10),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        _logger.d('→ ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.d('← ${response.statusCode} ${response.realUri.path}');
        handler.next(response);
      },
      onError: (error, handler) {
        _logger.e('✗ ${error.message}', error: error);
        handler.next(error);
      },
    ),
  );

  return dio;
}
