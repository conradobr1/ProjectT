import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_x/main.dart';

void main() {
  testWidgets('publica e atualiza feed de todos', (tester) async {
    var publicou = false;
    var consultas = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: AppTwitter(token: 'token-teste')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Ola, turma!');
      await tester.pump();
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
      expect(find.text('Ola, turma!'), findsOneWidget);
      expect(consultas, 2);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('postagem.php')) {
                expect(request.method, 'POST');
                expect(request.body, contains('Ola, turma!'));
                expect(request.body, contains('token-teste'));
                publicou = true;
                return http.Response('{"id":7}', 201);
              }
              consultas++;
              return http.Response(
                  jsonEncode({
                    'postagens': publicou
                        ? [
                            {
                              'id': 7,
                              'texto': 'Ola, turma!',
                              'nome': 'Ana',
                              'curtidas': 0,
                              'comentarios': 0,
                              'curtiu': false,
                              'amizade': 'proprio'
                            }
                          ]
                        : [],
                    'mais': false
                  }),
                  200);
            }));
  });
  testWidgets('falha na postagem preserva o texto para tentar novamente',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
          const MaterialApp(home: AppTwitter(token: 'token-teste')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Minha ideia');
      await tester.pump();
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Minha ideia');
      expect(find.text('Sessão expirada. Entre novamente.'), findsOneWidget);
    },
        () => MockClient((r) async {
              if (r.url.path.endsWith('social.php')) {
                return http.Response('{"postagens":[],"mais":false}', 200);
              }
              return http.Response(
                  '{"erro":"Sessão expirada. Entre novamente."}', 401,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });
}
