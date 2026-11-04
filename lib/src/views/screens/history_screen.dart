import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/history_year_controller.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/history_calendar.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/core/reader_numbers.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:live_darbar/src/views/widgets/app_nav_bar.dart';
import 'package:live_darbar/src/views/widgets/history_setting.dart';
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
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  /// The widest the page runs. The nav bar lines up with it on the web.
  static const maxWidth = 540.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final punjabi = ref.watch(localeController) == 'pa';
    final notifies = ref.watch(reminderPlatformProvider).isSupported;
    final loaded = ref.watch(historyYearProvider);
    final year = loaded.value;

    return Scaffold(
      backgroundColor: Palette.background,
      body: CustomScrollView(
        slivers: [
          AppNavBar(title: l10n.history_screen_title, contentWidth: maxWidth),
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                            child: Center(child: CupertinoActivityIndicator()),
                          ),
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
class _DayRow extends StatelessWidget {
  const _DayRow({
    super.key,
    required this.day,
    required this.tense,
    required this.punjabi,
  });

  final HistoryDay day;
  final HistoryTense tense;
  final bool punjabi;

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
    final weekday = DateFormat('E', locale).format(day.first);
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
