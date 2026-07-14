import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ishtirakati/main.dart';

void main() {
  test('installed builds disable Flutter paint diagnostics', () {
    debugPaintSizeEnabled = true;
    debugPaintBaselinesEnabled = true;
    debugPaintPointersEnabled = true;
    debugPaintLayerBordersEnabled = true;
    debugRepaintRainbowEnabled = true;

    disableVisualDebugOverlays();

    expect(debugPaintSizeEnabled, isFalse);
    expect(debugPaintBaselinesEnabled, isFalse);
    expect(debugPaintPointersEnabled, isFalse);
    expect(debugPaintLayerBordersEnabled, isFalse);
    expect(debugRepaintRainbowEnabled, isFalse);
  });
}
