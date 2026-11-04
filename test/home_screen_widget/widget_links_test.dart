import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/home_screen_widget/widget_links.dart';
import 'package:live_darbar/src/home_screen_widget/widget_playback.dart';

void main() {
  group('the widget links', () {
    test('are read from the exact strings the Swift widget writes', () {
      expect(
        widgetLinkFrom(Uri.parse('livedarbar://widget/live?homeWidget')),
        WidgetLink.live,
      );
      expect(
        widgetLinkFrom(Uri.parse('livedarbar://widget/hukamnama?homeWidget')),
        WidgetLink.hukamnama,
      );
      expect(
        widgetLinkFrom(Uri.parse('livedarbar://widget/open?homeWidget')),
        WidgetLink.open,
      );
    });

    test('ignore any other link', () {
      for (final link in [
        null,
        'https://darbar.live/widget/live',
        'livedarbar://widget/katha?homeWidget',
        'livedarbar://other/live?homeWidget',
        'livedarbar://widget/live/extra?homeWidget',
        'livedarbar://widget?homeWidget',
      ]) {
        expect(
          widgetLinkFrom(link == null ? null : Uri.parse(link)),
          isNull,
          reason: '$link',
        );
      }
    });
  });

  group('a tap on Live Kirtan', () {
    test('plays when live is off', () {
      for (final now in [
        WidgetPlayback.idle,
        const WidgetPlayback(WidgetPlayState.paused, WidgetSource.live),
        const WidgetPlayback(WidgetPlayState.playing, WidgetSource.hukamnama),
        const WidgetPlayback(WidgetPlayState.loading, WidgetSource.katha),
      ]) {
        expect(widgetTapFor(WidgetLink.live, now), WidgetTap.playLive,
            reason: '$now');
      }
    });

    test('stops live that plays or is still opening', () {
      for (final state in [WidgetPlayState.playing, WidgetPlayState.loading]) {
        expect(
          widgetTapFor(WidgetLink.live, WidgetPlayback(state, WidgetSource.live)),
          WidgetTap.stop,
        );
      }
    });
  });

  group('a tap on Hukamnama', () {
    test('plays or resumes when the Hukamnama is off', () {
      for (final now in [
        WidgetPlayback.idle,
        const WidgetPlayback(WidgetPlayState.paused, WidgetSource.hukamnama),
        const WidgetPlayback(WidgetPlayState.playing, WidgetSource.live),
      ]) {
        expect(widgetTapFor(WidgetLink.hukamnama, now), WidgetTap.playHukamnama,
            reason: '$now');
      }
    });

    test('pauses a Hukamnama that plays or is still opening', () {
      for (final state in [WidgetPlayState.playing, WidgetPlayState.loading]) {
        expect(
          widgetTapFor(
            WidgetLink.hukamnama,
            WidgetPlayback(state, WidgetSource.hukamnama),
          ),
          WidgetTap.pause,
        );
      }
    });
  });

  test('a tap away from the buttons opens the reader', () {
    expect(
      widgetTapFor(
        WidgetLink.open,
        const WidgetPlayback(WidgetPlayState.playing, WidgetSource.live),
      ),
      WidgetTap.openReader,
    );
  });
}
