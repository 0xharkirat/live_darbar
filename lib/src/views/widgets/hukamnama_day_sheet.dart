import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_darbar/l10n/app_localizations.dart';
import 'package:live_darbar/src/controllers/locale_controller.dart';
import 'package:live_darbar/src/core/app_type.dart';
import 'package:live_darbar/src/core/clock.dart';
import 'package:live_darbar/src/core/hukamnama_archive.dart';
import 'package:live_darbar/src/core/platform.dart';
import 'package:live_darbar/src/core/reader_numbers.dart';
import 'package:live_darbar/src/models/sgpc_day.dart';
import 'package:live_darbar/src/views/widgets/app_sheet.dart';
import 'package:live_darbar/src/views/widgets/sheet_parts.dart';

/// Asks the listener which earlier day to read, in a sheet with a date wheel.
///
/// [shown] is the earlier day the reader shows now, or null on today's reader.
/// The wheel starts on [shown], or on yesterday, the first day there is to
/// read, and it runs from the floor of the archive to today (see
/// [hukamnamaArchiveFloor]). "Open" and "Yesterday" close the sheet with the
/// day, an SGPC day as UTC midnight. A close by any other way gives null.
Future<DateTime?> showHukamnamaDaySheet(
  BuildContext context, {
  DateTime? shown,
}) =>
    showAppSheet<DateTime>(context, (_) => HukamnamaDaySheet(shown: shown));

/// The sheet behind [showHukamnamaDaySheet].
class HukamnamaDaySheet extends ConsumerStatefulWidget {
  const HukamnamaDaySheet({super.key, this.shown});

  final DateTime? shown;

  @override
  ConsumerState<HukamnamaDaySheet> createState() => _HukamnamaDaySheetState();
}

class _HukamnamaDaySheetState extends ConsumerState<HukamnamaDaySheet> {
  /// SGPC's day now, read once: the sheet is open for seconds, not past
  /// midnight at Amritsar.
  late final DateTime _today = sgpcDayOf(ref.read(clockProvider)());
  late final bool _web = ref.read(isWebProvider);
  late final DateTime _floor = hukamnamaArchiveFloor(_today, web: _web);

  /// The day the wheel starts on, held inside the wheel's range.
  late DateTime _picked = pickerDayOf(_start());

  DateTime _start() {
    final wanted = widget.shown ?? previousSgpcDay(_today);
    if (wanted.isBefore(_floor)) return _floor;
    return wanted.isAfter(_today) ? _today : wanted;
  }

  void _close(DateTime day) => Navigator.of(context).pop(day);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final punjabi = ref.watch(localeController) == 'pa';
    final body = _web
        ? l10n.archive_body_web(
            readerNumber(kHukamnamaWebArchiveDays, punjabi: punjabi),
          )
        : l10n.archive_body;

    return SheetFrame(
      key: const ValueKey('archive-sheet'),
      children: [
        Text(l10n.archive_title, style: AppType.title2),
        const SizedBox(height: 8),
        Text(body, style: AppType.body),
        const SizedBox(height: 8),
        // The wheel takes the Cupertino theme, which AppTheme sets to dark,
        // gold and Geist.
        SizedBox(
          height: 180,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: _picked,
            minimumDate: pickerDayOf(_floor),
            maximumDate: pickerDayOf(_today),
            // The year wheel ends at the range, and does not run on to years
            // the wheel can only snap back from.
            minimumYear: _floor.year,
            maximumYear: _today.year,
            onDateTimeChanged: (day) => _picked = pickerDayOf(day),
          ),
        ),
        const SizedBox(height: 16),
        GoldSheetButton(
          label: l10n.archive_open,
          onTap: () => _close(sgpcDayFromPicker(_picked)),
        ),
        const SizedBox(height: 4),
        QuietSheetButton(
          label: l10n.archive_yesterday,
          onTap: () => _close(previousSgpcDay(_today)),
        ),
      ],
    );
  }
}
