import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interview_prep_app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('HireIQ app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: HireIQApp()),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
