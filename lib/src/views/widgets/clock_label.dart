import 'package:flutter/material.dart';

/// Whether the time is written on a 24-hour clock: when the phone is set to
/// one, and in Punjabi, whose Material format is 24-hour ("19:00"). Every time
/// the app writes asks this, so the reminder and the clock on Home never
/// disagree.
///
/// The web build never hears the computer's setting: Flutter's web engine
/// reports 12-hour, so English on the web shows "7:43 PM".
bool uses24HourClock(BuildContext context) {
  final format = MaterialLocalizations.of(context).timeOfDayFormat(
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return hourFormat(of: format) != HourFormat.h;
}

/// [hour] and [minute] as the listener writes the time: "7:00 AM", or "7:00"
/// and "19:00" on a 24-hour clock. It names no zone.
String clockLabel(BuildContext context, int hour, int minute) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: hour, minute: minute),
      alwaysUse24HourFormat: uses24HourClock(context),
    );
