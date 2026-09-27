// test/widgets/corkboard_test.dart
//
// El post-it es el elemento visual del tablon de notas -- si el boton de
// borrar deja de disparar onDelete, el usuario cree que ha borrado la nota
// y sigue ahi (bug silencioso, dificil de notar a simple vista en manual QA).
import 'package:convive/theme/design_tokens.dart';
import 'package:convive/widgets/corkboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget home) => MaterialApp(theme: buildConviveDarkTheme(), home: home);

void main() {
  testWidgets('muestra el texto y el autor de la nota', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(
      body: PostItNote(text: 'Ha venido el casero', author: 'Ana', color: Color(0xFFE8B94E), seed: 1),
    )));

    expect(find.text('Ha venido el casero'), findsOneWidget);
    expect(find.text('— Ana'), findsOneWidget);
  });

  testWidgets('sin onDelete no muestra boton de borrar', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(
      body: PostItNote(text: 'x', author: 'a', color: Color(0xFFE8B94E), seed: 1),
    )));

    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('tocar el boton de borrar dispara onDelete exactamente una vez', (tester) async {
    var borrados = 0;
    await tester.pumpWidget(_app(Scaffold(
      body: PostItNote(
        text: 'x', author: 'a', color: const Color(0xFFE8B94E), seed: 1,
        onDelete: () => borrados++,
      ),
    )));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(borrados, 1);
  });

  testWidgets('CorkboardSurface renderiza su child por encima de la textura', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(
      body: CorkboardSurface(child: Text('hijo visible')),
    )));

    expect(find.text('hijo visible'), findsOneWidget);
  });
}
