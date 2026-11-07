import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/reminder_controller.dart';
import 'package:live_darbar/src/core/amritsar_time.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/reminder_settings.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:live_darbar/src/views/widgets/app_sheet.dart';
import 'package:live_darbar/src/views/widgets/sheet_parts.dart';

/// Whether the time is written on a 24-hour clock: when the phone is set to
/// one, and in Punjabi, whose Material format is 24-hour ("19:00"). The label
/// and the wheel both ask this, so they never disagree.
bool _uses24Hour(BuildContext context) {
  final format = MaterialLocalizations.of(context).timeOfDayFormat(
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return hourFormat(of: format) != HourFormat.h;
}

/// [time] as the listener writes the time: "7:00 AM", or "7:00" and "19:00"
/// on a 24-hour clock. It names no zone.
String reminderClockLabel(BuildContext context, ReminderTime time) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: time.hour, minute: time.minute),
      alwaysUse24HourFormat: _uses24Hour(context),
    );

/// When the reminder comes, for the listener to read.
///
/// A time on the listener's own clock is just the time: "9:30 PM". A time in
/// Amritsar names the place and shows the listener's own clock for the same
/// moment today: "7:00 AM in Amritsar, 12:30 PM here". The second part leaves
/// out when the listener's clock reads the same.
String reminderWhenLabel(
  BuildContext context,
  WidgetRef ref,
  ReminderTime time,
) {
  if (time.zone == ReminderZone.local) return reminderClockLabel(context, time);
  final l10n = AppLocalizations.of(context)!;
  final here = onListenersClock(
    time,
    sgpcDayOf(ref.read(clockProvider)()),
    offset: ref.read(localOffsetProvider),
  );
  final amritsar =
      reminderClockLabel(context, ReminderTime(time.hour, time.minute));
  return here.minutes == time.minutes
      ? l10n.reminder_time_amritsar_only(amritsar)
      : l10n.reminder_time_amritsar(
          amritsar, reminderClockLabel(context, here));
}

/// How long the reader must be calm, on top and at rest, before the question
/// appears. The page has slid in and the listener has seen the Hukamnama.
final reminderSettleProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 600),
);

/// The containers that have a check running, from the moment it starts until
/// it has asked or given up, so 2 checks cannot both ask.
final _asking = Expando<bool>('reminder check');

/// Stops a check that is waiting. The page calls it when it closes, so the
/// check leaves no timer behind and never opens a sheet for a page that is
/// gone. The reader's question and Home's "what's new" both use it.
class CancelAsk {
  bool _cancelled = false;
  Timer? _timer;
  Completer<void>? _sleeping;

  bool get cancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    _timer?.cancel();
    final sleeping = _sleeping;
    if (sleeping != null && !sleeping.isCompleted) sleeping.complete();
  }

  /// Waits [duration], or less when cancelled.
  Future<void> sleep(Duration duration) {
    if (_cancelled) return Future<void>.value();
    final sleeping = _sleeping = Completer<void>();
    _timer = Timer(duration, () {
      if (!sleeping.isCompleted) sleeping.complete();
    });
    return sleeping.future;
  }
}

/// Asks about the daily reminder, once, when the listener opens the Hukamnama
/// reader. Returns whether the question was shown, when its sheet closes.
///
/// [context] is the reader's. The question belongs here and not on Home: the
/// listener has just chosen to read the Hukamnama, so a reminder to read it
/// makes sense. On Home at launch it competed with the update offer, and lost.
///
/// It waits for the right moment, and does not use up the one question before
/// it shows:
///
/// - The reader is the top page and has finished sliding in. A sheet over it
///   (the update offer, which Home opens) is waited out, not skipped. The
///   question is marked as asked only when it appears.
/// - The app is on screen. A widget tap can start the app with no screen.
/// - The platform can show a reminder, and the app has not asked before.
///
/// It gives up after [giveUpAfter]. The next time the reader opens asks again.
Future<bool> askAboutReminderOnFirstOpen(
  BuildContext context, {
  Duration poll = const Duration(milliseconds: 250),
  Duration giveUpAfter = const Duration(minutes: 2),
  bool Function()? isForeground,
  CancelAsk? cancel,
}) async {
  cancel ??= CancelAsk();
  final container = ProviderScope.containerOf(context, listen: false);
  if (_asking[container] ?? false) return false;
  if (!container.read(reminderPlatformProvider).isSupported) return false;
  final route = ModalRoute.of(context);
  final settle = container.read(reminderSettleProvider);

  bool ready() {
    if (!context.mounted || cancel!.cancelled) return false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final foreground = isForeground?.call() ??
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    return foreground &&
        (route?.isCurrent ?? true) &&
        (route?.animation?.isCompleted ?? true);
  }

  _asking[container] = true;
  try {
    if ((await container.read(reminderProvider.future)).asked) return false;

    var calm = Duration.zero;
    for (var waited = Duration.zero;; waited += poll) {
      if (!context.mounted || cancel.cancelled || waited >= giveUpAfter) {
        return false;
      }
      if (!ready()) {
        calm = Duration.zero;
      } else if (calm >= settle) {
        break;
      } else {
        calm += poll;
      }
      await cancel.sleep(poll);
    }

    // The listener may have answered with the bell while this waited.
    final settings = await container.read(reminderProvider.future);
    if (settings.asked || !context.mounted || cancel.cancelled) return false;
    await container.read(reminderProvider.notifier).markAsked();
    if (!context.mounted) return true;
  } finally {
    _asking[container] = false;
  }

  await showReminderPrompt(context);
  return true;
}

/// The reminder's sheet.
///
/// The first time, it is the question: "Remind me" or "Not now". The bell on
/// the reader opens the same sheet at any time. With the reminder on, it shows
/// when the reminder comes, with a way to change the time or turn it off.
Future<void> showReminderPrompt(BuildContext context) =>
    showAppSheet<void>(context, (_) => const ReminderPrompt());

/// Where the listener picks the time of the reminder.
Future<void> showReminderTimeSheet(BuildContext context) =>
    showAppSheet<void>(context, (_) => const _ReminderTimeSheet());

class ReminderPrompt extends ConsumerStatefulWidget {
  const ReminderPrompt({super.key});

  @override
  ConsumerState<ReminderPrompt> createState() => _ReminderPromptState();
}

class _ReminderPromptState extends ConsumerState<ReminderPrompt> {
  /// Whether the reminder was on when the sheet opened. The sheet keeps its
  /// shape while it closes after "Remind me", so it does not flash the other.
  late final bool _wasOn = ref.read(reminderProvider).value?.enabled ?? false;

  bool _busy = false;
  ReminderProblem _problem = ReminderProblem.none;

  Future<void> _accept() async {
    setState(() => _busy = true);
    // The phone's own question, if it has one, appears now.
    final problem = await ref.read(reminderProvider.notifier).turnOn();
    if (!mounted) return;
    if (problem == ReminderProblem.none) {
      Navigator.of(context).pop();
    } else {
      // Say why, instead of closing as if it had worked.
      setState(() {
        _busy = false;
        _problem = problem;
      });
    }
  }

  Future<void> _turnOff() async {
    final navigator = Navigator.of(context);
    unawaited(ref.read(reminderProvider.notifier).turnOff());
    navigator.pop();
  }

  void _changeTime() {
    // The time sheet takes this one's place, so a "Done" ends the visit.
    final navigator = Navigator.of(context);
    navigator.pop();
    unawaited(showReminderTimeSheet(navigator.context));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(reminderProvider).value;
    final when = reminderWhenLabel(
      context,
      ref,
      settings?.time ?? ReminderTime.standard,
    );
    final failed = _problem != ReminderProblem.none;

    // A reminder that is on can still be blocked by the phone, and the sheet
    // says so instead of "on".
    final liveProblem = _wasOn && !failed
        ? (settings?.problem ?? ReminderProblem.none)
        : ReminderProblem.none;
    final shown = failed ? _problem : liveProblem;
    final message = switch (shown) {
      ReminderProblem.none =>
        _wasOn ? l10n.reminder_on_body(when) : l10n.reminder_prompt_body(when),
      ReminderProblem.blocked => l10n.reminder_blocked_hint,
      ReminderProblem.failed => l10n.reminder_failed_hint,
    };

    return SheetFrame(
      children: [
        Text(l10n.reminder_prompt_title, style: AppType.title2),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: Motion.quick,
          switchInCurve: Motion.easeOut,
          switchOutCurve: Motion.easeOut,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, if (current != null) current],
          ),
          child: Text(message, key: ValueKey(shown), style: AppType.body),
        ),
        const SizedBox(height: 24),
        if (failed)
          GoldSheetButton(
            label: l10n.reminder_done,
            onTap: () => Navigator.of(context).pop(),
          )
        else if (_wasOn) ...[
          GoldSheetButton(
            label: l10n.reminder_change_time,
            onTap: _changeTime,
          ),
          const SizedBox(height: 4),
          QuietSheetButton(
            label: l10n.reminder_turn_off,
            onTap: _turnOff,
          ),
        ] else ...[
          GoldSheetButton(
            label: l10n.reminder_prompt_yes,
            onTap: _busy ? null : _accept,
          ),
          const SizedBox(height: 4),
          QuietSheetButton(
            label: l10n.reminder_prompt_no,
            onTap: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ],
    );
  }
}

class _ReminderTimeSheet extends ConsumerStatefulWidget {
  const _ReminderTimeSheet();

  @override
  ConsumerState<_ReminderTimeSheet> createState() => _ReminderTimeSheetState();
}

class _ReminderTimeSheetState extends ConsumerState<_ReminderTimeSheet> {
  late final ReminderTime _current =
      ref.read(reminderProvider).value?.time ?? ReminderTime.standard;

  /// What the wheel starts on: the time on the listener's own clock today. A
  /// time in Amritsar shows as its equivalent here.
  late final ReminderTime _start = onListenersClock(
    _current,
    sgpcDayOf(ref.read(clockProvider)()),
    offset: ref.read(localOffsetProvider),
  );

  /// Set only when the listener turns the wheel. "Done" without a turn keeps
  /// the time as it was, in its own zone.
  ReminderTime? _picked;

  /// The time on the wheel, said in Amritsar: "1:30 PM here is 8:00 AM in
  /// Amritsar". It follows the wheel, so a listener abroad can pick a time by
  /// the Darbar Sahib's clock. Null where the 2 clocks read the same.
  String? _inAmritsar(AppLocalizations l10n) {
    final here = _picked ?? _start;
    final there = inAmritsar(
      here,
      sgpcDayOf(ref.read(clockProvider)()),
      offset: ref.read(localOffsetProvider),
    );
    if (there.minutes == here.minutes) return null;
    return l10n.reminder_wheel_amritsar(
      reminderClockLabel(context, here),
      reminderClockLabel(context, ReminderTime(there.hour, there.minute)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final amritsar = _current.zone == ReminderZone.amritsar;

    return SheetFrame(
      children: [
        Text(l10n.reminder_time, style: AppType.title2),
        if (amritsar) ...[
          const SizedBox(height: 8),
          Text(
            l10n.reminder_time_note(reminderWhenLabel(context, ref, _current)),
            style: AppType.body,
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            // Only the time of day is read, so the date is any date.
            initialDateTime: DateTime(2026, 1, 1, _start.hour, _start.minute),
            use24hFormat: _uses24Hour(context),
            // Each tick redraws the line under the wheel, with no animation:
            // it changes as often as the wheel clicks.
            onDateTimeChanged: (picked) => setState(
              () => _picked = ReminderTime(picked.hour, picked.minute),
            ),
          ),
        ),
        if (_inAmritsar(l10n) case final line?)
          Text(
            line,
            textAlign: TextAlign.center,
            style: AppType.callout.copyWith(
              color: Palette.gold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        const SizedBox(height: 16),
        GoldSheetButton(
          label: l10n.reminder_done,
          onTap: () {
            // The wheel can spin while the sheet closes. Save what it shows
            // now.
            final picked = _picked;
            if (picked != null) {
              unawaited(ref.read(reminderProvider.notifier).setTime(picked));
            }
            Navigator.of(context).pop();
          },
        ),
        if (!amritsar) ...[
          const SizedBox(height: 4),
          QuietSheetButton(
            label: l10n.reminder_use_amritsar,
            onTap: () {
              unawaited(
                ref
                    .read(reminderProvider.notifier)
                    .setTime(ReminderTime.standard),
              );
              Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}
