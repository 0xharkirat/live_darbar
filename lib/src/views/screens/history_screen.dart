import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/history_year_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/fuzzy_search.dart';
import 'package:live_darbar/src/core/history_calendar.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/core/reader_numbers.dart';
import 'package:live_darbar/src/models/sgpc_event.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:live_darbar/src/views/widgets/app_nav_bar.dart';
import 'package:live_darbar/src/views/widgets/history_setting.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';
import 'package:live_darbar/src/views/widgets/settings_group.dart';

/// Sikh history for the whole Nanakshahi year, like a calendar.
///
/// Home shows 1 quiet line for today and opens this page. Here are every
/// day of the year that SGPC's calendar lists, grouped by month. Past days
/// are muted, today is highlighted, and the days to come follow in the
/// brighter text. The page opens scrolled to today.
///
/// The switch for the "Today in Sikh history" notification is here as well as
/// in About, because this is where the listener reads about the days.
///
/// ## Search
///
/// A quiet field sits under the title and stays there while the page scrolls,
/// because the page opens in the middle of the year and the top is a long way
/// up. It finds an event by its name, in English or in Punjabi, whichever
/// language the app is in (see [FuzzyIndex]). While the field holds text, the
/// rows that fit replace the months, best first, each with its date and month.
/// Clearing the field brings the months back, opened on today again.
///
/// It searches the events of the year that the page lists, which is every
/// event of the Nanakshahi year that the bundled calendar covers and that has
/// been checked. Nothing goes to the network.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  /// The widest the page runs. The nav bar lines up with it on the web.
  static const maxWidth = 540.0;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  /// What the field holds, trimmed. Empty means no search.
  String _query = '';

  HistoryYear? _indexedYear;
  FuzzyIndex<SgpcEvent>? _index;
  String? _resultsQuery;
  List<SgpcEvent> _results = const [];

  @override
  void initState() {
    super.initState();
    _text.addListener(_onText);
  }

  @override
  void dispose() {
    _text
      ..removeListener(_onText)
      ..dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Runs for a letter typed, a letter pasted, the clear button, and a move of
  /// the cursor. Only a change of the words rebuilds the page.
  void _onText() {
    final query = _text.text.trim();
    if (query == _query) return;
    setState(() => _query = query);
    // The results start at the top of the list, not wherever the months had
    // been scrolled to. Clearing the field needs no jump: the months open on
    // today by themselves.
    if (query.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        if (_scroll.offset > 0) _scroll.jumpTo(0);
      });
    }
  }

  /// The events that fit the query, best first. The index is built once for a
  /// year, and the search runs once for a query.
  List<SgpcEvent> _search(HistoryYear year) {
    if (!identical(year, _indexedYear)) {
      _indexedYear = year;
      _resultsQuery = null;
      _index = FuzzyIndex<SgpcEvent>(
        [for (final day in year.days) ...day.events],
        texts: (event) => [event.titleEn, event.titlePa],
      );
    }
    if (_resultsQuery != _query) {
      _resultsQuery = _query;
      _results = _index!.search(_query);
    }
    return _results;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final punjabi = ref.watch(localeController) == 'pa';
    final notifies = ref.watch(reminderPlatformProvider).isSupported;
    final loaded = ref.watch(historyYearProvider);
    final year = loaded.value;
    final searching = year != null && _query.isNotEmpty;
    final searchHeight = _SearchBar.heightOf(context);

    return Scaffold(
      backgroundColor: Palette.background,
      body: CustomScrollView(
        controller: _scroll,
        // A swipe on the results puts the keyboard away.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          AppNavBar(
            title: l10n.history_screen_title,
            contentWidth: HistoryScreen.maxWidth,
          ),
          if (year != null)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchBarDelegate(
                height: searchHeight,
                child: _SearchBar(controller: _text, focusNode: _focus),
              ),
            ),
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: HistoryScreen.maxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (searching)
                          _SearchResults(
                            year: year,
                            results: _search(year),
                            query: _query,
                            punjabi: punjabi,
                          )
                        else ...[
                          if (year != null)
                            Text(
                              l10n.history_screen_intro(
                                readerNumber(year.number, punjabi: punjabi),
                              ),
                              style: AppType.callout,
                            ),
                          // The same switch as in About.
                          if (notifies) ...[
                            const SizedBox(height: 16),
                            const SettingsGroup(children: [HistorySetting()]),
                          ],
                          const SizedBox(height: 8),
                          if (year != null)
                            _YearList(year: year, punjabi: punjabi)
                          else if (loaded.hasValue || loaded.hasError)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                l10n.history_empty,
                                textAlign: TextAlign.center,
                                style: AppType.callout,
                              ),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 48),
                              child: Center(
                                child: CupertinoActivityIndicator(),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps the search field in place under the nav bar, with the page's own
/// background behind it. A hairline shows under it only while rows pass
/// beneath, so the field sits quiet on the canvas at the top of the page.
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  const _SearchBarDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.background,
        border: overlapsContent
            ? const Border(bottom: BorderSide(color: Palette.border))
            : null,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: HistoryScreen.maxWidth),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SearchBarDelegate oldDelegate) =>
      height != oldDelegate.height || child != oldDelegate.child;
}

/// The search field: a magnifier, the words, and a way to clear them.
///
/// It is a quiet surface like the groups on the page, with no label above it
/// and no Cancel. Nothing animates as the words change. Autocorrect is off,
/// because it would "correct" a Punjabi word written in Latin letters into an
/// English one.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  /// The space above the field, and below it.
  static const _above = 4.0;
  static const _below = 8.0;

  /// The space above and below the words inside the field.
  static const _inner = 10.0;

  /// Tall enough for a line of Gurmukhi, which has marks above and below.
  static const _lineHeight = 1.6;

  /// No letter spacing: Cupertino's text theme gives a field its own tracking
  /// of -0.41, which would push the vowel signs of Gurmukhi off their letters.
  static TextStyle get _style =>
      AppType.body.copyWith(height: _lineHeight, letterSpacing: 0);

  /// How tall the bar is. It follows the text size, so a larger setting grows
  /// the field and nothing is cut.
  static double heightOf(BuildContext context) {
    final line =
        MediaQuery.textScalerOf(context).scale(_style.fontSize!) * _lineHeight;
    return _above + line + 2 * _inner + _below;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, _above, 20, _below),
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, field) => DecoratedBox(
          decoration: ShapeDecoration(
            color: Palette.surface,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: focusNode.hasFocus
                    ? Palette.gold.withValues(alpha: 0.6)
                    : Palette.border,
              ),
            ),
          ),
          child: field,
        ),
        child: Semantics(
          label: l10n.history_search_hint,
          child: CupertinoTextField.borderless(
            controller: controller,
            focusNode: focusNode,
            placeholder: l10n.history_search_hint,
            placeholderStyle: _style.copyWith(color: Palette.muted),
            style: _style,
            cursorColor: Palette.gold,
            keyboardAppearance: Brightness.dark,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            padding: const EdgeInsetsDirectional.fromSTEB(0, _inner, 8, _inner),
            prefix: const Padding(
              padding: EdgeInsetsDirectional.only(start: 14, end: 8),
              child: Icon(
                CupertinoIcons.search,
                size: 18,
                color: Palette.muted,
              ),
            ),
            suffixMode: OverlayVisibilityMode.editing,
            suffix: _ClearButton(
              label: l10n.history_search_clear,
              onTap: controller.clear,
            ),
            onSubmitted: (_) => focusNode.unfocus(),
          ),
        ),
      ),
    );
  }
}

/// Empties the search field. A 44 point target around a small mark, with the
/// press fill that small targets take.
class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: const SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: PressFill(
              pressedColor: Palette.surfaceHigh,
              shape: CircleBorder(),
              child: Center(
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 18,
                  color: Palette.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The events that fit the words in the search field, best first, each on its
/// own row with its date and month. The months and their headings are not
/// shown.
///
/// A screen reader hears how many events fit each time the list changes, and
/// then the rows. With none, the message says so and says what to try.
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.year,
    required this.results,
    required this.query,
    required this.punjabi,
  });

  final HistoryYear year;
  final List<SgpcEvent> results;
  final String query;
  final bool punjabi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Semantics(
          liveRegion: true,
          child: Text(
            l10n.history_search_empty(query),
            textAlign: TextAlign.center,
            style: AppType.callout,
          ),
        ),
      );
    }

    final rows = [
      for (final event in results)
        HistoryDay(first: event.first, last: event.last, events: [event]),
    ];
    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.history_search_count(results.length),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, day) in rows.indexed) ...[
            // No hairline against today's wash: it would run into its edge.
            if (i > 0 &&
                day.tense(year.today) != HistoryTense.today &&
                rows[i - 1].tense(year.today) != HistoryTense.today)
              const _Hairline(),
            _DayRow(
              key: ValueKey(day.events.single.id),
              day: day,
              tense: day.tense(year.today),
              punjabi: punjabi,
              showMonth: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// The months of the year, opened on the row of today.
///
/// Every month is built at once, about 120 rows for the year, so the row to
/// scroll to is always there. The list stays clear until the scroll is set, so
/// the page never shows the top and then jumps.
class _YearList extends StatefulWidget {
  const _YearList({required this.year, required this.punjabi});

  final HistoryYear year;
  final bool punjabi;

  @override
  State<_YearList> createState() => _YearListState();
}

class _YearListState extends State<_YearList> {
  final _focusKey = GlobalKey();
  bool _placed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focus = _focusKey.currentContext;
      if (focus != null) {
        // Today a little below the top, so a few past days show above it.
        Scrollable.ensureVisible(focus, alignment: 0.2, duration: Duration.zero);
      }
      setState(() => _placed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final year = widget.year;
    final focus = year.focus;

    return AnimatedOpacity(
      opacity: _placed ? 1 : 0,
      duration: Motion.quick,
      curve: Motion.easeOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (m, month) in year.months.indexed) ...[
            _MonthHeading(month: month, punjabi: widget.punjabi, first: m == 0),
            for (final (i, day) in month.days.indexed) ...[
              // No hairline against today's wash: it would run into its edge.
              if (i > 0 &&
                  day.tense(year.today) != HistoryTense.today &&
                  month.days[i - 1].tense(year.today) != HistoryTense.today)
                const _Hairline(),
              _DayRow(
                key: identical(day, focus) ? _focusKey : null,
                day: day,
                tense: day.tense(year.today),
                punjabi: widget.punjabi,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MonthHeading extends StatelessWidget {
  const _MonthHeading({
    required this.month,
    required this.punjabi,
    required this.first,
  });

  final HistoryMonth month;
  final bool punjabi;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final name = DateFormat(
      'MMMM',
      punjabi ? 'pa' : 'en',
    ).format(DateTime.utc(month.year, month.month));
    final text = '$name ${readerNumber(month.year, punjabi: punjabi)}';

    return Padding(
      padding: EdgeInsets.fromLTRB(12, first ? 12 : 32, 12, 8),
      child: Semantics(
        header: true,
        child: Text(punjabi ? text : text.toUpperCase(), style: AppType.eyebrow),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(left: 12),
        child: Divider(height: 1, thickness: 1, color: Palette.border),
      );
}

/// One day with an event: its date on the left, its titles on the right.
///
/// A past day is muted, today sits on a gold wash with its date in gold, and a
/// day to come is in the brighter text. The titles wrap and are never cut.
/// A screen reader reads each row once: the date, "Today" if it is, then the
/// titles.
///
/// In the months, a heading above the rows names the month. Among search
/// results there are no headings, so the line under the date adds the month:
/// "Sun, Nov".
class _DayRow extends StatelessWidget {
  const _DayRow({
    super.key,
    required this.day,
    required this.tense,
    required this.punjabi,
    this.showMonth = false,
  });

  final HistoryDay day;
  final HistoryTense tense;
  final bool punjabi;

  /// Name the month under the date, for a row away from its month heading.
  final bool showMonth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = punjabi ? 'pa' : 'en';
    final today = tense == HistoryTense.today;
    final past = tense == HistoryTense.past;
    final titles = [for (final e in day.events) e.title(punjabi: punjabi)];

    final number = readerNumber(day.first.day, punjabi: punjabi);
    final dateText = day.isRange
        ? '$number–${readerNumber(day.last.day, punjabi: punjabi)}'
        : number;
    final weekday =
        DateFormat(showMonth ? 'E, MMM' : 'E', locale).format(day.first);
    final spoken = [
      readerDate(day.first, punjabi: punjabi, weekday: true),
      if (day.isRange) readerDate(day.last, punjabi: punjabi),
    ].join(' – ');

    final ink = past ? Palette.muted : Palette.foreground;

    return Semantics(
      container: true,
      label: [spoken, if (today) l10n.history_today, ...titles].join('. '),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: today
              ? ShapeDecoration(
                  color: Palette.gold.withValues(alpha: 0.12),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                )
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateText,
                      style: AppType.title2.copyWith(
                        fontSize: 22,
                        color: today ? Palette.gold : ink,
                      ),
                    ),
                    Text(
                      weekday,
                      style: AppType.footnote.copyWith(color: Palette.muted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (today) ...[
                      Text(
                        punjabi
                            ? l10n.history_today
                            : l10n.history_today.toUpperCase(),
                        style: AppType.eyebrow,
                      ),
                      const SizedBox(height: 2),
                    ],
                    for (final (i, title) in titles.indexed) ...[
                      if (i > 0) const SizedBox(height: 6),
                      Text(title, style: AppType.body.copyWith(color: ink)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
