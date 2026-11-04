import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/reminder_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/motion.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/models/reminder_settings.dart';
import 'package:live_darbar/src/models/reminder_time.dart';
import 'package:live_darbar/src/services/reminder_platform.dart';
import 'package:live_darbar/src/views/widgets/app_sheet.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';

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
/// on a 24-hour clock.
String reminderTimeLabel(BuildContext context, ReminderTime time) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: time.hour, minute: time.minute),
      alwaysUse24HourFormat: _uses24Hour(context),
    );

/// Held while a check decides, so 2 checks that start together (the launch,
/// and the first return to the front) cannot both ask.
var _deciding = false;

/// Asks about the daily reminder, once, if it is the right moment. Returns
/// whether the question was shown. It returns when the sheet closes.
///
/// The right moment is when all of these hold:
///
/// - The platform can show a reminder, and the app has not asked before.
/// - The app is on screen. A widget tap or Android Auto can start the app
///   with no screen, and a question shown then would use up the one time.
///   The app calls this again when it comes to the front.
/// - Home is the only page. A page on top (the reader, opened by a tap on the
///   widget) is where the listener is going, and a sheet would cover it. The
///   app asks on a later launch instead.
///
/// [settle] gives the home screen a moment to draw first.
Future<bool> showReminderPromptIfNeeded({
  required ProviderContainer container,
  required GlobalKey<NavigatorState> navigatorKey,
  Duration settle = const Duration(seconds: 1),
  bool Function()? isForeground,
}) async {
  if (_deciding) return false;
  if (!container.read(reminderPlatformProvider).isSupported) return false;

  _deciding = true;
  BuildContext context;
  try {
    var settings = await container.read(reminderProvider.future);
    if (settings.asked) return false;
    await Future<void>.delayed(settle);

    // The listener may have answered in About while this waited.
    settings = await container.read(reminderProvider.future);
    final foreground = isForeground?.call() ??
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final navigator = navigatorKey.currentState;
    final navigatorContext = navigatorKey.currentContext;
    if (settings.asked ||
        !foreground ||
        navigator == null ||
        navigatorContext == null ||
        !navigatorContext.mounted ||
        navigator.canPop()) {
      return false;
    }
    context = navigatorContext;

    await container.read(reminderProvider.notifier).markAsked();
  } finally {
    _deciding = false;
  }

  if (!context.mounted) return true;
  await showReminderPrompt(context);
  return true;
}

/// The first question, as a sheet the listener can wave away.
///
/// A sheet rather than a dialog, like the update offer: it never blocks the
/// kirtan that may already be playing, and a swipe down means "not now".
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final time =
        ref.watch(reminderProvider).value?.time ?? ReminderTime.standard;
    final failed = _problem != ReminderProblem.none;

    final message = switch (_problem) {
      ReminderProblem.none =>
        l10n.reminder_prompt_body(reminderTimeLabel(context, time)),
      ReminderProblem.blocked => l10n.reminder_blocked_hint,
      ReminderProblem.failed => l10n.reminder_failed_hint,
    };

    return _SheetFrame(
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
          child: Text(message, key: ValueKey(_problem), style: AppType.body),
        ),
        const SizedBox(height: 24),
        if (failed)
          _GoldButton(
            label: l10n.reminder_done,
            onTap: () => Navigator.of(context).pop(),
          )
        else ...[
          _GoldButton(
            label: l10n.reminder_prompt_yes,
            onTap: _busy ? null : _accept,
          ),
          const SizedBox(height: 4),
          _QuietButton(
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
  late ReminderTime _chosen =
      ref.read(reminderProvider).value?.time ?? ReminderTime.standard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _SheetFrame(
      children: [
        Text(l10n.reminder_time, style: AppType.title2),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            // Only the time of day is read, so the date is any date.
            initialDateTime: DateTime(2026, 1, 1, _chosen.hour, _chosen.minute),
            use24hFormat: _uses24Hour(context),
            onDateTimeChanged: (picked) =>
                _chosen = ReminderTime(picked.hour, picked.minute),
          ),
        ),
        const SizedBox(height: 16),
        _GoldButton(
          label: l10n.reminder_done,
          onTap: () {
            // The wheel can spin while the sheet closes. Save what it shows
            // now.
            unawaited(ref.read(reminderProvider.notifier).setTime(_chosen));
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

/// The sheet's surface, grabber and padding, as the update sheet draws them.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const ShapeDecoration(
        color: Palette.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: Palette.border),
        ),
      ),
      child: SafeArea(
        top: false,
        // Scrolls when it does not fit, on a small phone or at a large text
        // size.
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
            child: AnimatedSize(
              duration: Motion.quick,
              curve: Motion.easeOut,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Palette.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 1 gold button of the sheet.
class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: Palette.gold,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            label,
            style: AppType.headline.copyWith(color: Palette.onGold),
          ),
        ),
      ),
    );
  }
}

/// The quiet way out: words only, with a target of 48 points.
class _QuietButton extends StatelessWidget {
  const _QuietButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppType.callout.copyWith(color: Palette.muted),
          ),
        ),
      ),
    );
  }
}
