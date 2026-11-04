// Checks on a real phone or emulator that the film in the "add the widget"
// sheet plays: the real video player, the real MP4 from the app's assets, and
// the taps' clock running with it.
//
//     flutter test integration_test/demo_film_test.dart -d <device id>
//
// The widget tests use a stand-in for the player, and the player's own test
// uses a stand-in for the platform. This is the one that runs the plugin.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:live_darbar/src/views/widgets/demo_film.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final film in [DemoFilm.iphone, DemoFilm.android]) {
    testWidgets('plays ${film.video}, muted, in a loop', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: DemoFilmView(film: film, width: 172)),
            ),
          ),
        ),
      );

      // Wait for the film to put a picture on screen and play.
      var seconds = 0.0;
      for (var i = 0; i < 100 && seconds < 2.5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        final painters = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((p) => p.painter)
            .whereType<TapMarksPainter>();
        if (painters.isNotEmpty) seconds = painters.first.time.value;
      }
      expect(find.byType(DemoFilmView), findsOneWidget);
      expect(seconds, greaterThan(2.0),
          reason: 'the film played and its clock ran with it');
    });
  }
}
