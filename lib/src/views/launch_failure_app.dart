import 'package:flutter/material.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/app_theme.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/core/text_scale.dart';
import 'package:live_darbar/src/views/widgets/sheet_parts.dart';

/// What the listener sees when the app could not start.
///
/// A static app of its own, with nothing in it that start-up could have
/// broken: no providers, no saved settings, no network. It says the app did
/// not start, what to do, and offers one gold Retry. No exception, no stack,
/// no alarm colour: the listener has done nothing wrong.
///
/// The language the listener chose is saved in the settings that may be what
/// failed, so the screen shows both languages. Each reads on its own.
class LaunchFailureApp extends StatelessWidget {
  const LaunchFailureApp({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Darbar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.material,
      darkTheme: AppTheme.material,
      themeMode: ThemeMode.dark,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: kMaxTextScale,
        child: child ?? const SizedBox.shrink(),
      ),
      home: _LaunchFailure(onRetry: onRetry),
    );
  }
}

class _LaunchFailure extends StatelessWidget {
  const _LaunchFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Looked up by name, not from the context: no localization is set up when
    // start-up fails.
    final en = lookupAppLocalizations(const Locale('en'));
    final pa = lookupAppLocalizations(const Locale('pa'));
    // Gurmukhi takes no letter spacing and a taller line.
    TextStyle gurmukhi(TextStyle style) =>
        style.copyWith(letterSpacing: 0, height: 1.5);

    return Scaffold(
      backgroundColor: Palette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                // The words scroll when they do not fit, at a large text size.
                // Retry stays under them, in reach.
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(en.launch_failed_title, style: AppType.title),
                          const SizedBox(height: 8),
                          Text(en.launch_failed_body, style: AppType.callout),
                          const SizedBox(height: 28),
                          Text(
                            pa.launch_failed_title,
                            style: gurmukhi(AppType.title),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            pa.launch_failed_body,
                            style: gurmukhi(AppType.callout),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
                  child: GoldSheetButton(
                    label: '${en.retry} · ${pa.retry}',
                    onTap: onRetry,
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
