import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_x/galeria.dart';

void main() {
  testWidgets('galeria vazia orienta o envio de uma foto', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Galeria(
                  baseUrl: Uri.parse('http://localhost/api/fotos.php')))));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nenhuma foto publicada'), findsOneWidget);
    }, () => MockClient((_) async => http.Response('[]', 200)));
  });

  testWidgets('mostra todas as fotos uma por vez com limites de navegacao',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Galeria(
                  baseUrl: Uri.parse('http://localhost/api/fotos.php')))));
      await tester.pumpAndSettle();
      expect(find.text('Primeira foto'), findsOneWidget);
      expect(find.text('Segunda foto'), findsNothing);
      expect(
          tester
              .widget<OutlinedButton>(
                  find.ancestor(of: find.text('Anterior'), matching: find.byWidgetPredicate((w) => w is OutlinedButton)).first)
              .onPressed,
          isNull);
      await tester.tap(find.text('Próxima foto'));
      await tester.pumpAndSettle();
      expect(find.text('Segunda foto'), findsOneWidget);
      expect(find.text('Foto 2 de 2'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.ancestor(of: find.text('Próxima foto'), matching: find.byWidgetPredicate((w) => w is FilledButton)).first)
              .onPressed,
          isNull);
      await tester.tap(find.text('Anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Primeira foto'), findsOneWidget);
    },
        () => MockClient((_) async => http.Response(
            '[{"id":1,"url":"uploads/a.png","descricao":"Primeira foto"},{"id":2,"url":"uploads/b.png","descricao":"Segunda foto"}]',
            200)));
  });
}

