import 'package:flutter_test/flutter_test.dart';
import 'package:sheaf/logic/zoom.dart';

void main() {
  group('clampZoom', () {
    test('keeps in-range factors untouched', () {
      expect(clampZoom(1.0), 1.0);
      expect(clampZoom(0.75), 0.75);
      expect(clampZoom(1.9), 1.9);
    });

    test('clamps beyond the documented range', () {
      expect(clampZoom(0.1), kZoomMin);
      expect(clampZoom(5.0), kZoomMax);
      expect(clampZoom(-2), kZoomMin);
    });
  });

  group('stepZoom', () {
    test('steps up and down by 10%', () {
      expect(stepZoom(1.0, up: true), 1.1);
      expect(stepZoom(1.1, up: false), 1.0);
    });

    test('avoids binary floating point drift', () {
      // 0.7 + 0.1 must be exactly 0.8, not 0.7999999999999999.
      var f = 0.6;
      for (var i = 0; i < 4; i++) {
        f = stepZoom(f, up: true);
      }
      expect(f, 1.0);
    });

    test('stops at the bounds without wrapping', () {
      expect(stepZoom(kZoomMax, up: true), kZoomMax);
      expect(stepZoom(kZoomMin, up: false), kZoomMin);
      expect(stepZoom(1.95, up: true), 2.0);
      expect(stepZoom(0.55, up: false), 0.5);
    });

    test('normalizes arbitrary inputs before stepping', () {
      expect(stepZoom(3.0, up: true), 2.0);
      expect(stepZoom(0.123, up: false), 0.5);
    });
  });
}
