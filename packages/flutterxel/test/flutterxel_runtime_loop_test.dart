import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterxel/flutterxel.dart' as flutterxel;

void main() {
  tearDown(() {
    flutterxel.stopRunLoop();
  });

  test('run starts periodic loop and stopRunLoop halts it', () async {
    flutterxel.init(32, 32, fps: 60);

    var updates = 0;
    var draws = 0;

    flutterxel.run(
      () {
        updates += 1;
      },
      () {
        draws += 1;
      },
    );

    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(flutterxel.isRunning, isTrue);
    expect(updates, greaterThan(0));
    expect(draws, greaterThan(0));

    flutterxel.stopRunLoop();
    expect(flutterxel.isRunning, isFalse);

    final frozenUpdates = updates;
    final frozenDraws = draws;
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(updates, frozenUpdates);
    expect(draws, frozenDraws);
  });

  testWidgets('FlutterxelView renders CustomPaint canvas', (tester) async {
    flutterxel.init(16, 16, fps: 30);
    flutterxel.cls(3);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: flutterxel.FlutterxelView(pixelScale: 2)),
        ),
      ),
    );

    expect(find.byType(flutterxel.FlutterxelView), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    flutterxel.stopRunLoop();
  });
}
