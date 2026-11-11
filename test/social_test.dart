import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mini_x/social.dart';

Map<String, dynamic> postagem({String amizade = 'nenhuma', int id = 4}) => {
      'id': id,
      'autor_id': 2,
      'nome': 'Bruno',
      'texto': 'Ideia $id',
      'curtidas': 0,
      'curtiu': false,
      'comentarios': 0,
      'amizade': amizade,
      'pode_comentar': amizade == 'amigo'
    };
http.Response resposta(Map<String, dynamic> dados) =>
    http.Response(jsonEncode(dados), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
Widget feed() => const MaterialApp(
    home: Scaffold(
        body: SingleChildScrollView(
            child:
                FeedSocial(baseUrl: 'http://localhost/api', token: 'sessao'))));

void main() {
  testWidgets('curte e descurte; pedido pendente nao libera comentario',
      (tester) async {
    final acoes = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(feed());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('curtir-4')));
      await tester.pumpAndSettle();
      expect(find.text('1 curtidas'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('curtir-4')));
      await tester.pumpAndSettle();
      expect(find.text('0 curtidas'), findsOneWidget);
      await tester.tap(find.text('Solicitar amizade'));
      await tester.pumpAndSettle();
      expect(find.text('Solicitação enviada. Aguardando aprovação.'),
          findsOneWidget);
      await tester.tap(find.text('0 comentários'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(
          find.text(
              'Para comentar, solicite amizade ao autor e aguarde a aprovação.'),
          findsOneWidget);
      expect(acoes, ['feed', 'curtir', 'curtir', 'solicitar', 'comentarios']);
    },
        () => MockClient((r) async {
              final campos = r.bodyFields;
              final acao = campos['acao']!;
              acoes.add(acao);
              expect(campos['token'], 'sessao');
              if (acao == 'feed') {
                return resposta({
                  'postagens': [postagem()],
                  'mais': false
                });
              }
              if (acao == 'curtir') {
                return resposta({
                  'curtiu': campos['curtir'] == '1',
                  'curtidas': campos['curtir'] == '1' ? 1 : 0
                });
              }
              if (acao == 'solicitar') {
                expect(campos['usuario_id'], '2');
                return resposta({'amizade': 'enviado'});
              }
              return resposta(
                  {'comentarios': [], 'mais': false, 'pode_comentar': false});
            }));
  });

  testWidgets('aprovar pedido atualiza o feed e libera comentario',
      (tester) async {
    var amigo = false;
    var comentou = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(feed());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amizades'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aprovar'));
      await tester.pumpAndSettle();
      expect(find.text('Seus amigos'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Amigos • Você pode comentar'), findsOneWidget);
      await tester.tap(find.text('0 comentários'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Gostei da ideia!');
      await tester.pump();
      await tester.tap(find.text('Comentar'));
      await tester.pumpAndSettle();
      expect(find.text('Gostei da ideia!'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      expect(find.text('1 comentários'), findsOneWidget);
    },
        () => MockClient((r) async {
              final c = r.bodyFields;
              switch (c['acao']) {
                case 'feed':
                  return resposta({
                    'postagens': [
                      {
                        ...postagem(amizade: amigo ? 'amigo' : 'recebido'),
                        'comentarios': comentou ? 1 : 0
                      }
                    ],
                    'mais': false
                  });
                case 'amizades':
                  return resposta({
                    'amizades': [
                      {
                        'id': 2,
                        'nome': 'Bruno',
                        'status': amigo ? 'amigo' : 'recebido'
                      }
                    ]
                  });
                case 'responder':
                  expect(c['aceitar'], '1');
                  expect(c['usuario_id'], '2');
                  amigo = true;
                  return resposta({'amizade': 'amigo'});
                case 'comentar':
                  expect(amigo, isTrue);
                  expect(c['texto'], 'Gostei da ideia!');
                  comentou = true;
                  return resposta({'id': 1});
                default:
                  return resposta({
                    'comentarios': comentou
                        ? [
                            {
                              'id': 1,
                              'nome': 'Ana',
                              'texto': 'Gostei da ideia!'
                            }
                          ]
                        : [],
                    'pode_comentar': amigo,
                    'mais': false
                  });
              }
            }));
  });

  testWidgets('pagina postagens sem apagar a pagina anterior', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(feed());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Carregar mais postagens'));
      await tester.tap(find.text('Carregar mais postagens'));
      await tester.pumpAndSettle();
      expect(find.text('Ideia 4'), findsOneWidget);
      expect(find.text('Ideia 3'), findsOneWidget);
    },
        () => MockClient((r) async {
              final segunda = r.bodyFields['antes'] != null;
              if (segunda) expect(r.bodyFields['antes'], '4');
              return resposta({
                'postagens': [postagem(id: segunda ? 3 : 4)],
                'mais': !segunda
              });
            }));
  });

  testWidgets('erro no feed oferece nova tentativa', (tester) async {
    var tentativas = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(feed());
      await tester.pumpAndSettle();
      expect(find.text('Servidor indisponível'), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Ideia 4'), findsOneWidget);
    },
        () => MockClient((r) async {
              if (tentativas++ == 0) {
                return http.Response('{"erro":"Servidor indisponível"}', 500,
                    headers: {
                      'content-type': 'application/json; charset=utf-8'
                    });
              }
              return resposta({
                'postagens': [postagem()],
                'mais': false
              });
            }));
  });
}
