import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_puzzle/main.dart';

void main() {
  testWidgets('renders puzzle controls', (tester) async {
    await tester.pumpWidget(const PixelPuzzleApp());

    expect(find.text('UP'), findsOneWidget);
    expect(find.text('DOWN'), findsOneWidget);
    expect(find.text('LEFT'), findsOneWidget);
    expect(find.text('RIGHT'), findsOneWidget);
    expect(find.text('ACT'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
