
import 'package:live_darbar/logics/page_manager.dart';
import 'package:audio_service/audio_service.dart';
import 'audio_handler.dart';

import 'playlist_repository.dart';
import 'package:get_it/get_it.dart';

GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {

  getIt.registerSingleton<AudioHandler>(await initAudioService());

  // services
  getIt.registerLazySingleton<PlaylistRepository>(() => DemoPlaylist());

  // page state
  getIt.registerLazySingleton<PageManager>(() => PageManager());
}