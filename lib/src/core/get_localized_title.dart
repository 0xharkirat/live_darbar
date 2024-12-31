import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

String getLocalizedTitle(String title, BuildContext context) {
  final localizations = AppLocalizations.of(context)!;
  switch (title) {
    case 'Live Kirtan':
      return localizations.live_kirtan;
    case 'Mukhwak':
      return localizations.mukhwak;
    case 'Mukhwak Katha':
      return localizations.mukhwak_katha;
    default:
      return title; // Fallback to the original title if no match
  }
}

