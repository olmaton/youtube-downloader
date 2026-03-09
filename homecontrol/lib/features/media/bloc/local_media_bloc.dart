import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/local_storage.dart';
import '../models/local_media_entry.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class LocalMediaEvent extends Equatable {
  const LocalMediaEvent();
  @override
  List<Object?> get props => [];
}

class LoadLocalMediaEvent extends LocalMediaEvent {}

class DeleteLocalMediaEvent extends LocalMediaEvent {
  final String jobId;
  final String localPath;
  const DeleteLocalMediaEvent({required this.jobId, required this.localPath});
  @override
  List<Object?> get props => [jobId, localPath];
}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class LocalMediaState extends Equatable {
  const LocalMediaState();
  @override
  List<Object?> get props => [];
}

class LocalMediaInitial extends LocalMediaState {}

class LocalMediaLoading extends LocalMediaState {}

class LocalMediaLoaded extends LocalMediaState {
  final List<LocalMediaEntry> entries;
  const LocalMediaLoaded(this.entries);
  @override
  List<Object?> get props => [entries];
}

class LocalMediaError extends LocalMediaState {
  final String message;
  const LocalMediaError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class LocalMediaBloc extends Bloc<LocalMediaEvent, LocalMediaState> {
  final LocalStorage _storage;

  LocalMediaBloc({required LocalStorage storage})
      : _storage = storage,
        super(LocalMediaInitial()) {
    on<LoadLocalMediaEvent>(_onLoad);
    on<DeleteLocalMediaEvent>(_onDelete);
  }

  Future<void> _onLoad(
      LoadLocalMediaEvent event, Emitter<LocalMediaState> emit) async {
    emit(LocalMediaLoading());
    try {
      final entries = await _storage.loadEntries();
      emit(LocalMediaLoaded(entries));
    } catch (e) {
      emit(LocalMediaError(e.toString()));
    }
  }

  Future<void> _onDelete(
      DeleteLocalMediaEvent event, Emitter<LocalMediaState> emit) async {
    try {
      final file = File(event.localPath);
      if (file.existsSync()) {
        file.deleteSync();
      }
      await _storage.deleteEntry(event.jobId);
      add(LoadLocalMediaEvent());
    } catch (e) {
      emit(LocalMediaError(e.toString()));
    }
  }
}
