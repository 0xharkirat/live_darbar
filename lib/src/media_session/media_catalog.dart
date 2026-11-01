import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:live_darbar/src/media_session/voice_query.dart';
import 'package:live_darbar/src/models/source_index.dart';

/// What a car or Bluetooth display shows beside the title.
///
/// Those screens read artist and album from the media session and show a blank
/// where there is none, so the title was the only thing on them.
const kSessionArtist = 'Sri Harmandir Sahib, Amritsar';
const kSessionAlbum = 'Live Darbar';

/// The three things the app can play, as the media session names them.
///
/// One definition serves three readers, so they can never disagree. The
/// player tags each source with it, the notification and lock screen show it,
/// and Android Auto lists it. Auto marks the playing row by matching the media
/// id, so the id in the tree has to be the id on the current item.
abstract final class MediaCatalog {
  static const _titles = <int, String>{
    kLiveIndex: 'Live Kirtan',
    kMukhwakIndex: 'Hukamnama',
    kKathaIndex: 'Katha',
  };

  /// The id the session uses for source [index].
  ///
  /// The index as a string. The views read it back from the player's tag to
  /// know which source is current.
  static String idFor(int index) => '$index';

  /// Source [index] as a media item.
  ///
  /// [artUri] is the painting's URI, or null when there is none. On Android it
  /// is a `content:` URI that the Android Auto host can read, and elsewhere it
  /// is a `file:` URI. See `ArtworkStore`.
  /// [duration] is set for a recording once the player knows it. The live
  /// stream has none, and the item says so with `isLive`.
  static MediaItem item(int index, {Uri? artUri, Duration? duration}) {
    final title = _titles[index];
    if (title == null) {
      throw ArgumentError.value(index, 'index', 'no such audio source');
    }
    return MediaItem(
      id: idFor(index),
      title: title,
      artist: kSessionArtist,
      album: kSessionAlbum,
      artUri: artUri,
      duration: index == kLiveIndex ? null : duration,
      isLive: index == kLiveIndex,
      playable: true,
    );
  }

  /// All three, in the order the app lists them. [art] maps a source index to
  /// its painting.
  static List<MediaItem> items([Map<int, Uri> art = const {}]) => [
        for (final index in kSourceIndexes) item(index, artUri: art[index]),
      ];

  /// The item a request to play asks for. Never null: live is the answer to
  /// everything the app does not understand.
  static MediaItem forQuery(String? query, [Map<int, Uri> art = const {}]) {
    final index = sourceForQuery(query);
    return item(index, artUri: art[index]);
  }

  /// The items that answer a search for [query]: the one source it names, or
  /// none. Unlike [forQuery], a query with no keyword in it finds nothing, so
  /// a search for "weather" shows an empty result and not a row of live
  /// kirtan that has nothing to do with it.
  static List<MediaItem> search(
    String? query, [
    Map<int, Uri> art = const {},
  ]) {
    final index = matchQuery(query);
    if (index == null) return const [];
    return [item(index, artUri: art[index])];
  }

  /// The item with media id [id], or null when there is none.
  static MediaItem? byId(String id, [Map<int, Uri> art = const {}]) {
    for (final index in kSourceIndexes) {
      if (idFor(index) == id) return item(index, artUri: art[index]);
    }
    return null;
  }
}
