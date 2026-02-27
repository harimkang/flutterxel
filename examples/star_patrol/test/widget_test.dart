import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:star_patrol/main.dart';

void main() {
  testWidgets('renders top-down controls', (tester) async {
    await tester.pumpWidget(const StarPatrolApp());

    expect(find.text('UP'), findsOneWidget);
    expect(find.text('DOWN'), findsOneWidget);
    expect(find.text('LEFT'), findsOneWidget);
    expect(find.text('RIGHT'), findsOneWidget);
    expect(find.text('FIRE'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
