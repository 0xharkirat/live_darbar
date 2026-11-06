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
import 'package:live_darbar/src/controllers/reader_scale_controller.dart';
import 'package:live_darbar/src/controllers/sikh_date_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/core/meaning_paragraphs.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/open_link.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/core/reader_numbers.dart';
import 'package:live_darbar/src/models/hukamnama.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
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
class HukamnamaScreen extends ConsumerStatefulWidget {
  const HukamnamaScreen({super.key});

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
      if (mounted) {
        unawaited(askAboutReminderOnFirstOpen(context, cancel: _question));
      }
    });
  }

  @override
  void dispose() {
    _question.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The reader is read slowly with no touch, so the screen stays on while
    // it is open, and the phone locks as usual once it closes.
    return KeepScreenAwake(child: _page(context));
  }

  Widget _page(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(hukamnamaProvider);

    return Scaffold(
      backgroundColor: Palette.background,
      body: CustomScrollView(
        slivers: [
          AppNavBar(
            title: l10n.mukhwak,
            contentWidth: _Column.maxWidth,
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [ReminderBell(), _TextSizeControl()],
            ),
          ),
          // Stored text shows even while a refresh runs or after it fails;
          // the failure screen is only for having nothing at all.
          if (state.hasValue)
            ..._content(context, state.requireValue)
          else if (state.hasError)
            _Failure(l10n: l10n)
          else
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator()),
            ),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, Hukamnama h) {
    final l10n = AppLocalizations.of(context)!;
    final punjabi = ref.watch(localeController) == 'pa';
    final scale = ref.watch(readerScaleProvider);
    final stale = !h.isFor(sgpcDayOf(ref.read(clockProvider)()));

    // The mirror's lines carry a meaning under each line and the pauses, so
    // they are read first. Without them, SGPC's own lines show as before, and
    // SGPC's meaning of the whole shabad below is the only meaning.
    final shabad = h.shabad;
    final lines = shabad?.lines ?? h.lines;
    final meaningBy = shabad?.credits[punjabi ? 'punjabi' : 'english'];

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
      readerDate(h.date, punjabi: punjabi),
    ].join(' · ');

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        sliver: SliverToBoxAdapter(
          child: _Column(
            children: [
              if (meta.isNotEmpty) Text(meta, style: AppType.callout),
              if (stale) ...[
                const SizedBox(height: 12),
                _Note(
                  text: l10n.hukamnama_not_out(
                    readerDate(h.date, punjabi: punjabi),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const _Actions(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      if (h.headingGurmukhi != null)
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
            child: _Line(line: lines[i], punjabi: punjabi, scale: scale),
          ),
        ),
      ),
      if (h.punjabiMeaning != null || h.englishMeaning != null)
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
                if (shabad != null && meaningBy != null)
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
                Center(
                  child: CupertinoButton(
                    onPressed: () => openLink(kHukamnamaSourceUrl),
                    child: Text(
                      l10n.text_source(kHukamnamaSourceName),
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
  const _Line({required this.line, required this.punjabi, required this.scale});

  final HukamnamaLine line;
  final bool punjabi;
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
    final meaning = punjabi
        ? (line.punjabi ?? line.english)
        : (line.english ?? line.punjabi);
    final roman = punjabi ? null : line.transliteration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText.rich(
          _gurmukhi(AppType.gurbani.copyWith(fontSize: 22 * scale)),
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
        if (meaning != null) ...[
          const SizedBox(height: 6),
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

class _Actions extends ConsumerWidget {
  const _Actions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final now = ref.watch(nowPlayingProvider);
    final playing = now.index == kMukhwakIndex && now.isPlaying;

    Widget pill({
      required IconData icon,
      required String label,
      required VoidCallback? onTap,
      bool primary = false,
      bool external = false,
      bool busy = false,
    }) =>
        Pressable(
          semanticLabel: label,
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

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        pill(
          icon: playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
          label: playing ? l10n.pause : l10n.listen,
          primary: true,
          onTap: () => togglePlayback(ref, kMukhwakIndex),
        ),
        InAppLink(
          url: kHukamnamaPdfPageUrl,
          builder: (context, opening, open) => pill(
            icon: CupertinoIcons.doc_text,
            label: l10n.sgpc_pdf,
            external: true,
            busy: opening,
            onTap: open,
          ),
        ),
      ],
    );
  }
}

class _TextSizeControl extends ConsumerWidget {
  const _TextSizeControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    ref.watch(readerScaleProvider);
    final scale = ref.read(readerScaleProvider.notifier);

    Widget button(String label, String semantic, bool enabled, VoidCallback f) {
      return Semantics(
        button: true,
        label: semantic,
        excludeSemantics: true,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        button('A−', l10n.smaller_text, scale.canShrink, scale.shrink),
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
  const _Failure({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
