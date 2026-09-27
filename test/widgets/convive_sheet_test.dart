// test/widgets/convive_sheet_test.dart
//
// showConviveSheet es el cajón que abre CADA flujo de escritura (nuevo
// gasto, nueva tarea, nuevo recordatorio, nota...). No toca Firebase, así
// que se puede testear de verdad sin el bloqueo de mocking de Firebase que
// afecta al resto de la suite (ver test/widget_test.dart).
import 'package:convive/theme/design_tokens.dart';
import 'package:convive/widgets/convive_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => MaterialApp(theme: buildConviveDarkTheme(), home: home);

void main() {
  testWidgets('muestra el titulo y el contenido del builder', (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => showConviveSheet<void>(
            context: context,
            title: 'Nuevo gasto',
            builder: (ctx, setState) => const Text('contenido del formulario'),
          ),
          child: const Text('abrir'),
        ),
      ),
    )));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo gasto'), findsOneWidget);
    expect(find.text('contenido del formulario'), findsOneWidget);
  });

  testWidgets('el setState del builder actualiza el contenido sin cerrar el sheet', (tester) async {
    // igual que en mostrarNuevoGasto: la variable de estado vive en el
    // scope de quien ABRE el sheet, no dentro del builder -- si viviera
    // dentro del builder, cada setState la reiniciaria (ese fue justo el
    // bug que este test atrapo la primera vez que se escribio).
    var seleccionado = false;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => showConviveSheet<void>(
            context: context,
            title: 'Elegir',
            builder: (ctx, setState) => ElevatedButton(
              onPressed: () => setState(() => seleccionado = !seleccionado),
              child: Text(seleccionado ? 'seleccionado' : 'sin seleccionar'),
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    )));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('sin seleccionar'), findsOneWidget);

    await tester.tap(find.text('sin seleccionar'));
    await tester.pumpAndSettle();
    expect(find.text('seleccionado'), findsOneWidget);
    expect(find.text('Elegir'), findsOneWidget); // el sheet sigue abierto
  });

  testWidgets('devuelve el valor pasado a Navigator.pop al cerrarse', (tester) async {
    String? resultado;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () async {
            resultado = await showConviveSheet<String>(
              context: context,
              title: 'Confirmar',
              builder: (ctx, setState) => ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'ok'),
                child: const Text('confirmar'),
              ),
            );
          },
          child: const Text('abrir'),
        ),
      ),
    )));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('confirmar'));
    await tester.pumpAndSettle();

    expect(resultado, 'ok');
  });
}
