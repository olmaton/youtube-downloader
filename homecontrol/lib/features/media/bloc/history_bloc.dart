import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/media_api.dart';
import '../data/local_storage.dart';
import '../models/history_item.dart';
import '../models/local_media_entry.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class HistoryEvent extends Equatable {
  const HistoryEvent();
  @override
  List<Object?> get props => [];
}

class LoadHistoryEvent extends HistoryEvent {}

class DownloadHistoryFileEvent extends HistoryEvent {
  final String jobId;
  final String fileName;
  const DownloadHistoryFileEvent({required this.jobId, required this.fileName});
  @override
  List<Object?> get props => [jobId, fileName];
}

class DeleteHistoryEntryEvent extends HistoryEvent {
  final String jobId;
  const DeleteHistoryEntryEvent(this.jobId);
  @override
  List<Object?> get props => [jobId];
}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class HistoryState extends Equatable {
  const HistoryState();
  @override
  List<Object?> get props => [];
}

class HistoryInitial extends HistoryState {}

class HistoryLoading extends HistoryState {}

class HistoryLoaded extends HistoryState {
  final HistoryResponse data;
  final Set<String> downloadingIds;
  final String? lastSavedJobId;

  const HistoryLoaded(
    this.data, {
    this.downloadingIds = const {},
    this.lastSavedJobId,
  });

  HistoryLoaded copyWith({
    HistoryResponse? data,
    Set<String>? downloadingIds,
    String? lastSavedJobId,
  }) =>
      HistoryLoaded(
        data ?? this.data,
        downloadingIds: downloadingIds ?? this.downloadingIds,
        lastSavedJobId: lastSavedJobId,
      );

  @override
  List<Object?> get props => [data, downloadingIds, lastSavedJobId];
}

class HistoryError extends HistoryState {
  final String message;
  const HistoryError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final MediaApi _api;
  final LocalStorage _storage;

  HistoryBloc({required MediaApi api, required LocalStorage storage})
      : _api = api,
        _storage = storage,
        super(HistoryInitial()) {
    on<LoadHistoryEvent>(_onLoad);
    on<DownloadHistoryFileEvent>(_onDownloadFile);
    on<DeleteHistoryEntryEvent>(_onDelete);
  }

  Future<void> _onLoad(
      LoadHistoryEvent event, Emitter<HistoryState> emit) async {
    emit(HistoryLoading());
    try {
      final data = await _api.getHistory();
      emit(HistoryLoaded(data));
    } on DioException catch (e) {
      emit(HistoryError(e.message ?? 'Error al cargar historial'));
    } catch (e) {
      emit(HistoryError(e.toString()));
    }
  }

  Future<void> _onDownloadFile(
    DownloadHistoryFileEvent event,
    Emitter<HistoryState> emit,
  ) async {
    final current = state;
    if (current is! HistoryLoaded) return;

    final downloading = {...current.downloadingIds, event.jobId};
    emit(current.copyWith(downloadingIds: downloading));

    try {
      final localPath = await _api.downloadFile(event.jobId, event.fileName);
      final item =
          current.data.history.firstWhere((h) => h.jobId == event.jobId);
      await _storage.saveEntry(LocalMediaEntry(
        jobId: item.jobId,
        type: item.type,
        title: item.title,
        fileName: item.fileName,
        format: item.format,
        quality: item.quality,
        completedAt: item.completedAt,
        localPath: localPath,
      ));
      final done = {...current.downloadingIds}..remove(event.jobId);
      emit(current.copyWith(
        downloadingIds: done,
        lastSavedJobId: event.jobId,
      ));
    } on DioException catch (e) {
      final done = {...current.downloadingIds}..remove(event.jobId);
      emit(HistoryLoaded(current.data, downloadingIds: done));
      emit(HistoryError(e.message ?? 'Error al descargar archivo'));
    } catch (e) {
      final done = {...current.downloadingIds}..remove(event.jobId);
      emit(HistoryLoaded(current.data, downloadingIds: done));
      emit(HistoryError(e.toString()));
    }
  }

  Future<void> _onDelete(
    DeleteHistoryEntryEvent event,
    Emitter<HistoryState> emit,
  ) async {
    try {
      await _api.deleteHistoryEntry(event.jobId);
      add(LoadHistoryEvent());
    } on DioException catch (e) {
      emit(HistoryError(e.message ?? 'Error al eliminar entrada'));
    } catch (e) {
      emit(HistoryError(e.toString()));
    }
  }
}
