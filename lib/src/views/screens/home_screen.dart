import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Darbar',
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: StreamBuilder<AudioProgressState>(
            stream: ref.read(audioController).positionDataStream,
            builder: (context, snapshot) {
              final progress = snapshot.data;
              
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: ProgressBar(
                  progress: progress?.position ?? Duration.zero,
                  buffered: progress?.bufferedPosition ?? Duration.zero,
                  total: progress?.totalDuration ?? Duration.zero,
                  bufferedBarColor: Colors.red,
                  progressBarColor: Colors.blue,
                  onSeek: (value) => ref.read(audioController).seek(value),
                ),
              );
            }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (isPlaying) {
            await ref.read(audioController).pause();
            setState(() {
              isPlaying = false;
            });
          } else {
            await ref.read(audioController).play();
            setState(() {
              isPlaying = true;
            });
          }
        },
        child: Icon(!isPlaying ? Icons.play_arrow : Icons.pause),
      ),
    );
  }
}
