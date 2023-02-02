import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class PageManager {
  final buttonNotifier = ValueNotifier<ButtonState>(ButtonState.paused);

  static const liveKirtan = 'https://live.sgpc.net:8443/;nocache=889869audio_file.mp3';
  static const mukhwak = 'https://old.sgpc.net/hukumnama/jpeg%20hukamnama/hukamnama.mp3';
  static const mukhwakKatha = 'https://old.sgpc.net/hukumnama/jpeg hukamnama/katha.mp3';

  late ConcatenatingAudioSource _playlist;

  // Define the playlist
  void _setInitialPlaylist() async {
    
    _playlist = ConcatenatingAudioSource(children: [
      AudioSource.uri(Uri.parse(liveKirtan)),
      AudioSource.uri(Uri.parse(mukhwak)),
      AudioSource.uri(Uri.parse(mukhwakKatha)),
    ]);
    await _audioPlayer.setAudioSource(_playlist);
  }

  late AudioPlayer _audioPlayer;

  PageManager(){
    _init();
  }

  void _init() async {
    _audioPlayer = AudioPlayer();
    _setInitialPlaylist();
    _listenForChangesInPlayerState();

    _audioPlayer.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;
      if (processingState == ProcessingState.loading || processingState == ProcessingState.buffering){
        buttonNotifier.value = ButtonState.loading;
      }
      else if (!isPlaying){
        buttonNotifier.value = ButtonState.paused;
      }
      else {
        buttonNotifier.value = ButtonState.playing;
      }
    });
  }

  void _listenForChangesInPlayerState() {
    _audioPlayer.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final processingState = playerState.processingState;
      if (processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering) {
        buttonNotifier.value = ButtonState.loading;
      } else if (!isPlaying) {
        buttonNotifier.value = ButtonState.paused;
      } else if (processingState != ProcessingState.completed) {
        buttonNotifier.value = ButtonState.playing;
      }
    });
  }

  void play(int index) async {


    _audioPlayer.setAudioSource(_playlist, initialIndex: index);
    await _audioPlayer.play();
  }

  void pause(){
    _audioPlayer.pause();
  }

  void dispose(){
    _audioPlayer.dispose();
  }

}

enum ButtonState {
  paused, playing, loading
}

