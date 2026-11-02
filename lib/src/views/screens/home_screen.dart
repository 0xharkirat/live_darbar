import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/connectivity_controller.dart';
import 'package:live_darbar/src/controllers/hukamnama_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/controllers/update_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/core/open_link.dart';
import 'package:live_darbar/src/core/store_links.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/core/reader_numbers.dart';
import 'package:live_darbar/src/models/app_update.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/models/sikh_date.dart';
import 'package:live_darbar/src/views/screens/about_screen.dart';
import 'package:live_darbar/src/views/screens/hukamnama_screen.dart';
import 'package:live_darbar/src/views/widgets/artwork.dart';
import 'package:live_darbar/src/views/widgets/equalizer.dart';
import 'package:live_darbar/src/views/widgets/language_switch.dart';
import 'package:live_darbar/src/views/widgets/live_badge.dart';
import 'package:live_darbar/src/views/widgets/mini_player_widget.dart';
import 'package:live_darbar/src/views/widgets/play_button.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';
import 'package:live_darbar/src/views/widgets/update_sheet.dart';

/// Today at Darbar Sahib, on one screen.
///
/// The hierarchy is the order people actually come for things: live kirtan
/// first and largest, then today's Hukamnama and its Katha, then reading the
/// Hukamnama. Each of those has its own shape (a painting with words on it,
/// two paintings with captions, a text card), so the screen reads as a page
/// rather than a stack of identical rows.
///
/// Nothing hides behind an unlabelled icon. The language switch shows both
/// languages in their own scripts, and About is a labelled link.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const maxWidth = 540.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final padding = MediaQuery.paddingOf(context);

    ref.listen<AsyncValue<AppUpdate?>>(updateController, (previous, next) {
      final update = next.value;
      if (update == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) showUpdateSheet(context, update);
      });
    });

    return Scaffold(
      backgroundColor: Palette.background,
      body: Stack(
        children: [
          const _DailyRefresh(),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              padding.top + 12,
              20,
              padding.bottom + MiniPlayer.height + 40,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _DateAndLanguage(),
                    const SizedBox(height: 6),
                    Text(l10n.app_title, style: AppType.largeTitle),
                    const SizedBox(height: 20),
                    const _LiveHero(),
                    const SizedBox(height: 32),
                    Text(l10n.today.toUpperCase(), style: AppType.eyebrow),
                    const SizedBox(height: 12),
                    const IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _DailyTile(index: kMukhwakIndex)),
                          SizedBox(width: 14),
                          Expanded(child: _DailyTile(index: kKathaIndex)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _ReadCard(),
                    const SizedBox(height: 36),
                    const _Footer(),
                  ],
                ),
              ),
            ),
          ),
          // A soft fade under the status bar, so content scrolls away under
          // it rather than colliding with the clock.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: padding.top + 8,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Palette.background, Color(0x000C0A09)],
                  ),
                ),
              ),
            ),
          ),
          // And a fade under the floating player, so cards scroll away beneath
          // it instead of peeking out from under its edge.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: padding.bottom + MiniPlayer.height + 36,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Palette.background, Color(0x000C0A09)],
                    stops: [0.55, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: padding.bottom + 10,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxWidth + 16),
                child: const MiniPlayer(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Moves the date and the Hukamnama on when the app comes back to the front.
///
/// People leave this app open for days. Neither provider changes by itself
/// at SGPC midnight, so coming back to the app is when "today" is checked
/// again.
class _DailyRefresh extends ConsumerStatefulWidget {
  const _DailyRefresh();

  @override
  ConsumerState<_DailyRefresh> createState() => _DailyRefreshState();
}

class _DailyRefreshState extends ConsumerState<_DailyRefresh> {
  late final AppLifecycleListener _listener = AppLifecycleListener(
    onResume: _refresh,
  );

  void _refresh() {
    ref.invalidate(sikhDateProvider);
    ref.read(hukamnamaProvider.notifier).refresh();
  }

  @override
  void initState() {
    super.initState();
    _listener;
    // Back online after a gap: look for today's at once instead of waiting
    // for the next scheduled retry.
    ref.listenManual<AsyncValue<bool>>(connectivityController, (prev, next) {
      final was = prev?.value ?? true;
      final now = next.value ?? true;
      if (!was && now) _refresh();
    });
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Today in both calendars, and the language switch.
///
/// The Sikh date comes first, in gold, because it is the date this app keeps:
/// the one SGPC prints on the Hukamnama. The everyday date sits under it.
/// When the Sikh date is not known for certain, only the everyday date shows.
class _DateAndLanguage extends ConsumerWidget {
  const _DateAndLanguage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeController);
    final sikh = ref.watch(sikhDateProvider).value;
    final punjabi = locale == 'pa';
    // Day before month, the way it is written in India and in Australia.
    final date = readerDate(
      everydayDateFor(sikh, ref.read(clockProvider)()),
      punjabi: punjabi,
      weekday: true,
    );

    final sikhLine = sikh == null
        ? null
        : punjabi
            ? sikh.shortGurmukhi
            : sikh.shortEnglish;

    String caps(String s) => punjabi ? s : s.toUpperCase();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sikhLine != null)
                Text(
                  caps(sikhLine),
                  style: AppType.eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                caps(date),
                style: AppType.eyebrow.copyWith(color: Palette.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const LanguageSwitch(),
      ],
    );
  }
}

/// Live kirtan: the painting, the words on it, and the biggest button on the
/// screen.
class _LiveHero extends ConsumerWidget {
  const _LiveHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final now = ref.watch(nowPlayingProvider);
    final playing = now.isLive && now.isPlaying;

    return Pressable(
      semanticLabel: l10n.live_kirtan,
      onTap: () => togglePlayback(ref, kLiveIndex),
      child: AspectRatio(
        aspectRatio: 1.4,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 32,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: ClipRSuperellipse(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The ragis sit in the painting's middle band; anchor a little
                // above centre so the bottom gradient never covers a face.
                const Artwork(
                  index: kLiveIndex,
                  radius: 0,
                  alignment: Alignment(0, -0.2),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x000C0A09),
                        Color(0x000C0A09),
                        Color(0xE60C0A09),
                      ],
                      stops: [0, 0.45, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: LiveBadge(playing: playing, onImage: true),
                ),
                Positioned(
                  left: 20,
                  right: 16,
                  bottom: 18,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.live_kirtan, style: AppType.title),
                            const SizedBox(height: 4),
                            Text(
                              l10n.live_location,
                              style: AppType.callout.copyWith(
                                color: Palette.foreground.withValues(
                                  alpha: 0.78,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const PlayButton(index: kLiveIndex, size: 64),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A painting with a caption under it: the Hukamnama and its Katha.
class _DailyTile extends ConsumerWidget {
  const _DailyTile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final now = ref.watch(nowPlayingProvider);
    final playing = now.index == index && now.isPlaying;
    final title = index == kKathaIndex ? l10n.mukhwak_katha : l10n.mukhwak;
    final subtitle =
        index == kKathaIndex ? l10n.katha_subtitle : l10n.todays_recording;

    return Pressable(
      semanticLabel: title,
      onTap: () => togglePlayback(ref, index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Artwork(index: index, radius: 20),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: PlayButton(
                    index: index,
                    size: 44,
                    look: PlayButtonLook.glass,
                  ),
                ),
                if (playing)
                  const Positioned(
                    left: 12,
                    bottom: 14,
                    child: Equalizer(active: true, color: Palette.foreground),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppType.title2.copyWith(fontSize: 19),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppType.footnote,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Reading today's Hukamnama: the one card that is about words, not sound.
///
/// Once the text has arrived, the card shows the Rahao line, the line the
/// whole shabad turns on, with its meaning. Before that, or offline with
/// nothing stored, it is a plain invitation to read.
class _ReadCard extends ConsumerWidget {
  const _ReadCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hukamnama = ref.watch(hukamnamaProvider).value;
    final punjabi = ref.watch(localeController) == 'pa';
    final line = hukamnama == null ? null : _previewLine(hukamnama);
    // SGPC explains the shabad as a whole, so the preview shows the start of
    // that explanation under the line.
    final meaning = hukamnama == null
        ? null
        : punjabi
            ? (hukamnama.punjabiMeaning ?? hukamnama.englishMeaning)
            : (hukamnama.englishMeaning ?? hukamnama.punjabiMeaning);

    final decoration = ShapeDecoration(
      color: Palette.surface,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Palette.border),
      ),
    );
    void open() => Navigator.of(context).push(
          CupertinoPageRoute<void>(builder: (_) => const HukamnamaScreen()),
        );

    if (line != null) {
      // Before SGPC posts today's (about 05:30 to 07:00 in India), the card
      // shows yesterday's and says so, rather than passing it off as today's.
      final stale = !hukamnama!.isFor(sgpcDayOf(ref.read(clockProvider)()));
      final eyebrow = [
        stale
            ? l10n.hukamnama_of(readerDate(hukamnama.date, punjabi: punjabi))
            : l10n.read_hukamnama,
        if (hukamnama.ang != null)
          l10n.hukamnama_ang(readerNumber(hukamnama.ang!, punjabi: punjabi)),
      ].join('  ·  ');
      return Pressable(
        semanticLabel: l10n.read_hukamnama,
        onTap: open,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 18),
          decoration: decoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      punjabi ? eyebrow : eyebrow.toUpperCase(),
                      style: AppType.eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 18,
                    color: Palette.faint,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                line.gurmukhi,
                style: AppType.gurbani.copyWith(fontSize: 20),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (meaning != null) ...[
                const SizedBox(height: 6),
                Text(
                  meaning.trim(),
                  style: AppType.footnote.copyWith(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Pressable(
      semanticLabel: l10n.read_hukamnama,
      onTap: open,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        decoration: decoration,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: ShapeDecoration(
                color: Palette.gold.withValues(alpha: 0.14),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Icon(
                CupertinoIcons.book_fill,
                color: Palette.gold,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.read_hukamnama, style: AppType.headline),
                  const SizedBox(height: 2),
                  Text(l10n.read_hukamnama_detail, style: AppType.footnote),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: Palette.faint,
            ),
          ],
        ),
      ),
    );
  }

  /// The Rahao line if there is one: the line the whole shabad turns on.
  /// Otherwise the first real verse, skipping short labels such as ਸਲੋਕੁ ॥.
  static HukamnamaLine? _previewLine(Hukamnama h) {
    for (final line in h.lines) {
      if (line.gurmukhi.contains('ਰਹਾਉ')) return line;
    }
    for (final line in h.lines) {
      if (line.gurmukhi.length > 20) return line;
    }
    return h.lines.isEmpty ? null : h.lines.first;
  }
}

class _Footer extends ConsumerWidget {
  const _Footer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final version = ref.watch(appVersionProvider).value;

    Widget link(String label, VoidCallback onTap) => CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(44, 44),
          onPressed: onTap,
          child: Text(
            label,
            style: AppType.callout.copyWith(color: Palette.gold),
          ),
        );

    return Column(
      children: [
        link(
          l10n.about_this_app,
          () => Navigator.of(context).push(
            CupertinoPageRoute<void>(builder: (_) => const AboutScreen()),
          ),
        ),
        // On the web, the site is often someone's first contact with the
        // app, so it offers the real thing.
        if (kIsWeb)
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              link(l10n.google_play, () => openLink(kPlayStoreUrl)),
              link(l10n.apple_store, () => openLink(kAppStoreUrl)),
            ],
          ),
        if (version != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.update_version(version),
            style: AppType.footnote.copyWith(color: Palette.faint),
          ),
        ],
      ],
    );
  }
}
