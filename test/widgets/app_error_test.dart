// test/widgets/app_error_test.dart
//
// AppError.show es el unico punto de feedback de error en las 12+ acciones
// de escritura de la app (enviar mensaje, nota, tarea, gasto...). Si deja de
// mostrar el SnackBar, un fallo de red vuelve a fallar en silencio -- el bug
// original que este helper existe para evitar.
import 'package:convive/widgets/app_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra un SnackBar con el mensaje dado', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => AppError.show(context, 'No se pudo enviar'),
            child: const Text('fallar'),
          ),
        ),
      ),
    ));

    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text('fallar'));
    await tester.pump(); // el SnackBar entra con una animacion

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('No se pudo enviar'), findsOneWidget);
  });
}
