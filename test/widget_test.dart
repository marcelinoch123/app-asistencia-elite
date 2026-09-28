import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test básico de widgets', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Elite Multiservicios'),
          ),
        ),
      ),
    );

    expect(find.text('Elite Multiservicios'), findsOneWidget);
  });
}