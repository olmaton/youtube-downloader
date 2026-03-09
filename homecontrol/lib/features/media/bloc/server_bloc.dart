import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/server_manager.dart';

// ─── Events ───────────────────────────────────────────────────────────────────

abstract class ServerEvent extends Equatable {
  const ServerEvent();
  @override
  List<Object?> get props => [];
}

class CheckServerEvent extends ServerEvent {}

// ─── States ───────────────────────────────────────────────────────────────────

abstract class ServerBlocState extends Equatable {
  const ServerBlocState();
  @override
  List<Object?> get props => [];
}

class ServerChecking extends ServerBlocState {}

class ServerStarting extends ServerBlocState {}

class ServerRunning extends ServerBlocState {}

class ServerNotFound extends ServerBlocState {}

class ServerFailed extends ServerBlocState {}

// ─── BLoC ─────────────────────────────────────────────────────────────────────

class ServerBloc extends Bloc<ServerEvent, ServerBlocState> {
  final ServerManager _manager;

  ServerBloc(this._manager) : super(ServerChecking()) {
    on<CheckServerEvent>(_onCheck);
  }

  Future<void> _onCheck(
      CheckServerEvent event, Emitter<ServerBlocState> emit) async {
    emit(ServerChecking());
    final pinged = await _manager.ping();
    if (pinged) {
      emit(ServerRunning());
      return;
    }

    final exePath = _manager.resolveExePath();
    if (exePath == null) {
      emit(ServerNotFound());
      return;
    }

    emit(ServerStarting());
    final result = await _manager.ensureRunning();
    switch (result) {
      case ServerState.running:
        emit(ServerRunning());
      case ServerState.error:
        emit(ServerFailed());
      default:
        emit(ServerFailed());
    }
  }

  @override
  Future<void> close() {
    _manager.dispose();
    return super.close();
  }
}
