// test/widget_test.dart
//
// Smoke test mínimo — no toca Firebase (no hay mocking de FirebaseAuth
// disponible todavía, misma limitación que en RiskRunner). Los tests reales
// de lógica van en test/services/ a medida que se añaden servicios.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp con texto renderiza correctamente', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Text('Convive')),
    ));
    expect(find.text('Convive'), findsOneWidget);
  });
}
