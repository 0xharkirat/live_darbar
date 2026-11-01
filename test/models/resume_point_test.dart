import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/models/resume_point.dart';

void main() {
  final t0 = DateTime(2026, 11, 2, 6);

  test('offers nothing before a position is remembered', () {
    expect(ResumePoint().startFor(1, t0), isNull);
  });

  test('offers the remembered position for the same source', () {
    final point = ResumePoint()..remember(1, const Duration(minutes: 20), t0);
    expect(point.startFor(1, t0), const Duration(minutes: 20));
  });

  test('offers nothing for a different source', () {
    final point = ResumePoint()..remember(1, const Duration(minutes: 20), t0);
    expect(point.startFor(2, t0), isNull);
  });

  test('the latest position wins', () {
    final point = ResumePoint()
      ..remember(1, const Duration(minutes: 20), t0)
      ..remember(1, const Duration(minutes: 21), t0);
    expect(point.startFor(1, t0), const Duration(minutes: 21));
  });

  test('moving to another source drops the old position', () {
    final point = ResumePoint()
      ..remember(1, const Duration(minutes: 20), t0)
      ..remember(2, const Duration(seconds: 30), t0);
    expect(point.startFor(1, t0), isNull);
    expect(point.startFor(2, t0), const Duration(seconds: 30));
  });

  test('a position at the very start is not worth a seek', () {
    final point = ResumePoint()..remember(1, const Duration(seconds: 1), t0);
    expect(point.startFor(1, t0), isNull);
  });

  test('clear forgets the position', () {
    final point = ResumePoint()
      ..remember(1, const Duration(minutes: 20), t0)
      ..clear();
    expect(point.startFor(1, t0), isNull);
    expect(point.index, -1);
  });

  test('a position expires after three hours', () {
    final point = ResumePoint()..remember(1, const Duration(minutes: 20), t0);
    expect(
      point.startFor(1, t0.add(ResumePoint.maxAge)),
      const Duration(minutes: 20),
    );
    expect(
      point.startFor(1, t0.add(ResumePoint.maxAge + const Duration(seconds: 1))),
      isNull,
    );
  });

  test('ignores a negative position', () {
    final point = ResumePoint()
      ..remember(1, const Duration(minutes: 5), t0)
      ..remember(1, const Duration(seconds: -3), t0);
    expect(point.startFor(1, t0), const Duration(minutes: 5));
  });
}
