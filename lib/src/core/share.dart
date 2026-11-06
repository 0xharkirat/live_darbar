import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/core/share_text.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the system share sheet with [text].
///
/// [context] is the button that asked: an iPad and a Mac show the sheet as a
/// popover pointing at it, and need its place on screen.
///
/// When there is no sheet (a desktop browser without the Web Share API, or a
/// platform error), the text goes to the clipboard and a short note says so
/// with [copied], so the tap still does something useful.
Future<void> shareText(
  BuildContext context,
  String text, {
  required String copied,
  String? subject,
}) async {
  final box = context.findRenderObject();
  final origin = box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        sharePositionOrigin: origin,
        // Our fallback is the clipboard, not an email draft.
        mailToFallbackEnabled: false,
      ),
    );
    // Any result (shared, dismissed, or unknown) means the sheet was tried.
    // `unavailable` only says the platform cannot report the outcome, so it
    // is not a failure and must not overwrite the clipboard.
    return;
  } catch (e) {
    if (!kReleaseMode) debugPrint('[share] no share sheet: $e');
  }
  try {
    await Clipboard.setData(ClipboardData(text: text));
  } catch (e) {
    if (!kReleaseMode) debugPrint('[share] clipboard refused: $e');
    return;
  }
  if (messenger == null || !messenger.mounted) return;
  messenger.showSnackBar(SnackBar(content: Text(copied)));
}

/// Opens the share sheet with a link to the app: the site and both stores.
/// About and Home's footer both use it.
Future<void> shareApp(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return shareText(
    context,
    appShareText(
      message: l10n.share_app_message,
      playLabel: l10n.google_play,
      appStoreLabel: l10n.apple_store,
    ),
    subject: l10n.app_title,
    copied: l10n.link_copied,
  );
}
