import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:live_darbar/src/models/daily_edition.dart';
import 'package:live_darbar/src/models/mukhwak_document.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps the day's Mukhwak PDF on disk and knows which day it is.
///
/// Two things were wrong with the way this used to work, and they compounded.
///
/// **Nothing had a timeout.** The fetch ran from `initState` on every launch
/// against `hukamnamapdf.php`, an endpoint that renders the PDF per request
/// and takes about four seconds to produce its first byte on a good day. When
/// it stalls it completes the TLS handshake and then sends nothing at all, and
/// because neither the call nor Dart's default client set a deadline, the
/// future never completed. Anyone without a warm cache got a spinner that
/// could not resolve, with no error and no way out. Every request here now has
/// a deadline, and the failure path ends somewhere.
///
/// **The cache key was the device's date.** Someone in Auckland crossed into
/// tomorrow thirteen and a half hours before Amritsar did, so their cache
/// missed and they refetched a PDF they already had; someone in Los Angeles
/// went the other way and kept yesterday's under today's name. The key is now
/// SGPC's day, which is the only one the content is actually organised by.
///
/// The order of preference is the dated archive file first and the
/// self-rendering endpoint last, which is the opposite of what it was. See
/// [kLatestHukamnamaPdfUrl] for the measurements behind that.
class MukhwakController extends AsyncNotifier<MukhwakDocument?> {
  /// The archive lookup is small and fast, so a short deadline is fair. It has
  /// answered in under 0.6 s on every call measured.
  static const _archiveTimeout = Duration(seconds: 8);

  /// The dated PDF is roughly 680 KB served straight from disk. Twenty seconds
  /// is slow mobile territory rather than a real ceiling.
  static const _pdfTimeout = Duration(seconds: 20);

  /// The undated endpoint gets longer because it has to render before it
  /// sends. Longer, but still finite, which is the entire point.
  static const _latestPdfTimeout = Duration(seconds: 30);

  late http.Client _client;

  @override
  Future<MukhwakDocument?> build() async {
    final client = http.Client();
    _client = client;
    ref.onDispose(client.close);

    final directory = await getApplicationDocumentsDirectory();
    return _cached(directory, sgpcDayNow());
  }

  /// Bring the cache up to date, preferring today and settling for yesterday.
  Future<void> fetchAndCache() async {
    final Directory directory;
    try {
      directory = await getApplicationDocumentsDirectory();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return;
    }

    final today = sgpcDayNow();
    final cached = await _cached(directory, today);

    // Show whatever is already on disk straight away, even when it is
    // yesterday's, rather than making someone watch a spinner for content the
    // app is holding. The network work below then upgrades it in place.
    if (cached != null) state = AsyncValue.data(cached);
    if (cached?.freshness == DailyFreshness.today) return;
    if (cached == null) state = const AsyncValue.loading();

    final fetched = await _fetchDated(directory, today, DailyFreshness.today) ??
        await _fetchDated(
          directory,
          previousSgpcDay(today),
          DailyFreshness.previousDay,
        ) ??
        await _fetchLatest(directory, today);

    if (fetched == null) {
      // Failing with something already on screen must not replace it with an
      // error. The listener has yesterday's Mukhwak open and labelled as
      // such, which is a better place to leave them than an apology.
      if (cached == null) {
        state = AsyncValue.error(
          Exception('no Mukhwak PDF was reachable'),
          StackTrace.current,
        );
      }
      return;
    }

    await _sweepCache(directory, today);
    state = AsyncValue.data(fetched);
  }

  /// The newest usable PDF already on disk, or null.
  ///
  /// Ordered best first. A file older than yesterday is never returned, which
  /// is what stops a stale copy from being shown as though it were current.
  Future<MukhwakDocument?> _cached(Directory directory, DateTime today) async {
    final yesterday = previousSgpcDay(today);
    final candidates = <(String, DailyFreshness, DateTime?)>[
      (MukhwakDocument.datedFileName(today), DailyFreshness.today, today),
      (
        MukhwakDocument.datedFileName(yesterday),
        DailyFreshness.previousDay,
        yesterday,
      ),
      (MukhwakDocument.latestFileName(today), DailyFreshness.latest, null),
    ];

    for (final (name, freshness, day) in candidates) {
      final file = File('${directory.path}/$name');
      if (await file.exists()) {
        return MukhwakDocument(
          filePath: file.path,
          freshness: freshness,
          day: day,
        );
      }
    }
    return null;
  }

  Future<MukhwakDocument?> _fetchDated(
    Directory directory,
    DateTime day,
    DailyFreshness freshness,
  ) async {
    // Reaching here for yesterday usually means today's is not up yet, and
    // yesterday's is often already on disk from yesterday. A dated file never
    // changes, so there is nothing to gain by fetching 680 KB of it again.
    final name = MukhwakDocument.datedFileName(day);
    final existing = File('${directory.path}/$name');
    if (await existing.exists()) {
      return MukhwakDocument(
        filePath: existing.path,
        freshness: freshness,
        day: day,
      );
    }

    final id = await _pdfIdFor(day);
    if (id == null) return null;

    final bytes = await _pdfBytes(hukamnamaPdfUrl(id), _pdfTimeout);
    if (bytes == null) return null;

    return _write(directory, name, bytes, freshness, day);
  }

  Future<MukhwakDocument?> _fetchLatest(
    Directory directory,
    DateTime today,
  ) async {
    final bytes = await _pdfBytes(kLatestHukamnamaPdfUrl, _latestPdfTimeout);
    if (bytes == null) return null;

    return _write(
      directory,
      MukhwakDocument.latestFileName(today),
      bytes,
      DailyFreshness.latest,
      null,
    );
  }

  Future<MukhwakDocument?> _write(
    Directory directory,
    String fileName,
    Uint8List bytes,
    DailyFreshness freshness,
    DateTime? day,
  ) async {
    try {
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);
      return MukhwakDocument(
        filePath: file.path,
        freshness: freshness,
        day: day,
      );
    } catch (e) {
      if (!kReleaseMode) debugPrint('[mukhwak] could not write $fileName: $e');
      return null;
    }
  }

  /// The id of the PDF SGPC generated for [day], or null if they have none.
  Future<int?> _pdfIdFor(DateTime day) async {
    try {
      final response = await _client
          .post(
            Uri.parse(kHukamnamaArchiveUrl),
            headers: const {'X-Requested-With': 'XMLHttpRequest'},
            body: {'selected_date': sgpcDayIso(day)},
          )
          .timeout(_archiveTimeout);
      if (response.statusCode != 200) return null;

      // Decoded explicitly because the response carries Gurmukhi with no
      // charset on its content type, and package:http falls back to latin1.
      return hukamnamaPdfIdFrom(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
    } catch (e) {
      if (!kReleaseMode) {
        debugPrint(
          '[mukhwak] archive lookup failed for ${sgpcDayIso(day)}: $e',
        );
      }
      return null;
    }
  }

  Future<Uint8List?> _pdfBytes(String url, Duration timeout) async {
    try {
      final response = await _client.get(Uri.parse(url)).timeout(timeout);
      if (response.statusCode != 200) return null;
      if (!MukhwakDocument.looksLikePdf(response.bodyBytes)) return null;
      return response.bodyBytes;
    } catch (e) {
      if (!kReleaseMode) debugPrint('[mukhwak] fetch failed for $url: $e');
      return null;
    }
  }

  /// Delete every cached PDF that could no longer be shown.
  Future<void> _sweepCache(Directory directory, DateTime today) async {
    final keep = {
      MukhwakDocument.datedFileName(today),
      MukhwakDocument.datedFileName(previousSgpcDay(today)),
      MukhwakDocument.latestFileName(today),
    };
    try {
      for (final entity in directory.listSync()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith(MukhwakDocument.filePrefix)) continue;
        if (!name.endsWith('.pdf')) continue;
        if (keep.contains(name)) continue;
        await entity.delete();
      }
    } catch (e) {
      if (!kReleaseMode) debugPrint('[mukhwak] cache sweep failed: $e');
    }
  }
}

final mukhwakController =
    AsyncNotifierProvider<MukhwakController, MukhwakDocument?>(
  MukhwakController.new,
);
