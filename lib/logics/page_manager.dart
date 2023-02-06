import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class PageManager {
  final buttonNotifier = ValueNotifier<ButtonState>(ButtonState.paused);
  final currentSongTitleNotifier = ValueNotifier<String>('');

  static const liveKirtan = 'https://live.sgpc.net:8443/;nocache=889869audio_file.mp3';
  static const mukhwak = 'https://old.sgpc.net/hukumnama/jpeg%20hukamnama/hukamnama.mp3';
  static const mukhwakKatha = 'https://old.sgpc.net/hukumnama/jpeg hukamnama/katha.mp3';

  late ConcatenatingAudioSource _playlist;

  // Define the playlist
  void _setInitialPlaylist() async {
    
    _playlist = ConcatenatingAudioSource(children: [
      AudioSource.uri(Uri.parse(liveKirtan), tag: 'Live Kirtan'),
      AudioSource.uri(Uri.parse(mukhwak), tag: 'Mukhwak'),
      AudioSource.uri(Uri.parse(mukhwakKatha), tag: 'Mukhwak Katha'),
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

    _listenForChangesInSequenceState();
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

  void _listenForChangesInSequenceState() {
    _audioPlayer.sequenceStateStream.listen((sequenceState) {
      if (sequenceState == null) return;
      final currentItem = sequenceState.currentSource;
      final title = currentItem?.tag as String?;
      currentSongTitleNotifier.value = title ?? '';
    });
  }


  void play(int index) async {


    _audioPlayer.setAudioSource(_playlist, initialIndex: index);
    _listenForChangesInPlayerState();

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

enum Channel {
  liveKirtan,
  mukhwak,
  mukhwakKatha
}

