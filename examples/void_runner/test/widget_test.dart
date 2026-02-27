import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:void_runner/main.dart';

void main() {
  testWidgets('renders jump control', (tester) async {
    await tester.pumpWidget(const VoidRunnerApp());

    expect(find.text('JUMP'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
