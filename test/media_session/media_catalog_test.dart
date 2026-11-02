import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/media_session/media_catalog.dart';
import 'package:live_darbar/src/models/source_index.dart';

/// The browse tree that Android Auto and an assistant read.
void main() {
  group('MediaCatalog.items', () {
    test('lists live, Hukamnama and Katha, in that order', () {
      final items = MediaCatalog.items();
      expect(
        items.map((item) => item.title),
        ['Live Kirtan', 'Hukamnama', 'Katha'],
      );
      expect(items.map((item) => item.id), ['0', '1', '2']);
    });

    test('every item is playable and names the artist and the app', () {
      for (final item in MediaCatalog.items()) {
        expect(item.playable, isTrue, reason: item.title);
        expect(item.artist, 'Sri Harmandir Sahib, Amritsar', reason: item.title);
        expect(item.album, 'Live Darbar', reason: item.title);
      }
    });

    test('only live is marked as a live stream', () {
      final items = MediaCatalog.items();
      expect(items[kLiveIndex].isLive, isTrue);
      expect(items[kMukhwakIndex].isLive, isFalse);
      expect(items[kKathaIndex].isLive, isFalse);
    });

    test('each item carries its own painting', () {
      final art = {
        kLiveIndex: Uri.file('/files/artwork/0.jpg'),
        kMukhwakIndex: Uri.file('/files/artwork/1.jpg'),
        kKathaIndex: Uri.file('/files/artwork/2.jpg'),
      };
      final items = MediaCatalog.items(art);
      expect(items[0].artUri, art[kLiveIndex]);
      expect(items[1].artUri, art[kMukhwakIndex]);
      expect(items[2].artUri, art[kKathaIndex]);
    });

    test('a missing painting leaves the row without one', () {
      final items = MediaCatalog.items({kLiveIndex: Uri.file('/a.jpg')});
      expect(items[0].artUri, isNotNull);
      expect(items[1].artUri, isNull);
      expect(items[2].artUri, isNull);
    });
  });

  group('MediaCatalog.item', () {
    test('the id is the index, which is what the views read back', () {
      for (final index in kSourceIndexes) {
        expect(MediaCatalog.idFor(index), '$index');
        expect(MediaCatalog.item(index).id, '$index');
      }
    });

    test('a recording takes a duration and live never does', () {
      const length = Duration(minutes: 25);
      expect(
        MediaCatalog.item(kKathaIndex, duration: length).duration,
        length,
      );
      expect(MediaCatalog.item(kLiveIndex, duration: length).duration, isNull);
    });

    test('a source that does not exist is an error, not a blank row', () {
      expect(() => MediaCatalog.item(3), throwsArgumentError);
      expect(() => MediaCatalog.item(-1), throwsArgumentError);
    });
  });

  group('lookups', () {
    test('byId finds each item and nothing else', () {
      expect(MediaCatalog.byId('1')?.title, 'Hukamnama');
      expect(MediaCatalog.byId('2')?.title, 'Katha');
      expect(MediaCatalog.byId('root'), isNull);
      expect(MediaCatalog.byId(''), isNull);
      expect(MediaCatalog.byId('9'), isNull);
    });

    test('search returns the one item a keyword names', () {
      expect(MediaCatalog.search('katha').map((item) => item.id), ['2']);
      expect(MediaCatalog.search('mukh wak').map((item) => item.id), ['1']);
      expect(MediaCatalog.search('ਮੁੱਖ ਵਾਕ').map((item) => item.id), ['1']);
      expect(MediaCatalog.search('kirtan').map((item) => item.id), ['0']);
    });

    test('search carries the painting', () {
      final art = {kKathaIndex: Uri.parse('content://x.artwork/2.jpg')};
      expect(MediaCatalog.search('katha', art).single.artUri, art[kKathaIndex]);
    });

    test('search returns nothing when no keyword matches', () {
      expect(MediaCatalog.search('weather'), isEmpty);
      expect(MediaCatalog.search('anything else'), isEmpty);
      expect(MediaCatalog.search(''), isEmpty);
      expect(MediaCatalog.search(null), isEmpty);
    });

    test('forQuery follows the voice rules and never comes back empty', () {
      expect(MediaCatalog.forQuery('katha').id, '2');
      expect(MediaCatalog.forQuery('ਹੁਕਮਨਾਮਾ').id, '1');
      expect(MediaCatalog.forQuery('kirtan').id, '0');
      expect(MediaCatalog.forQuery('anything else').id, '0');
      expect(MediaCatalog.forQuery(null).id, '0');
    });
  });
}
