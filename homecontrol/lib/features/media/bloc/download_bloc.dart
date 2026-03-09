import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/media_api.dart';
import '../data/local_storage.dart';
import '../models/job_status.dart';
import '../models/local_media_entry.dart';
import '../models/video_info.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class DownloadEvent extends Equatable {
  const DownloadEvent();
  @override
  List<Object?> get props => [];
}

class ValidateUrlEvent extends DownloadEvent {
  final String url;
  const ValidateUrlEvent(this.url);
  @override
  List<Object?> get props => [url];
}

class StartDownloadEvent extends DownloadEvent {
  final String url;
  final String format;
  final String? quality;
  final bool convert;
  const StartDownloadEvent({
    required this.url,
    required this.format,
    this.quality,
    this.convert = false,
  });
  @override
  List<Object?> get props => [url, format, quality, convert];
}

class ResetDownloadEvent extends DownloadEvent {}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class DownloadState extends Equatable {
  const DownloadState();
  @override
  List<Object?> get props => [];
}

class DownloadInitial extends DownloadState {}

class DownloadValidating extends DownloadState {}

class DownloadInfoLoaded extends DownloadState {
  final VideoInfo info;
  final String url;
  const DownloadInfoLoaded({required this.info, required this.url});
  @override
  List<Object?> get props => [info, url];
}

class DownloadStarting extends DownloadState {}

class DownloadInProgress extends DownloadState {
  final String jobId;
  final JobStatus? jobStatus;
  const DownloadInProgress({required this.jobId, this.jobStatus});
  @override
  List<Object?> get props => [jobId, jobStatus];
}

class DownloadSaving extends DownloadState {
  final String fileName;
  const DownloadSaving(this.fileName);
  @override
  List<Object?> get props => [fileName];
}

class DownloadCompleted extends DownloadState {
  final String localPath;
  final String fileName;
  final String title;
  const DownloadCompleted({
    required this.localPath,
    required this.fileName,
    required this.title,
  });
  @override
  List<Object?> get props => [localPath, fileName, title];
}

class DownloadError extends DownloadState {
  final String message;
  const DownloadError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class DownloadBloc extends Bloc<DownloadEvent, DownloadState> {
  final MediaApi _api;
  final LocalStorage _storage;

  DownloadBloc({required MediaApi api, required LocalStorage storage})
      : _api = api,
        _storage = storage,
        super(DownloadInitial()) {
    on<ValidateUrlEvent>(_onValidate);
    on<StartDownloadEvent>(_onStart);
    on<ResetDownloadEvent>((_, emit) => emit(DownloadInitial()));
  }

  Future<void> _onValidate(
    ValidateUrlEvent event,
    Emitter<DownloadState> emit,
  ) async {
    emit(DownloadValidating());
    try {
      final info = await _api.getVideoInfo(event.url);
      emit(DownloadInfoLoaded(info: info, url: event.url));
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? (data['error'] as String?) : null;
      emit(DownloadError(msg ?? e.message ?? 'Error al validar la URL'));
    } catch (e) {
      emit(DownloadError(e.toString()));
    }
  }

  Future<void> _onStart(
    StartDownloadEvent event,
    Emitter<DownloadState> emit,
  ) async {
    emit(DownloadStarting());
    try {
      final jobId = await _api.startDownload(
        url: event.url,
        format: event.format,
        quality: event.quality,
        convert: event.convert,
      );
      emit(DownloadInProgress(jobId: jobId));

      while (!emit.isDone) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        final status = await _api.getStatus(jobId);

        if (status.isDone) {
          emit(DownloadSaving(status.fileName));
          final localPath =
              await _api.downloadFile(jobId, status.fileName);
          await _storage.saveEntry(LocalMediaEntry(
            jobId: jobId,
            type: 'download',
            title: status.title,
            fileName: status.fileName,
            format: event.format,
            quality: event.quality,
            completedAt: DateTime.now().toIso8601String(),
            localPath: localPath,
          ));
          emit(DownloadCompleted(
            localPath: localPath,
            fileName: status.fileName,
            title: status.title,
          ));
          break;
        } else if (status.isError) {
          emit(DownloadError(status.error ?? 'Error durante la descarga'));
          break;
        } else {
          emit(DownloadInProgress(jobId: jobId, jobStatus: status));
        }
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? (data['error'] as String?) : null;
      emit(DownloadError(msg ?? e.message ?? 'Error de red'));
    } catch (e) {
      emit(DownloadError(e.toString()));
    }
  }
}
