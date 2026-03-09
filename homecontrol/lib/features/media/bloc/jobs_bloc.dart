import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../data/media_api.dart';
import '../models/job_item.dart';

// ─── Events ──────────────────────────────────────────────────────────────────

abstract class JobsEvent extends Equatable {
  const JobsEvent();
  @override
  List<Object?> get props => [];
}

class LoadJobsEvent extends JobsEvent {
  const LoadJobsEvent();
}

class _PollJobsEvent extends JobsEvent {
  const _PollJobsEvent();
}

class CancelJobEvent extends JobsEvent {
  final String jobId;
  const CancelJobEvent(this.jobId);
  @override
  List<Object?> get props => [jobId];
}

class StopJobsPollingEvent extends JobsEvent {
  const StopJobsPollingEvent();
}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class JobsState extends Equatable {
  const JobsState();
  @override
  List<Object?> get props => [];
}

class JobsInitial extends JobsState {
  const JobsInitial();
}

class JobsLoading extends JobsState {
  const JobsLoading();
}

class JobsLoaded extends JobsState {
  final JobsResponse data;
  final Set<String> cancellingIds;
  final bool isPolling;

  const JobsLoaded({
    required this.data,
    this.cancellingIds = const {},
    this.isPolling = false,
  });

  JobsLoaded copyWith({
    JobsResponse? data,
    Set<String>? cancellingIds,
    bool? isPolling,
  }) =>
      JobsLoaded(
        data: data ?? this.data,
        cancellingIds: cancellingIds ?? this.cancellingIds,
        isPolling: isPolling ?? this.isPolling,
      );

  @override
  List<Object?> get props => [data, cancellingIds, isPolling];
}

class JobsError extends JobsState {
  final String message;
  const JobsError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class JobsBloc extends Bloc<JobsEvent, JobsState> {
  final MediaApi _api;
  Timer? _pollTimer;

  static const _pollInterval = Duration(seconds: 2);

  JobsBloc({required MediaApi api})
      : _api = api,
        super(const JobsInitial()) {
    on<LoadJobsEvent>(_onLoad);
    on<_PollJobsEvent>(_onPoll);
    on<CancelJobEvent>(_onCancel);
    on<StopJobsPollingEvent>(_onStop);
  }

  Future<void> _onLoad(LoadJobsEvent event, Emitter<JobsState> emit) async {
    emit(const JobsLoading());
    try {
      final data = await _api.getJobs();
      emit(JobsLoaded(data: data, isPolling: data.jobs.any((j) => j.isActive)));
      _restartPolling(data);
    } catch (e) {
      emit(JobsError(e.toString()));
    }
  }

  Future<void> _onPoll(_PollJobsEvent event, Emitter<JobsState> emit) async {
    try {
      final data = await _api.getJobs();
      final current = state;
      final cancellingIds =
          current is JobsLoaded ? current.cancellingIds : const <String>{};
      final hasActive = data.jobs.any((j) => j.isActive);
      emit(JobsLoaded(
        data: data,
        cancellingIds: cancellingIds,
        isPolling: hasActive,
      ));
      if (!hasActive) {
        _stopPolling();
      }
    } catch (_) {
      // Silently ignore poll errors to avoid flickering
    }
  }

  Future<void> _onCancel(CancelJobEvent event, Emitter<JobsState> emit) async {
    final current = state;
    if (current is JobsLoaded) {
      emit(current.copyWith(
        cancellingIds: {...current.cancellingIds, event.jobId},
      ));
      try {
        await _api.cancelJob(event.jobId);
        final data = await _api.getJobs();
        final updated = <String>{...current.cancellingIds}..remove(event.jobId);
        emit(JobsLoaded(
          data: data,
          cancellingIds: updated,
          isPolling: data.jobs.any((j) => j.isActive),
        ));
        _restartPolling(data);
      } catch (e) {
        final updated = <String>{...current.cancellingIds}..remove(event.jobId);
        emit(current.copyWith(cancellingIds: updated));
      }
    }
  }

  void _onStop(StopJobsPollingEvent event, Emitter<JobsState> emit) {
    _stopPolling();
  }

  void _restartPolling(JobsResponse data) {
    _stopPolling();
    if (data.jobs.any((j) => j.isActive)) {
      _pollTimer = Timer.periodic(_pollInterval, (_) {
        if (!isClosed) add(const _PollJobsEvent());
      });
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }
}
