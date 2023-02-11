import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:live_darbar/notifiers/progress_notifier.dart';
import 'package:audio_service/audio_service.dart';
import 'package:live_darbar/services/playlist_repository.dart';
import 'package:live_darbar/services/service_locator.dart';

class PageManager {

  final _audioHandler = getIt<AudioHandler>();

  final buttonNotifier = ValueNotifier<ButtonState>(ButtonState.paused);
  final currentSongTitleNotifier = ValueNotifier<String>('');
  final playlistNotifier = ValueNotifier<List<String>>([]);
  final progressNotifier = ProgressNotifier();


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
    await _audioPlayer.setAudioSource(_playlist, preload: true);
  }

  late AudioPlayer _audioPlayer;

  PageManager(){
    _init();
  }

  void _init() async {
    await _loadPlaylist();
    _listenToChangesInPlaylist();
    _audioPlayer = AudioPlayer();
    _setInitialPlaylist();
    _listenForChangesInPlayerPosition();
    _listenForChangesInBufferedPosition();
    _listenForChangesInTotalDuration();
    _listenForChangesInSequenceState();
  }

  Future<void> _loadPlaylist() async {
    final songRepository = getIt<PlaylistRepository>();
    final playlist = await songRepository.fetchInitialPlaylist();
    final mediaItems = playlist
        .map((song) => MediaItem(
      id: song['id'] ?? '',
      title: song['title'] ?? '',
      extras: {'url': song['url']},
    ))
        .toList();
    _audioHandler.addQueueItems(mediaItems);
  }


  void _listenToChangesInPlaylist() {
    _audioHandler.queue.listen((playlist) {
      if (playlist.isEmpty) return;
      final newList = playlist.map((item) => item.title).toList();
      playlistNotifier.value = newList;
    });
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

  void resume() async{
    await _audioPlayer.play();

  }
  void seek(Duration position) {
    _audioPlayer.seek(position);
  }

  int getIndex()  {
    int selectedChannelIndex = 0;
    if (currentSongTitleNotifier.value != '') {
      if (currentSongTitleNotifier.value == 'Live Kirtan') {
        selectedChannelIndex = 0;
      }
      else if (currentSongTitleNotifier.value == 'Mukhwak') {
        selectedChannelIndex = 1;
      }
      else if (currentSongTitleNotifier.value == 'Mukhwak Katha') {
        selectedChannelIndex = 2;
      }
    }

    return selectedChannelIndex;


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


