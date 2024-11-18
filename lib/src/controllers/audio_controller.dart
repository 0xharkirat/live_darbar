import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

const kLiveKirtanUrl =
    "https://s3.amazonaws.com/scifri-episodes/scifri20181123-episode.mp3";

const kLiveKirtanUrl2 =
    "http://live.sgpc.net:7339/;";

class AudioProgressState {
  final Duration position;
  final Duration bufferedPosition;
  final Duration totalDuration;

  AudioProgressState({
    required this.position,
    required this.bufferedPosition,
    required this.totalDuration,
  });
}

class AudioController {
  final AudioPlayer _audioPlayer;
  static const MethodChannel _channel = MethodChannel('com.example.live_darbar/audio');
  AudioController(this._audioPlayer) {
    _init();
    _setupMethodChannel();
  }

  Future<void> _setupMethodChannel() async {
    // Listen for method calls from the native side
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'playLiveDarbar') {
        // Example method to play audio from a native trigger
        await play();
      } else if (call.method == 'pauseLiveDarbar') {
        // Example method to pause audio
        await pause();
      } else if (call.method == 'stopLiveDarbar') {
        // Example method to stop audio
        await stop();
      }
    });
  }

  Future<void> _init() async {
    await _audioPlayer.setUrl(kLiveKirtanUrl2);
  }

  Future<void> play() async {
    _audioPlayer.play();
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }

   Stream<AudioProgressState> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, AudioProgressState>(
          _audioPlayer.positionStream,
          _audioPlayer.bufferedPositionStream,
          _audioPlayer.durationStream,
          (position, bufferedPosition, duration) {
            
            return AudioProgressState(
                position: position,
                bufferedPosition: bufferedPosition,
                totalDuration: duration ?? Duration.zero);
          });

  Future<void> seek(Duration duration) async {
    await _audioPlayer.seek(duration);
  }
}

final audioController = Provider<AudioController>((ref) {
  final audioPlayer = AudioPlayer();
  
  return AudioController(audioPlayer);
});

// Create a StreamProvider to expose the position data stream
final audioProgressProvider = StreamProvider<AudioProgressState>((ref) {
  final controller = ref.watch(audioController); // Access the AudioController
  return controller.positionDataStream; // Return the stream
});

