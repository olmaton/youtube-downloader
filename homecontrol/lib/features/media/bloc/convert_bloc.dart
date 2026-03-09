import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/media_api.dart';
import '../data/local_storage.dart';
import '../models/job_status.dart';
import '../models/local_media_entry.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class ConvertEvent extends Equatable {
  const ConvertEvent();
  @override
  List<Object?> get props => [];
}

class StartConvertEvent extends ConvertEvent {
  final String filePath;
  final String originalFileName;
  const StartConvertEvent({
    required this.filePath,
    required this.originalFileName,
  });
  @override
  List<Object?> get props => [filePath, originalFileName];
}

class ResetConvertEvent extends ConvertEvent {}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class ConvertState extends Equatable {
  const ConvertState();
  @override
  List<Object?> get props => [];
}

class ConvertInitial extends ConvertState {}

class ConvertInProgress extends ConvertState {
  final String jobId;
  final JobStatus? jobStatus;
  const ConvertInProgress({required this.jobId, this.jobStatus});
  @override
  List<Object?> get props => [jobId, jobStatus];
}

class ConvertSaving extends ConvertState {
  final String fileName;
  const ConvertSaving(this.fileName);
  @override
  List<Object?> get props => [fileName];
}

class ConvertCompleted extends ConvertState {
  final String localPath;
  final String fileName;
  final String title;
  const ConvertCompleted({
    required this.localPath,
    required this.fileName,
    required this.title,
  });
  @override
  List<Object?> get props => [localPath, fileName, title];
}

class ConvertError extends ConvertState {
  final String message;
  const ConvertError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class ConvertBloc extends Bloc<ConvertEvent, ConvertState> {
  final MediaApi _api;
  final LocalStorage _storage;

  ConvertBloc({required MediaApi api, required LocalStorage storage})
      : _api = api,
        _storage = storage,
        super(ConvertInitial()) {
    on<StartConvertEvent>(_onStart);
    on<ResetConvertEvent>((_, emit) => emit(ConvertInitial()));
  }

  Future<void> _onStart(
    StartConvertEvent event,
    Emitter<ConvertState> emit,
  ) async {
    try {
      final jobId = await _api.startConvert(event.filePath);
      emit(ConvertInProgress(jobId: jobId));

      while (!emit.isDone) {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        final status = await _api.getStatus(jobId);

        if (status.isDone) {
          emit(ConvertSaving(status.fileName));
          final localPath =
              await _api.downloadFile(jobId, status.fileName);
          await _storage.saveEntry(LocalMediaEntry(
            jobId: jobId,
            type: 'convert',
            title: status.title,
            fileName: status.fileName,
            format: 'mp4',
            completedAt: DateTime.now().toIso8601String(),
            localPath: localPath,
          ));
          emit(ConvertCompleted(
            localPath: localPath,
            fileName: status.fileName,
            title: status.title,
          ));
          break;
        } else if (status.isError) {
          emit(ConvertError(status.error ?? 'Error durante la conversión'));
          break;
        } else {
          emit(ConvertInProgress(jobId: jobId, jobStatus: status));
        }
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? (data['error'] as String?) : null;
      emit(ConvertError(msg ?? e.message ?? 'Error de red'));
    } catch (e) {
      emit(ConvertError(e.toString()));
    }
  }
}
