import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('HireIQ app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: HireIQApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
