import 'package:flutter_test/flutter_test.dart';
import 'package:flutterxel/flutterxel.dart' as flutterxel;

void main() {
  tearDown(() {
    flutterxel.stopRunLoop();
    flutterxel.reset();
  });

  test(
    'resource image bank supports IMAGE_SIZE coordinates for sprite-sheet rows',
    () {
      flutterxel.init(64, 64);
      flutterxel.cls(0);
      flutterxel.images[0].cls(0);

      // Mimics Visual Agent sprite-sheet addressing (32px frame, row 5 => y=160).
      flutterxel.images[0].pset(0, 160, 9);
      flutterxel.blt(0, 0, 0, 0, 160, 1, 1);

      expect(flutterxel.pget(0, 0), 9);
    },
  );

  test('resource image bank supports frame-width sampling beyond 16px', () {
    flutterxel.init(64, 64);
    flutterxel.cls(0);
    flutterxel.images[0].cls(0);

    flutterxel.images[0].pset(31, 0, 12);
    flutterxel.blt(0, 0, 0, 0, 0, 32, 1);

    expect(flutterxel.pget(31, 0), 12);
  });
}
