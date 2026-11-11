import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_x/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('valida campos e rejeita login sem salvar sessao',
      (tester) async {
    var pedidos = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MiniX());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Informe um e-mail válido.'), findsOneWidget);
      expect(pedidos, 0);
      await tester.enterText(
          find.byType(TextFormField).at(0), 'ana@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'senhaerrada');
      await tester.ensureVisible(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
      expect(
          (await SharedPreferences.getInstance()).getString('usuario'), isNull);
    },
        () => MockClient((r) async {
              if (r.url.path.endsWith('social.php')) {
                return http.Response('{"postagens":[],"mais":false}', 200);
              }
              pedidos++;
              expect(r.url.path, '/api/login.php');
              return http.Response(
                  jsonEncode({'erro': 'E-mail ou senha incorretos.'}), 401,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });

  testWidgets('cadastro envia dados, restaura sessao e permite sair',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MiniX());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Criar uma conta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Ana Silva');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'ana@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'Senha123!');
      await tester.ensureVisible(find.text('Cadastrar'));
      await tester.tap(find.text('Cadastrar'));
      await tester.pumpAndSettle();
      expect(find.text('Compartilhe uma ideia'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(
          jsonDecode(prefs.getString('usuario')!)['email'], 'ana@example.com');
      expect(jsonDecode(prefs.getString('usuario')!)['token'], 'token-teste');
      expect(prefs.getKeys(), isNot(contains('senha')));
      expect(prefs.getString('usuario'), isNot(contains('Senha123!')));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MiniX());
      await tester.pumpAndSettle();
      expect(find.text('Compartilhe uma ideia'), findsOneWidget);
      await tester.tap(find.byTooltip('Sair da conta'));
      await tester.pumpAndSettle();
      expect(find.text('Bem-vindo ao Mini X'), findsOneWidget);
      expect(prefs.getString('usuario'), isNull);
    },
        () => MockClient((r) async {
              if (r.url.path.endsWith('social.php')) {
                return http.Response('{"postagens":[],"mais":false}', 200);
              }
              expect(r.url.path, '/api/cadastro.php');
              expect(r.bodyFields, {
                'nome': 'Ana Silva',
                'email': 'ana@example.com',
                'senha': 'Senha123!'
              });
              return http.Response(
                  jsonEncode({
                    'token': 'token-teste',
                    'usuario': {
                      'id': 1,
                      'nome': 'Ana Silva',
                      'email': 'ana@example.com'
                    }
                  }),
                  201);
            }));
  });

  testWidgets('login correto abre o app e salva o perfil', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MiniX());
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextFormField).at(0), 'ana@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'Senha123!');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Compartilhe uma ideia'), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getString('usuario'),
          contains('ana@example.com'));
    },
        () => MockClient((r) async {
              if (r.url.path.endsWith('social.php')) {
                return http.Response('{"postagens":[],"mais":false}', 200);
              }
              expect(r.url.path, '/api/login.php');
              expect(r.bodyFields,
                  {'email': 'ana@example.com', 'senha': 'Senha123!'});
              return http.Response(
                  jsonEncode({
                    'token': 'token-teste',
                    'usuario': {
                      'id': 1,
                      'nome': 'Ana',
                      'email': 'ana@example.com'
                    }
                  }),
                  200);
            }));
  });
  testWidgets('perfil antigo sem token exige novo login', (tester) async {
    SharedPreferences.setMockInitialValues({
      'usuario':
          jsonEncode({'id': 1, 'nome': 'Ana', 'email': 'ana@example.com'})
    });
    await tester.pumpWidget(const MiniX());
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo ao Mini X'), findsOneWidget);
    expect(find.text('Publicar'), findsNothing);
  });
}
