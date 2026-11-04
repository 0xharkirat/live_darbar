import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/widget_card_rules.dart';

/// When the "add the widget" card shows. Each test starts from a listener who
/// should see the card, and changes 1 fact.
void main() {
  bool show({
    bool supported = true,
    bool played = true,
    bool laterVisit = true,
    bool dismissed = false,
    bool shownEarlier = false,
    bool showing = false,
    WidgetPlacement placement = WidgetPlacement.absent,
    bool sheetOpen = false,
  }) =>
      shouldShowWidgetCard(
        WidgetCardFacts(
          supported: supported,
          playedHukamnama: played,
          laterVisit: laterVisit,
          dismissed: dismissed,
          shownEarlier: shownEarlier,
          showing: showing,
          placement: placement,
          sheetOpen: sheetOpen,
        ),
      );

  test('shows on a later visit, after the Hukamnama has played', () {
    expect(show(), isTrue);
  });

  group('when', () {
    test('never before the Hukamnama recording has played', () {
      expect(show(played: false), isFalse);
    });

    test('not on the visit that played it', () {
      expect(show(laterVisit: false), isFalse);
    });

    test('a visit that has not played yet is not a later visit', () {
      expect(show(played: false, laterVisit: true), isFalse);
    });
  });

  group('never', () {
    test('on a platform with no home screen widgets, such as the web', () {
      expect(show(supported: false), isFalse);
    });

    test('when the widget is already on the home screen', () {
      expect(show(placement: WidgetPlacement.added), isFalse);
    });

    test('when the phone cannot say if the widget is there', () {
      expect(show(placement: WidgetPlacement.unknown), isFalse);
    });

    test('after "Not now"', () {
      expect(show(dismissed: true), isFalse);
    });

    test('after "Not now", even when it was on screen', () {
      expect(show(dismissed: true, showing: true), isFalse);
    });

    test('while a sheet is open', () {
      expect(show(sheetOpen: true), isFalse);
    });
  });

  group('once', () {
    test('not again after an earlier visit showed it and nobody answered', () {
      expect(show(shownEarlier: true), isFalse);
    });

    test('stays while it is on screen in this visit', () {
      expect(show(showing: true), isTrue);
    });

    test('stays on screen when a sheet opens over it', () {
      expect(show(showing: true, sheetOpen: true), isTrue);
    });

    test('goes away when the widget is added, even while on screen', () {
      expect(
        show(showing: true, placement: WidgetPlacement.added),
        isFalse,
      );
    });

    test('does not come back if the widget is removed after the first show',
        () {
      // On a later visit, shown is a saved fact and showing is not.
      expect(
          show(shownEarlier: true, placement: WidgetPlacement.absent), isFalse);
    });
  });
}
