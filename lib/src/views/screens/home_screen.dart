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
    // Watch the audio progress state using the StreamProvider
    final progressStateAsync = ref.watch(audioProgressProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Live Darbar',
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: progressStateAsync.when(
          data: (progressState) {
            // print(
            //     "Position: ${progressState.position}, Buffered: ${progressState.bufferedPosition}, Duration: ${progressState.totalDuration ?? Duration.zero}");
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: ProgressBar(
                progress: progressState.position,
                buffered: progressState.bufferedPosition,
                total: progressState.totalDuration,
                bufferedBarColor: Colors.red,
                thumbRadius: 5.0,
                onSeek: (duration) {
                  // Seek to a new position using AudioController
                  ref.read(audioController).seek(duration);
                },
              ),
            );
          },
          loading: () => CircularProgressIndicator(),
          error: (error, stack) => Text('Error: $error'),
        ),
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
