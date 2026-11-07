import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/audio_controller.dart';
import 'package:live_darbar/src/controllers/hukamnama_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/controllers/now_playing_controller.dart';
import 'package:live_darbar/src/controllers/sangrand_controller.dart';
import 'package:live_darbar/src/controllers/reader_meanings_controller.dart';
import 'package:live_darbar/src/controllers/reader_scale_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/core/meaning_paragraphs.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/open_link.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/core/reader_numbers.dart';
import 'package:live_darbar/src/core/share.dart';
import 'package:live_darbar/src/core/share_text.dart';
import 'package:live_darbar/src/core/store_links.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/services/hukamnama_service.dart';
import 'package:live_darbar/src/views/app_router.dart';
import 'package:live_darbar/src/views/widgets/hukamnama_day_sheet.dart';
import 'package:live_darbar/src/views/widgets/sheet_parts.dart';
import 'package:live_darbar/src/views/widgets/app_sheet.dart';
import 'package:live_darbar/src/views/widgets/app_nav_bar.dart';
import 'package:live_darbar/src/views/widgets/busy_icon.dart';
import 'package:live_darbar/src/views/widgets/in_app_link.dart';
import 'package:live_darbar/src/views/widgets/keep_screen_awake.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';
import 'package:live_darbar/src/views/widgets/reminder_bell.dart';
import 'package:live_darbar/src/views/widgets/reminder_sheet.dart';

/// Today's Hukamnama as words, line by line, with the meaning under each line.
///
/// The words come first and largest, in the serif Gurmukhi they are printed
/// in. Under each line sits its meaning in the app's language, and in English
/// the transliteration too, for the many who listen to Gurbani every day but
/// do not read Gurmukhi. Text size has its own control here, because this is
/// the one screen that is read slowly and closely.
///
/// The first time the listener opens it, it asks once about the daily
/// reminder (`askAboutReminderOnFirstOpen`). After that the bell in the top
/// bar opens the same sheet, to set the reminder up or change it.
///
/// With a [day] before today it is the same reader for that earlier day, and
/// the date line at the top is a button that opens the archive sheet (see
/// [showHukamnamaDaySheet]). An earlier day has no recording in the app, so
/// it has Share and no Listen, and no link to SGPC's PDF, which is of today.
/// On Sangrand it also has the pauri of Barah Maha, as today's does.
class HukamnamaScreen extends ConsumerStatefulWidget {
  const HukamnamaScreen({super.key, this.day});

  /// The earlier day to read, an SGPC day. Null is today's reader, as is a day
  /// that is today or later: an address cannot ask for a day that has no text
  /// yet, and a mistyped one never ends on an error page.
  final DateTime? day;

  /// The route's name. Whoever opens the reader from outside a screen (the
  /// home screen widget) uses it to tell whether the reader is already open.
  static const routeName = '/hukamnama';

  /// The page transition that every screen opens the reader with.
  static Route<void> route() => CupertinoPageRoute<void>(
        settings: const RouteSettings(name: routeName),
        builder: (_) => const HukamnamaScreen(),
      );

  @override
  ConsumerState<HukamnamaScreen> createState() => _HukamnamaScreenState();
}

class _HukamnamaScreenState extends ConsumerState<HukamnamaScreen> {
  final _question = CancelAsk();

  @override
  void initState() {
    super.initState();
    // After the first frame, so the route is there to read. The check waits
    // for the page to settle, and for any sheet over it to close.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Both are about today. A listener who opens an earlier day, from a link
      // or the archive, is reading, and is asked nothing.
      if (mounted && _earlier == null) {
        unawaited(askAboutReminderOnFirstOpen(context, cancel: _question));
        // The mirror can add today's line meanings after the app read the
        // text, so opening the reader asks for them again.
        ref.read(hukamnamaProvider.notifier).refreshForLines();
      }
    });
  }

  @override
  void dispose() {
    _question.cancel();
    super.dispose();
  }

  /// The earlier day this reader shows, or null for today's.
  DateTime? get _earlier {
    final day = widget.day;
    if (day == null) return null;
    final earlier = DateTime.utc(day.year, day.month, day.day);
    return earlier.isBefore(sgpcDayOf(ref.read(clockProvider)()))
        ? earlier
        : null;
  }

  @override
  Widget build(BuildContext context) {
    // The reader is read slowly with no touch, so the screen stays on while
    // it is open, and the phone locks as usual once it closes.
    return KeepScreenAwake(child: _page(context));
  }

  Widget _page(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final earlier = _earlier;
    final state = earlier == null
        ? ref.watch(hukamnamaProvider)
        : ref.watch(hukamnamaForDayProvider(earlier));

    return Scaffold(
      backgroundColor: Palette.background,
      body: CustomScrollView(
        slivers: [
          AppNavBar(
            title: l10n.mukhwak,
            contentWidth: _Column.maxWidth,
            // The bell and 1 Aa button. Text size and meanings are 1 level
            // deeper, in the reading options: Hark, 7 November, the reader
            // looked "so crowded with so many buttons".
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ReminderBell(),
                _ReadingButton(meanings: state.value?.shabad != null),
              ],
            ),
          ),
          // Stored text shows even while a refresh runs or after it fails;
          // the failure screen is only for having nothing at all.
          if (state.hasValue)
            ..._content(context, state.requireValue, earlier)
          else if (state.hasError && !state.isLoading)
            _Failure(l10n: l10n, earlier: earlier, error: state.error)
          else
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator()),
            ),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, Hukamnama h, DateTime? earlier) {
    final l10n = AppLocalizations.of(context)!;
    final punjabi = ref.watch(localeController) == 'pa';
    final scale = ref.watch(readerScaleProvider);
    final meanings = ref.watch(readerMeaningsProvider);
    // An earlier day is that day's own text, not today's that has not come.
    final stale =
        earlier == null && !h.isFor(sgpcDayOf(ref.read(clockProvider)()));
    final sangrand = earlier == null
        ? ref.watch(sangrandProvider).value
        : ref.watch(sangrandForDayProvider(earlier)).value;

    // The mirror's lines carry a meaning under each line and the pauses, so
    // they are read first, and they replace SGPC's meaning of the whole
    // shabad. Without them, SGPC's own lines show as before, and SGPC's
    // meaning below is the only meaning.
    final shabad = h.shabad;
    final lines = shabad?.lines ?? h.lines;
    // The credit names the meanings on screen, or both when none shows.
    final meaningBy = [
      if (meanings.punjabi || !meanings.english) shabad?.credits['punjabi'],
      if (meanings.english || !meanings.punjabi) shabad?.credits['english'],
    ].nonNulls.join('; ');

    // One short line: the ang, the Sikh date of the Hukamnama's own day, and
    // the everyday date. SGPC's footer ("Monday, 17th Katak (Samvat 558
    // Nanakshahi)") is too long, so the date comes from the sangrand table
    // instead. Without a table or a row for the day, the Sikh date is left out
    // rather than guessed.
    final sikh = ref.watch(sangrandTableProvider).value?.sikhDateFor(h.date);
    final meta = [
      if (h.ang != null)
        l10n.hukamnama_ang(readerNumber(h.ang!, punjabi: punjabi)),
      if (sikh != null) punjabi ? sikh.shortGurmukhi : sikh.shortEnglish,
      readerDate(h.date, punjabi: punjabi, year: _showsYear(ref, h, earlier)),
    ].join(' · ');

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        sliver: SliverToBoxAdapter(
          child: _Column(
            children: [
              // The line names the day, and opens the archive: the reader's one
              // way to another day.
              if (meta.isNotEmpty)
                _DateLine(
                  meta: meta,
                  onTap: () => _chooseDay(context, ref, earlier),
                ),
              if (stale) ...[
                const SizedBox(height: 4),
                _Note(
                  text: l10n.hukamnama_not_out(
                    readerDate(h.date, punjabi: punjabi),
                  ),
                ),
              ],
              // The date line has 12 of its own space below its text.
              SizedBox(height: stale ? 16 : 4),
              _Actions(hukamnama: h, earlier: earlier),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      // The Granth's own title from the mirror, with its meanings, when the
      // mirror found it. Else SGPC's heading, as SGPC prints it.
      if (shabad != null && shabad.heading.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          sliver: SliverList.separated(
            itemCount: shabad.heading.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) => _Column(
              child: _Line(
                line: shabad.heading[i],
                punjabi: punjabi,
                meanings: meanings,
                scale: scale,
                title: true,
              ),
            ),
          ),
        )
      else if (h.headingGurmukhi != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          sliver: SliverToBoxAdapter(
            child: _Column(
              child: SelectableText(
                h.headingGurmukhi!,
                style: AppType.gurbani.copyWith(
                  fontSize: 18 * scale,
                  color: Palette.gold,
                ),
              ),
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        sliver: SliverList.separated(
          itemCount: lines.length,
          // A line with its meaning under it needs more air before the next,
          // so each pair reads as 1 unit and not as a wall.
          separatorBuilder: (_, __) =>
              SizedBox(height: shabad != null ? 26 : 14),
          itemBuilder: (context, i) => _Column(
            child: _Line(
              line: lines[i],
              punjabi: punjabi,
              meanings: meanings,
              scale: scale,
            ),
          ),
        ),
      ),
      // On Sangrand day the sangat hears the month's pauri of Barah Maha
      // after the Hukamnama, so the reader shows it next. Only over the
      // Hukamnama of that day: before SGPC posts, the text on screen is
      // yesterday's. An earlier day that was a Sangrand has its month's pauri.
      if (sangrand != null && sangrand.isSangrandDay && !stale)
        ..._sangrandSlivers(context, ref, sangrand, withTitle: true),
      if (shabad == null &&
          (h.punjabiMeaning != null || h.englishMeaning != null))
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _Column(
              child: _Meaning(hukamnama: h, scale: scale),
            ),
          ),
        ),
      SliverSafeArea(
        top: false,
        sliver: SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
          sliver: SliverToBoxAdapter(
            child: _Column(
              children: [
                if (shabad != null && meaningBy.isNotEmpty)
                  Text(
                    l10n.hukamnama_lines_credit(
                      meaningBy,
                      shabad.credits['vishraam'] ??
                          shabad.source ??
                          'Shabad OS',
                      shabad.source ?? 'Shabad OS',
                    ),
                    textAlign: TextAlign.center,
                    style: AppType.footnote.copyWith(color: Palette.faint),
                  ),
                // SGPC's own page of the day, next to SGPC's name: it is the
                // source, read once in a while, so it is not at the top.
                const SizedBox(height: 20),
                // SGPC's PDF page builds today's, so it is not for another day.
                if (earlier == null) const Center(child: _PdfLink()),
                Center(
                  child: CupertinoButton(
                    onPressed: () => openLink(kHukamnamaSourceUrl),
                    child: Text(
                      // The meanings under the lines are not SGPC's.
                      shabad != null
                          ? l10n.hukamnama_source(kHukamnamaSourceName)
                          : l10n.text_source(kHukamnamaSourceName),
                      style: AppType.footnote.copyWith(color: Palette.faint),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }
}

/// The Sangrand Hukamnama's slivers: "Barah Maha · Katak · Ang 135", the
/// title lines, then the month's pauri, each line with the chosen meanings.
/// The Sangrand page shows them, and so does the reader on Sangrand day, after
/// the day's Hukamnama, under the title [withTitle].
List<Widget> _sangrandSlivers(
  BuildContext context,
  WidgetRef ref,
  Sangrand s, {
  bool withTitle = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  final punjabi = ref.watch(localeController) == 'pa';
  final scale = ref.watch(readerScaleProvider);
  final meanings = ref.watch(readerMeaningsProvider);
  final meta = [
    l10n.barah_maha,
    punjabi ? s.date.monthGurmukhi : s.date.monthEnglish,
    if (s.ang != null)
      l10n.hukamnama_ang(readerNumber(s.ang!, punjabi: punjabi)),
  ].join(' · ');

  Widget line(HukamnamaLine l, {bool title = false}) => _Column(
        child: _Line(
          line: l,
          punjabi: punjabi,
          meanings: meanings,
          scale: scale,
          title: title,
        ),
      );

  return [
    SliverPadding(
      padding: EdgeInsets.fromLTRB(20, withTitle ? 44 : 4, 20, 8),
      sliver: SliverToBoxAdapter(
        child: _Column(
          children: [
            if (withTitle) ...[
              const Divider(height: 1, color: Palette.border),
              const SizedBox(height: 28),
              Text(l10n.sangrand_title, style: AppType.title2),
              const SizedBox(height: 6),
            ],
            Text(meta, style: AppType.callout),
          ],
        ),
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      sliver: SliverList.separated(
        itemCount: s.heading.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) => line(s.heading[i], title: true),
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      sliver: SliverList.separated(
        itemCount: s.lines.length,
        separatorBuilder: (_, __) => const SizedBox(height: 26),
        itemBuilder: (context, i) => line(s.lines[i]),
      ),
    ),
  ];
}

/// The Sangrand Hukamnama: the pauri of Barah Maha Maajh for the Sikh month
/// it is now, as the sangat reads it on Sangrand. Hark, 7 November.
///
/// It reads like the Hukamnama: the title lines, then each line with the
/// chosen meanings under it and the pause colours, with the same reading
/// options. Barah Maha ships with the app ([BarahMaha]), so it needs no
/// network.
class SangrandScreen extends ConsumerWidget {
  const SangrandScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sangrand = ref.watch(sangrandProvider).value;
    return KeepScreenAwake(
      child: Scaffold(
        backgroundColor: Palette.background,
        body: CustomScrollView(
          slivers: [
            AppNavBar(
              title: l10n.sangrand_title,
              contentWidth: _Column.maxWidth,
              trailing: const _ReadingButton(meanings: true),
            ),
            if (sangrand == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CupertinoActivityIndicator()),
              )
            else
              ..._content(context, ref, sangrand),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, WidgetRef ref, Sangrand s) {
    final l10n = AppLocalizations.of(context)!;
    final meanings = ref.watch(readerMeaningsProvider);
    final meaningBy = [
      if (meanings.punjabi || !meanings.english) s.credits['punjabi'],
      if (meanings.english || !meanings.punjabi) s.credits['english'],
    ].nonNulls.join('; ');

    return [
      ..._sangrandSlivers(context, ref, s),
      SliverSafeArea(
        top: false,
        sliver: SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
          sliver: SliverToBoxAdapter(
            child: _Column(
              child: Text(
                l10n.hukamnama_lines_credit(
                  meaningBy,
                  s.credits['vishraam'] ?? 'Shabad OS',
                  'Shabad OS',
                ),
                textAlign: TextAlign.center,
                style: AppType.footnote.copyWith(color: Palette.faint),
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

/// Keeps reading width comfortable on a tablet or a Mac window.
class _Column extends StatelessWidget {
  const _Column({this.child, this.children});

  /// The widest the text runs. The nav bar lines up with it on the web.
  static const maxWidth = 620.0;

  final Widget? child;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        // Full width, so a short line sits at the left edge with the rest
        // instead of floating in the middle.
        child: child != null
            ? SizedBox(width: double.infinity, child: child)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children!,
              ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.line,
    required this.punjabi,
    required this.meanings,
    required this.scale,
    this.title = false,
  });

  /// A title line: smaller, in gold, as SGPC's heading was.
  final bool title;

  final HukamnamaLine line;

  /// The app's language. The transliteration shows only in English.
  final bool punjabi;

  /// The meanings the listener chose to show.
  final ReaderMeanings meanings;
  final double scale;

  /// The line, with the word before each pause in its colour: kesri for a
  /// long pause, green for a short one, as Chet colours them. The colour tells
  /// a reader where to rest, and it breaks up the page.
  TextSpan _gurmukhi(TextStyle style) {
    if (line.vishraam.isEmpty) {
      return TextSpan(text: line.gurmukhi, style: style);
    }
    final pauses = {for (final v in line.vishraam) v.after: v.weight};
    final words = line.gurmukhi.split(RegExp(r'\s+'));
    return TextSpan(
      style: style,
      children: [
        for (final (i, word) in words.indexed) ...[
          if (i > 0) const TextSpan(text: ' '),
          TextSpan(
            text: word,
            style: switch (pauses[i]) {
              null => null,
              HukamnamaPause.light =>
                const TextStyle(color: Palette.pauseShort),
              HukamnamaPause.medium ||
              HukamnamaPause.heavy =>
                const TextStyle(color: Palette.pauseLong),
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Punjabi first, then English, each when chosen and when the line has it.
    final shown = [
      if (meanings.punjabi) line.punjabi,
      if (meanings.english) line.english,
    ].nonNulls;
    final roman = punjabi ? null : line.transliteration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText.rich(
          _gurmukhi(
            title
                ? AppType.gurbani.copyWith(
                    fontSize: 18 * scale,
                    color: Palette.gold,
                  )
                : AppType.gurbani.copyWith(fontSize: 22 * scale),
          ),
        ),
        if (roman != null) ...[
          const SizedBox(height: 4),
          // Gold marks it as a transliteration. Not italic: Geist ships no
          // italic file, so the engine would slant the upright face.
          Text(
            roman,
            style: AppType.callout.copyWith(
              fontSize: 15 * scale,
              color: Palette.gold.withValues(alpha: 0.85),
            ),
          ),
        ],
        for (final (i, meaning) in shown.indexed) ...[
          SizedBox(height: i == 0 ? 6 : 4),
          SelectableText(
            meaning,
            style: AppType.body.copyWith(
              fontSize: 16 * scale,
              color: Palette.muted,
            ),
          ),
        ],
      ],
    );
  }
}

/// SGPC's explanation of the whole Hukamnama, in Punjabi or English.
///
/// It starts in the app's language, and the toggle switches only this text,
/// so someone reading the app in Punjabi can check the English without going
/// back to change the whole app.
class _Meaning extends ConsumerStatefulWidget {
  const _Meaning({required this.hukamnama, required this.scale});

  final Hukamnama hukamnama;
  final double scale;

  @override
  ConsumerState<_Meaning> createState() => _MeaningState();
}

class _MeaningState extends ConsumerState<_Meaning> {
  bool? _punjabi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final h = widget.hukamnama;
    final hasPa = h.punjabiMeaning != null;
    final hasEn = h.englishMeaning != null;
    final appPunjabi = ref.watch(localeController) == 'pa';
    final punjabi = (_punjabi ?? appPunjabi) ? hasPa : !hasEn;
    final text = punjabi ? h.punjabiMeaning! : h.englishMeaning!;

    Widget option(String label, bool forPunjabi, bool available) {
      final active = punjabi == forPunjabi;
      return Semantics(
        button: true,
        selected: active,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: available && !active
              ? () {
                  HapticFeedback.selectionClick();
                  setState(() => _punjabi = forPunjabi);
                }
              : null,
          child: AnimatedContainer(
            duration: Motion.quick,
            curve: Motion.easeOut,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: active ? Palette.surfaceHigh : Colors.transparent,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              label,
              style: AppType.footnote.copyWith(
                color: active ? Palette.foreground : Palette.muted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.meaning, style: AppType.title2)),
            if (hasPa && hasEn)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: ShapeDecoration(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(13),
                    side: const BorderSide(color: Palette.border),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    option('ਪੰਜਾਬੀ', true, hasPa),
                    option('English', false, hasEn),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: Motion.quick,
          child: Column(
            key: ValueKey(punjabi),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, paragraph) in meaningParagraphs(text).indexed) ...[
                if (i > 0) const SizedBox(height: 14),
                SelectableText(
                  paragraph,
                  style: AppType.body.copyWith(
                    fontSize: 17 * widget.scale,
                    height: 1.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A pill button: gold for the main action, quiet for the rest.
Widget _pill({
  required IconData icon,
  required String label,
  required VoidCallback? onTap,
  bool primary = false,
  bool external = false,
  bool busy = false,
  String? semanticLabel,
}) =>
    Pressable(
      semanticLabel: semanticLabel ?? label,
      onTap: onTap,
      // The label above is the whole of what the reader says.
      child: ExcludeSemantics(
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: ShapeDecoration(
            color: primary ? Palette.gold : Palette.surfaceHigh,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(14),
              side: primary
                  ? BorderSide.none
                  : const BorderSide(color: Palette.border),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BusyIcon(
                busy: busy,
                icon: icon,
                size: 17,
                color: primary ? Palette.onGold : Palette.gold,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppType.headline.copyWith(
                  fontSize: 15,
                  color: primary ? Palette.onGold : Palette.foreground,
                ),
              ),
              if (external) ...[
                const SizedBox(width: 6),
                const _LeavesTheApp(),
              ],
            ],
          ),
        ),
      ),
    );

/// Listen and Share: the 2 things a listener does with the Hukamnama. An
/// earlier day has Share alone: the player has today's recording and Katha, and
/// no other day's.
class _Actions extends ConsumerWidget {
  const _Actions({required this.hukamnama, this.earlier});

  /// The text on screen. Share sends its first line, with its own date.
  final Hukamnama hukamnama;

  /// The earlier day on screen, or null on today's reader.
  final DateTime? earlier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final now = ref.watch(nowPlayingProvider);
    final playing = now.index == kMukhwakIndex && now.isPlaying;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (earlier == null)
          _pill(
            icon:
                playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
            label: playing ? l10n.pause : l10n.listen,
            primary: true,
            onTap: () => togglePlayback(ref, kMukhwakIndex),
          ),
        // The sangat forwards the Hukamnama every morning. This sends the
        // first line and the date, as plain text, with a link to the rest.
        Builder(
          builder: (button) => _pill(
            icon: CupertinoIcons.share,
            label: l10n.share,
            semanticLabel: l10n.share_hukamnama,
            onTap: () => _shareHukamnama(button, ref, hukamnama, earlier),
          ),
        ),
      ],
    );
  }
}

/// SGPC's PDF of the day, opened in the in-app browser.
class _PdfLink extends StatelessWidget {
  const _PdfLink();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InAppLink(
      url: kHukamnamaPdfPageUrl,
      builder: (context, opening, open) => _pill(
        icon: CupertinoIcons.doc_text,
        label: l10n.sgpc_pdf,
        external: true,
        busy: opening,
        onTap: open,
      ),
    );
  }
}

/// The Aa button: the reading options, text size and meanings.
class _ReadingButton extends StatelessWidget {
  const _ReadingButton({required this.meanings});

  /// Whether the text on screen has meanings under its lines to choose.
  final bool meanings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: l10n.reader_options,
      excludeSemantics: true,
      child: CupertinoButton(
        key: const ValueKey('reader-options'),
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        onPressed: () => showAppSheet<void>(
          context,
          (_) => _ReadingSheet(meanings: meanings),
        ),
        child: Text(
          'Aa',
          style: AppType.headline.copyWith(color: Palette.gold, fontSize: 19),
        ),
      ),
    );
  }
}

/// The reading options: text size, and which meanings show under each line.
///
/// The reader stays in view above the sheet, so each change shows at once on
/// the text it changes.
class _ReadingSheet extends ConsumerWidget {
  const _ReadingSheet({required this.meanings});

  /// Whether to offer the meaning switches. A day with SGPC's text only has
  /// no meanings under its lines.
  final bool meanings;

  static const _radius = 20.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final chosen = ref.watch(readerMeaningsProvider);
    final controller = ref.read(readerMeaningsProvider.notifier);

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(text, style: AppType.callout),
        );

    Widget group(List<Widget> children) => DecoratedBox(
          decoration: ShapeDecoration(
            color: Palette.surfaceHigh,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(_radius),
            ),
          ),
          child: Column(children: children),
        );

    Widget meaning(String key, String name, bool on, ValueChanged<bool> set) =>
        MergeSemantics(
          child: GestureDetector(
            key: ValueKey('reader-meaning-$key'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              set(!on);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  Expanded(child: Text(name, style: AppType.headline)),
                  CupertinoSwitch(
                    value: on,
                    activeTrackColor: Palette.gold,
                    onChanged: set,
                  ),
                ],
              ),
            ),
          ),
        );

    return SheetFrame(
      key: const ValueKey('reader-sheet'),
      children: [
        Text(l10n.reader_options, style: AppType.title2),
        const SizedBox(height: 20),
        label(l10n.reader_text_size),
        group(const [_TextSizeControl()]),
        if (meanings) ...[
          const SizedBox(height: 24),
          label(l10n.reader_meanings),
          group([
            meaning('punjabi', 'ਪੰਜਾਬੀ', chosen.punjabi, controller.setPunjabi),
            const Divider(height: 1, indent: 16, color: Palette.border),
            meaning(
                'english', 'English', chosen.english, controller.setEnglish),
          ]),
        ],
      ],
    );
  }
}

/// Shares [h] from the button at [context].
///
/// The date is the Hukamnama's own day, which is not always today (see
/// [Hukamnama.date]), so the title never says "today". For an [earlier] day the
/// link names that day, so it opens the shabad that was shared. That day has no
/// recording, so the text does not say listen.
Future<void> _shareHukamnama(
  BuildContext context,
  WidgetRef ref,
  Hukamnama h,
  DateTime? earlier,
) {
  final l10n = AppLocalizations.of(context)!;
  final punjabi = ref.read(localeController) == 'pa';
  final title = [
    l10n.share_hukamnama_title(
      readerDate(h.date, punjabi: punjabi, year: _showsYear(ref, h, earlier)),
    ),
    if (h.ang != null)
      l10n.hukamnama_ang(readerNumber(h.ang!, punjabi: punjabi)),
  ].join(' · ');
  return shareText(
    context,
    hukamnamaShareText(
      title: title,
      firstLine: h.lines.first.gurmukhi,
      more: h.lines.length > 1,
      footer: earlier == null
          ? l10n.share_hukamnama_footer
          : l10n.share_hukamnama_footer_day,
      url: earlier == null ? kHukamnamaWebUrl : hukamnamaWebUrlOn(h.date),
    ),
    subject: l10n.mukhwak,
    copied: l10n.link_copied,
  );
}

/// A−, the 5 sizes as dots, and A+. Each step ticks, and a button at the end
/// of the range is dim and quiet.
class _TextSizeControl extends ConsumerWidget {
  const _TextSizeControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(readerScaleProvider);
    final scale = ref.read(readerScaleProvider.notifier);
    final at = ReaderScaleController.steps.indexOf(current);

    Widget button(String label, String semantic, bool enabled, VoidCallback f) {
      return Semantics(
        button: true,
        label: semantic,
        excludeSemantics: true,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(56, 52),
          onPressed: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  f();
                }
              : null,
          child: AnimatedOpacity(
            duration: Motion.quick,
            opacity: enabled ? 1 : 0.35,
            child: Text(
              label,
              style: AppType.headline.copyWith(color: Palette.gold),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        button('A−', l10n.smaller_text, scale.canShrink, scale.shrink),
        Expanded(
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < ReaderScaleController.steps.length; i++)
                  AnimatedContainer(
                    duration: Motion.quick,
                    curve: Motion.easeOut,
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= at ? Palette.gold : Palette.border,
                    ),
                  ),
              ],
            ),
          ),
        ),
        button('A+', l10n.larger_text, scale.canGrow, scale.grow),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: ShapeDecoration(
        color: Palette.surfaceHigh,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child:
                Icon(CupertinoIcons.calendar, size: 16, color: Palette.muted),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppType.footnote)),
        ],
      ),
    );
  }
}

class _Failure extends ConsumerWidget {
  const _Failure({required this.l10n, this.earlier, this.error});

  final AppLocalizations l10n;

  /// The earlier day that failed, or null for today's reader.
  final DateTime? earlier;

  /// What went wrong. A day with no text is no fault: asking again will not
  /// change the answer.
  final Object? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = earlier;
    if (day != null) return _earlierDayFailure(context, ref, day);
    const web = kIsWeb;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.book, size: 32, color: Palette.faint),
            const SizedBox(height: 12),
            Text(
              l10n.hukamnama_unavailable,
              textAlign: TextAlign.center,
              style: AppType.callout,
            ),
            const SizedBox(height: 8),
            _FailureLink(
              label: l10n.retry,
              onTap: () => ref.read(hukamnamaProvider.notifier).refresh(),
            ),
            // The web app reads a copy of SGPC's text, which can be late or
            // down, so it also sends the reader to SGPC's own site. The PDF
            // page needs the in-app browser, which web does not have.
            if (web)
              _FailureLink(
                label: l10n.open_on_sgpc,
                external: true,
                onTap: () => openLink(kHukamnamaSourceUrl),
              )
            else
              InAppLink(
                url: kHukamnamaPdfPageUrl,
                builder: (context, opening, open) => _FailureLink(
                  label: l10n.sgpc_pdf,
                  external: true,
                  busy: opening,
                  onTap: open,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// What the reader says when an earlier day did not load. A day with no text
  /// says so and offers another day; any other fault also offers a retry. The
  /// PDF is of today, so neither offers it.
  Widget _earlierDayFailure(BuildContext context, WidgetRef ref, DateTime day) {
    final none = error is HukamnamaNotPublishedException;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.book, size: 32, color: Palette.faint),
            const SizedBox(height: 12),
            Text(
              none ? l10n.archive_none : l10n.archive_failed,
              textAlign: TextAlign.center,
              style: AppType.callout,
            ),
            const SizedBox(height: 8),
            if (!none)
              _FailureLink(
                label: l10n.retry,
                onTap: () => ref.invalidate(hukamnamaForDayProvider(day)),
              ),
            _FailureLink(
              label: l10n.archive_other_day,
              onTap: () => _chooseDay(context, ref, day),
            ),
          ],
        ),
      ),
    );
  }
}

/// The date line, as a button: the day the reader shows, and a small calendar
/// that says it opens the archive.
class _DateLine extends StatelessWidget {
  const _DateLine({required this.meta, required this.onTap});

  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Pressable(
        key: const ValueKey('reader-date'),
        semanticLabel: '$meta, ${l10n.hukamnama_pick_day}',
        onTap: onTap,
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(meta, style: AppType.callout)),
                const SizedBox(width: 8),
                const Icon(
                  CupertinoIcons.calendar,
                  size: 16,
                  color: Palette.gold,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether the date of [h] is written with its year: for an earlier day that
/// is not of the year it is now, where "2 November" would not say which.
bool _showsYear(WidgetRef ref, Hukamnama h, DateTime? earlier) =>
    earlier != null && h.date.year != sgpcDayOf(ref.read(clockProvider)()).year;

/// Asks which day to read, and opens it.
///
/// [shown] is the earlier day on screen, or null on today's reader. From
/// today's reader the day opens over it, so back returns to today. From an
/// earlier day it takes that reader's place, so the days do not stack. Today,
/// from an earlier day, goes back to today's reader.
Future<void> _chooseDay(
  BuildContext context,
  WidgetRef ref,
  DateTime? shown,
) async {
  final picked = await showHukamnamaDaySheet(context, shown: shown);
  if (picked == null || !context.mounted) return;
  final navigator = Navigator.of(context);
  final today = sgpcDayOf(ref.read(clockProvider)());

  if (!picked.isBefore(today)) {
    if (shown == null) return;
    // Back to the reader of today that sits under this one. With none under
    // it, as when a link opened this one, open it.
    var onToday = false;
    navigator.popUntil((route) {
      onToday = route.settings.name == AppRoutes.hukamnama;
      return onToday || route.isFirst;
    });
    if (!onToday) unawaited(navigator.pushNamed(AppRoutes.hukamnama));
  } else if (picked == shown) {
    return;
  } else if (shown == null) {
    unawaited(navigator.pushNamed(AppRoutes.hukamnamaOn(picked)));
  } else {
    unawaited(navigator.pushReplacementNamed(AppRoutes.hukamnamaOn(picked)));
  }
}

/// The small arrow that says a button leaves the app, for the browser. While
/// [busy] it is a spinner, for a button that has no other icon to swap.
class _LeavesTheApp extends StatelessWidget {
  const _LeavesTheApp({this.busy = false});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return BusyIcon(
      busy: busy,
      icon: CupertinoIcons.arrow_up_right,
      size: 13,
      color: Palette.muted,
    );
  }
}

/// A text button under the failure message. It is a [Pressable], like the
/// pills above it, so the same action has the same press feedback whichever
/// screen it is on.
class _FailureLink extends StatelessWidget {
  const _FailureLink({
    required this.label,
    required this.onTap,
    this.external = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool external;

  /// The browser is on its way: the arrow becomes a spinner.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            widthFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppType.callout.copyWith(color: Palette.gold),
                ),
                if (external) ...[
                  const SizedBox(width: 6),
                  _LeavesTheApp(busy: busy),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
