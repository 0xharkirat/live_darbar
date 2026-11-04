import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_darbar/src/core/motion.dart';

void main() {
  group('SpringThroughCurve', () {
    const curve = Curves.fastEaseInToSlowEaseOut;

    SpringSimulation makeSpring([double velocity = 0]) =>
        SpringSimulation(Motion.sheet, 0, 1, velocity, snapToEnd: true);

    test('draws the spring on screen, not the warped curve', () {
      final spring = makeSpring();
      final through = SpringThroughCurve(spring, curve);

      for (var ms = 0; ms <= 600; ms += 20) {
        final t = ms / 1000;
        // What a route draws is the curve of its controller. It must be the
        // spring's own value.
        expect(curve.transform(through.x(t)), closeTo(spring.x(t), 0.01));
      }
    });

    test('starts at 0 and ends at exactly 1', () {
      final through = SpringThroughCurve(makeSpring(), curve);

      expect(through.x(0), 0);
      expect(through.x(5), 1);
      expect(through.isDone(5), isTrue);
    });

    test('carries the finger\'s speed: the sheet on screen starts at it', () {
      // 2 sheet heights per second. The spring also speeds up toward its end
      // point, so over the first 20 ms the sheet averages more than that.
      final spring = makeSpring(2);
      final through = SpringThroughCurve(spring, curve);

      const dt = 0.02;
      final screenSpeed = curve.transform(through.x(dt)) / dt;
      expect(screenSpeed, greaterThan(2));
      expect(screenSpeed, closeTo(spring.x(dt) / dt, 0.15));
    });

    test('a faster finger is further along at the same moment', () {
      final slow = SpringThroughCurve(makeSpring(), curve);
      final fast = SpringThroughCurve(makeSpring(3), curve);

      expect(fast.x(0.06), greaterThan(slow.x(0.06)));
    });

    test('never leaves 0 to 1, so a bounded controller is safe', () {
      final through = SpringThroughCurve(
        SpringSimulation(Motion.sheetFlick, 0, 1, 6, snapToEnd: true),
        curve,
      );

      for (var ms = 0; ms <= 900; ms += 10) {
        expect(through.x(ms / 1000), inInclusiveRange(0, 1));
      }
    });
  });
}
