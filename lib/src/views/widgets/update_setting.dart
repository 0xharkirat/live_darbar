import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/update_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/app_version.dart';
import 'package:live_darbar/src/core/palette.dart';
import 'package:live_darbar/src/views/widgets/busy_icon.dart';
import 'package:live_darbar/src/views/widgets/pressable.dart';
import 'package:live_darbar/src/views/widgets/update_sheet.dart';

/// The "Check for updates" row of the About group.
///
/// The app offers a new version once, at launch. A listener who declined it,
/// or who heard about a release from a friend, can ask here. A tap reads the
/// release file again and then does 1 of 3 things: it opens the update sheet,
/// says this is the newest version, or says it could not check. The line
/// under the title shows the version until then, so the row also answers
/// "which version do I have?".
///
/// The About screen shows it only in the apps. On the web a reload is the
/// update.
class UpdateSetting extends ConsumerStatefulWidget {
  const UpdateSetting({super.key});

  @override
  ConsumerState<UpdateSetting> createState() => _UpdateSettingState();
}

enum _Result { latest, failed }

class _UpdateSettingState extends ConsumerState<UpdateSetting> {
  bool _checking = false;
  _Result? _result;

  Future<void> _check() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _result = null;
    });
    try {
      final update = await ref.read(updateController.notifier).checkNow();
      if (!mounted) return;
      setState(() => _checking = false);
      if (update == null) {
        setState(() => _result = _Result.latest);
      } else {
        await showUpdateSheet(context, update);
      }
    } on UpdateCheckFailed {
      if (mounted) {
        setState(() {
          _checking = false;
          _result = _Result.failed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final version = ref.watch(appVersionProvider).value;

    final detail = switch (_result) {
      _Result.latest when version != null => l10n.update_check_latest(version),
      _Result.failed => l10n.update_check_failed,
      _ when version != null => l10n.update_version(version),
      _ => null,
    };

    return Pressable(
      scale: 1,
      semanticLabel: l10n.update_check_title,
      semanticValue: detail,
      onTap: _checking
          ? null
          : () {
              HapticFeedback.selectionClick();
              _check();
            },
      child: PressFill(
        pressedColor: Palette.surfaceHigh,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  BusyIcon(
                    busy: _checking,
                    icon: CupertinoIcons.arrow_down_circle,
                    size: 20,
                    color: Palette.gold,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.update_check_title, style: AppType.body),
                        if (detail != null)
                          Text(
                            detail,
                            style: AppType.footnote.copyWith(
                              color: _result == _Result.failed
                                  ? Palette.danger
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    size: 15,
                    color: Palette.faint,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
