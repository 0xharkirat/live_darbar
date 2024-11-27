import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:live_darbar/src/models/audio_progress_state.dart';
import 'package:live_darbar/src/models/source.dart';
import 'package:rxdart/rxdart.dart';

class AudioController {
  final AudioPlayer _audioPlayer;
  AudioController(this._audioPlayer) {
    _init();
  }

  final _audioSource = <AudioSource>[
    AudioSource.uri(
      Uri.parse(kLiveKirtanUrlWeb),
      tag: MediaItem(
        id: '0',
        title: 'Live Kirtan',
        artUri: Uri.parse(
            'https://raw.githubusercontent.com/0xharkirat/live_darbar/refs/heads/audio-controller/assets/images/splash_logo.png'),
      ),
    ),
    AudioSource.uri(
      Uri.parse(kMukhWakUrl),
      tag: MediaItem(
        id: "1",
        title: 'Mukhwak',
        artUri: Uri.parse(
            'https://raw.githubusercontent.com/0xharkirat/live_darbar/refs/heads/audio-controller/assets/images/splash_logo.png'),
      ),
    ),
    AudioSource.uri(
      Uri.parse(kMukhwakKathaUrl),
      tag: MediaItem(
        id: "2",
        title: 'Mukhwak Katha',
        artUri: Uri.parse(
            'https://raw.githubusercontent.com/0xharkirat/live_darbar/refs/heads/audio-controller/assets/images/splash_logo.png'),
      ),
    ),
  ];

  List<AudioSource> get audioSource => _audioSource;

  Future<void> _init() async {
    await _audioPlayer.setAudioSource(_audioSource.first);
  }

  Future<void> play([int index = 0]) async {
    await _audioPlayer.setAudioSource(_audioSource[index]);
    _audioPlayer.play();
  }

  void resume() async {
    _audioPlayer.play();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    await _audioPlayer.seek(Duration.zero);
  }

  Future<void> seek(Duration duration) async {
    await _audioPlayer.seek(duration);
  }

  void dispose() {
    _audioPlayer.dispose();
  }

  Stream<AudioProgressState> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, AudioProgressState>(
          _audioPlayer.positionStream,
          _audioPlayer.bufferedPositionStream,
          _audioPlayer.durationStream, (position, bufferedPosition, duration) {
        return AudioProgressState(
            position: position,
            bufferedPosition: bufferedPosition,
            totalDuration: duration ?? Duration.zero);
      });

  Stream<PlayerState> get playStateStream => _audioPlayer.playerStateStream;

  Stream<int?> get currentIndexStream => _audioPlayer.currentIndexStream;

  Stream<SequenceState?> get sequenceStateStream =>
      _audioPlayer.sequenceStateStream;
}

final audioController = Provider.autoDispose<AudioController>((ref) {
  final audioPlayer = AudioPlayer();

  return AudioController(audioPlayer);
});

// Create a StreamProvider to expose the position data stream
final audioProgressProvider =
    StreamProvider.autoDispose<AudioProgressState>((ref) {
  final controller = ref.watch(audioController); // Access the AudioController
  return controller.positionDataStream; // Return the stream
});

// Create a StreamProvider to expose the player state stream
final playerStateProvider = StreamProvider.autoDispose<PlayerState>((ref) {
  final controller = ref.watch(audioController); // Access the AudioController
  return controller.playStateStream; // Return the stream
});

// Create a StreamProvider to expose the current index stream
final currentIndexProvider = StreamProvider.autoDispose<int?>((ref) {
  final controller = ref.watch(audioController); // Access the AudioController
  return controller.currentIndexStream; // Return the stream
});

// Create a StreamProvider to expose the sequence state stream
final sequenceStateProvider = StreamProvider.autoDispose<SequenceState?>((ref) {
  final controller = ref.watch(audioController); // Access the AudioController
  return controller.sequenceStateStream; // Return the stream
});
