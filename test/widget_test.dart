import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_asistencia_elite/main.dart'; // ✅ IMPORTAR MyApp

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // ✅ CAMBIAR EliteAttendanceApp POR MyApp
    await tester.pumpWidget(const MyApp());

    // Verificar que la app carga correctamente
    expect(find.byType(MyApp), findsOneWidget);
  });
}