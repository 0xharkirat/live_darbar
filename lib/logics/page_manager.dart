import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:live_darbar/notifiers/progress_notifier.dart';

class PageManager {
  final buttonNotifier = ValueNotifier<ButtonState>(ButtonState.paused);
  final currentSongTitleNotifier = ValueNotifier<String>('');
  final progressNotifier = ProgressNotifier();

  static const liveKirtan = 'http://live.sgpc.net:8080/;';
  static const mukhwak =
      'https://old.sgpc.net/hukumnama/jpeg%20hukamnama/hukamnama.mp3';
  static const mukhwakKatha =
      'https://old.sgpc.net/hukumnama/jpeg hukamnama/katha.mp3';

  final _playlist = [
    AudioSource.uri(
      Uri.parse(liveKirtan),
      tag: MediaItem(
        id: '${_nextMediaId++}',
        title: 'Live Kirtan',
      ),
    ),
    AudioSource.uri(
      Uri.parse(mukhwak),
      tag: MediaItem(
        id: '${_nextMediaId++}',
        title: 'Mukhwak',
      ),
    ),
    AudioSource.uri(
      Uri.parse(mukhwakKatha),
      tag: MediaItem(
        id: '${_nextMediaId++}',
        title: 'Mukhwak Katha',
      ),
    ),
  ];

  // Define the playlist
  void _setInitialPlaylist() async {
    await _audioPlayer.setAudioSource(_playlist[0], preload: true);
  }

  late AudioPlayer _audioPlayer;
  static int _nextMediaId = 0;

  PageManager() {
    _init();
  }

  void _init() async {
    _audioPlayer = AudioPlayer();
    _setInitialPlaylist();
    _listenForChangesInPlayerPosition();
    _listenForChangesInBufferedPosition();
    _listenForChangesInTotalDuration();
    _listenForChangesInSequenceState();
    // _listenForChangesInPlayerState();
    // _listenForChangesInCurrentSong();
  }

  void _listenForChangesInPlayerPosition() {
    _audioPlayer.positionStream.listen((position) {
      final oldState = progressNotifier.value;
      progressNotifier.value = ProgressBarState(
        current: position,
        buffered: oldState.buffered,
        total: oldState.total,
      );
    });
  }

  void _listenForChangesInBufferedPosition() {
    _audioPlayer.bufferedPositionStream.listen((bufferedPosition) {
      final oldState = progressNotifier.value;
      progressNotifier.value = ProgressBarState(
        current: oldState.current,
        buffered: bufferedPosition,
        total: oldState.total,
      );
    });
  }

  void _listenForChangesInTotalDuration() {
    _audioPlayer.durationStream.listen((totalDuration) {
      final oldState = progressNotifier.value;
      progressNotifier.value = ProgressBarState(
        current: oldState.current,
        buffered: oldState.buffered,
        total: totalDuration ?? Duration.zero,
      );
    });
  }

  void _listenForChangesInPlayerState() {
    _audioPlayer.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;

      final processingState = playerState.processingState;
      bool completed = false;

      if (processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering) {
        print('loading0.......');
        buttonNotifier.value = ButtonState.loading;
      } else if (!isPlaying) {
        if (!completed) {
          print('paused0..........');
          buttonNotifier.value = ButtonState.paused;
        }
        buttonNotifier.value = ButtonState.completed;
      } else if (processingState != ProcessingState.completed) {
        print('playing0......');
        buttonNotifier.value = ButtonState.playing;
      } else {
        // completed
        completed = true;
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
      }
    });
  }

  void _listenForChangesInSequenceState() {
    _audioPlayer.sequenceStateStream.listen((sequenceState) {
      if (sequenceState == null) return;
      final currentItem = sequenceState.currentSource!.tag as MediaItem;
      final title = currentItem.title;
      currentSongTitleNotifier.value = title;
    });
  }

  void play(int index) async {
    _audioPlayer.setAudioSource(_playlist[index]);
    _listenForChangesInPlayerState();

    await _audioPlayer.play();
  }

  void resume() async {
    await _audioPlayer.play();
  }

  void seek(Duration position) {
    _audioPlayer.seek(position);
  }

  int getIndex() {
    int selectedChannelIndex = 0;
    if (currentSongTitleNotifier.value != '') {
      if (currentSongTitleNotifier.value == 'Live Kirtan') {
        selectedChannelIndex = 0;
      } else if (currentSongTitleNotifier.value == 'Mukhwak') {
        selectedChannelIndex = 1;
      } else if (currentSongTitleNotifier.value == 'Mukhwak Katha') {
        selectedChannelIndex = 2;
      }
    }

    return selectedChannelIndex;
  }

  void pause() {
    _audioPlayer.pause();
  }

  void dispose() {
    _audioPlayer.dispose();
  }

  void stop() {
    _audioPlayer.stop();
  }
}

enum ButtonState {
  paused,
  playing,
  loading,
  completed,
}
