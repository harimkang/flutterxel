import 'package:cosmic_survivor/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterxel/flutterxel.dart' as flutterxel;

void main() {
  testWidgets('uses fullscreen layout and renders controls', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const CosmicSurvivorApp());

    expect(find.byType(AppBar), findsNothing);

    final stackSize = tester.getSize(find.byType(Stack).first);
    expect(stackSize.height, 640);

    final gameViewSize = tester.getSize(find.byType(flutterxel.FlutterxelView));
    expect(gameViewSize.height, greaterThan(500));

    expect(find.text('LEFT'), findsOneWidget);
    expect(find.text('FIRE'), findsOneWidget);
    expect(find.text('RIGHT'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
