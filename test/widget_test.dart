import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_x/main.dart';

void main() {
  testWidgets('publica e preserva ultimo texto no fim', (tester) async {
    final consultas = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: AppTwitter()));
      await tester.enterText(find.byType(TextField), 'Ola, turma!');
      await tester.pump();
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
      await tester.scrollUntilVisible(find.text('Próximo'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Ola, turma!'), findsOneWidget);
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Ola, turma!'), findsOneWidget);
      expect(consultas, ['0', '7']);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('salva.php')) {
                expect(request.url.queryParameters['txt'], 'Ola, turma!');
                return http.Response('Texto salvo!', 200);
              }
              final id = request.url.queryParameters['id']!;
              consultas.add(id);
              return http.Response(
                  id == '0' ? '{"id":7,"texto":"Ola, turma!"}' : 'null', 200);
            }));
  });
}
