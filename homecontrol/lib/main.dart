import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app.dart';
import 'core/dio_client.dart';
import 'core/server_manager.dart';
import 'features/media/data/local_storage.dart';
import 'features/media/data/media_api.dart';
import 'features/media/bloc/download_bloc.dart';
import 'features/media/bloc/convert_bloc.dart';
import 'features/media/bloc/history_bloc.dart';
import 'features/media/bloc/local_media_bloc.dart';
import 'features/media/bloc/server_bloc.dart';

void main() {
  runApp(const _Root());
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final dio = createDioClient();
    final api = MediaApi(dio);
    final storage = LocalStorage();
    final serverManager = ServerManager();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              ServerBloc(serverManager)..add(CheckServerEvent()),
        ),
        BlocProvider(
          create: (_) => DownloadBloc(api: api, storage: storage),
        ),
        BlocProvider(
          create: (_) => ConvertBloc(api: api, storage: storage),
        ),
        BlocProvider(
          create: (_) => HistoryBloc(api: api, storage: storage),
        ),
        BlocProvider(
          create: (_) =>
              LocalMediaBloc(storage: storage)..add(LoadLocalMediaEvent()),
        ),
      ],
      child: const App(),
    );
  }
}

