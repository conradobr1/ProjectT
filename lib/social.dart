import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SocialApi {
  SocialApi(this.base, this.token);
  final String base;
  final String token;
  Uri arquivo(String caminho) =>
      Uri.parse('${base.replaceFirst(RegExp(r'/+$'), '')}/').resolve(caminho);
  Future<Map<String, dynamic>> chamar(String acao,
      [Map<String, String> campos = const {}]) async {
    try {
      final r = await http.post(arquivo('social.php'), body: {
        'token': token,
        'acao': acao,
        ...campos
      }).timeout(const Duration(seconds: 15));
      final dados = jsonDecode(utf8.decode(r.bodyBytes));
      if (dados is! Map<String, dynamic>) throw const FormatException();
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw FalhaSocial(dados['erro'] is String
            ? dados['erro'] as String
            : 'Não foi possível concluir.');
      }
      return dados;
    } on FalhaSocial {
      rethrow;
    } catch (_) {
      throw FalhaSocial(
          'Não foi possível conectar. Confira o servidor e tente novamente.');
    }
  }
}

class FalhaSocial implements Exception {
  FalhaSocial(this.mensagem);
  final String mensagem;
}

class FeedSocial extends StatefulWidget {
  const FeedSocial({super.key, required this.baseUrl, required this.token});
  final String baseUrl;
  final String token;
  @override
  State<FeedSocial> createState() => _FeedSocialState();
}

class _FeedSocialState extends State<FeedSocial> {
  late final api = SocialApi(widget.baseUrl, widget.token);
  final List<Map<String, dynamic>> postagens = [];
  final Set<int> ocupados = {};
  bool carregando = false, mais = false;
  String? erro;
  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar({bool continuar = false}) async {
    if (carregando) return;
    setState(() {
      carregando = true;
      erro = null;
    });
    try {
      final dados = await api.chamar('feed', {
        if (continuar && postagens.isNotEmpty)
          'antes': '${postagens.last['id']}'
      });
      final itens = (dados['postagens'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        if (!continuar) postagens.clear();
        postagens.addAll(itens);
        mais = dados['mais'] == true;
      });
    } on FalhaSocial catch (e) {
      if (mounted) setState(() => erro = e.mensagem);
    } catch (_) {
      if (mounted) {
        setState(() => erro = 'Não foi possível carregar as postagens.');
      }
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  void mensagem(String texto) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(texto)));
  Future<void> curtir(Map<String, dynamic> p) async {
    final id = p['id'] as int;
    if (ocupados.contains(id)) return;
    setState(() => ocupados.add(id));
    try {
      final dados = await api.chamar('curtir',
          {'publicacao_id': '$id', 'curtir': p['curtiu'] == true ? '0' : '1'});
      if (mounted) {
        setState(() {
          p['curtidas'] = dados['curtidas'];
          p['curtiu'] = dados['curtiu'];
        });
      }
    } on FalhaSocial catch (e) {
      if (mounted) mensagem(e.mensagem);
    } finally {
      if (mounted) setState(() => ocupados.remove(id));
    }
  }

  Future<void> solicitar(Map<String, dynamic> p) async {
    final id = p['id'] as int;
    if (ocupados.contains(id)) return;
    setState(() => ocupados.add(id));
    try {
      final dados =
          await api.chamar('solicitar', {'usuario_id': '${p['autor_id']}'});
      if (!mounted) return;
      setState(() {
        for (final item in postagens) {
          if (item['autor_id'] == p['autor_id']) {
            item['amizade'] = dados['amizade'];
            item['pode_comentar'] = dados['amizade'] == 'amigo';
          }
        }
      });
      mensagem(dados['amizade'] == 'recebido'
          ? 'Você já recebeu um pedido dessa pessoa. Abra Amizades para responder.'
          : 'Solicitação registrada. Aguarde a aprovação.');
    } on FalhaSocial catch (e) {
      if (mounted) mensagem(e.mensagem);
    } finally {
      if (mounted) setState(() => ocupados.remove(id));
    }
  }

  Future<void> amizades() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => TelaAmizades(api: api)));
    if (mounted) await carregar();
  }

  Future<void> comentarios(Map<String, dynamic> p) async {
    await showDialog<void>(
        context: context,
        builder: (_) => ComentariosSocial(api: api, postagem: p['id'] as int));
    if (mounted) await carregar();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Publicações de todos',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Wrap(children: [
                IconButton(
                    tooltip: 'Atualizar postagens',
                    onPressed: carregando ? null : () => carregar(),
                    icon: const Icon(Icons.refresh)),
                TextButton.icon(
                    onPressed: amizades,
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Amizades')),
              ]),
            ]),
        if (erro != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(erro!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        if (!carregando && erro == null && postagens.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'Ainda não há postagens. Compartilhe a primeira ideia!')),
        for (final p in postagens)
          Card(
              key: ValueKey('post-${p['id']}'),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(p['nome'] as String? ?? 'Comunidade',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        if (p['criado_em'] is String)
                          Text(p['criado_em'] as String,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 12),
                        SelectableText(p['texto'] as String,
                            style: const TextStyle(fontSize: 18)),
                        if (p['foto_url'] is String)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Image.network(
                                  api
                                      .arquivo(p['foto_url'] as String)
                                      .toString(),
                                  height: 230,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const Text('Foto indisponível.'))),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, children: [
                          TextButton.icon(
                              key: ValueKey('curtir-${p['id']}'),
                              onPressed: ocupados.contains(p['id'])
                                  ? null
                                  : () => curtir(p),
                              icon: Icon(
                                  p['curtiu'] == true
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: p['curtiu'] == true
                                      ? Colors.pinkAccent
                                      : null),
                              label: Text('${p['curtidas']} curtidas')),
                          TextButton.icon(
                              onPressed: () => comentarios(p),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: Text('${p['comentarios']} comentários')),
                        ]),
                        if (p['amizade'] == 'nenhuma')
                          OutlinedButton.icon(
                              onPressed: ocupados.contains(p['id'])
                                  ? null
                                  : () => solicitar(p),
                              icon: const Icon(Icons.person_add_alt),
                              label: const Text('Solicitar amizade')),
                        if (p['amizade'] == 'enviado')
                          const Text(
                              'Solicitação enviada. Aguardando aprovação.'),
                        if (p['amizade'] == 'recebido')
                          TextButton(
                              onPressed: amizades,
                              child: const Text(
                                  'Responder solicitação de amizade')),
                        if (p['amizade'] == 'amigo')
                          const Text('Amigos • Você pode comentar',
                              style: TextStyle(color: Colors.greenAccent)),
                        if (p['amizade'] != 'amigo')
                          const Text(
                              'Comentários disponíveis apenas em postagens de amigos.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                      ]))),
        if (carregando)
          const Padding(
              padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        if (mais && !carregando)
          OutlinedButton(
              onPressed: () => carregar(continuar: true),
              child: const Text('Carregar mais postagens')),
        if (erro != null && !carregando)
          TextButton(
              onPressed: () => carregar(),
              child: const Text('Tentar novamente')),
      ]);
}

class TelaAmizades extends StatefulWidget {
  const TelaAmizades({super.key, required this.api});
  final SocialApi api;
  @override
  State<TelaAmizades> createState() => _TelaAmizadesState();
}

class _TelaAmizadesState extends State<TelaAmizades> {
  List<Map<String, dynamic>> lista = [];
  bool carregando = true, ocupado = false;
  String? erro;
  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() {
      carregando = true;
      erro = null;
    });
    try {
      final dados = await widget.api.chamar('amizades');
      if (mounted) {
        setState(() =>
            lista = (dados['amizades'] as List).cast<Map<String, dynamic>>());
      }
    } on FalhaSocial catch (e) {
      if (mounted) setState(() => erro = e.mensagem);
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> responder(int id, bool aceitar) async {
    if (ocupado) return;
    setState(() {
      ocupado = true;
      erro = null;
    });
    try {
      await widget.api.chamar(
          'responder', {'usuario_id': '$id', 'aceitar': aceitar ? '1' : '0'});
      if (mounted) await carregar();
    } on FalhaSocial catch (e) {
      if (mounted) setState(() => erro = e.mensagem);
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Amizades'), actions: [
          IconButton(
              tooltip: 'Atualizar amizades',
              onPressed: carregando || ocupado ? null : carregar,
              icon: const Icon(Icons.refresh))
        ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (carregando || ocupado) const LinearProgressIndicator(),
          if (erro != null)
            Text(erro!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          for (final grupo in ['recebido', 'enviado', 'amigo']) ...[
            Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 12),
                child: Text(
                    {
                      'recebido': 'Solicitações recebidas',
                      'enviado': 'Solicitações enviadas',
                      'amigo': 'Seus amigos'
                    }[grupo]!,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold))),
            if (!lista.any((p) => p['status'] == grupo) && !carregando)
              const Text('Nenhum usuário nesta lista.'),
            for (final p in lista.where((p) => p['status'] == grupo))
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['nome'] as String,
                                style: const TextStyle(fontSize: 18)),
                            if (grupo == 'recebido')
                              Wrap(spacing: 12, children: [
                                FilledButton(
                                    onPressed: ocupado
                                        ? null
                                        : () => responder(p['id'] as int, true),
                                    child: const Text('Aprovar')),
                                TextButton(
                                    onPressed: ocupado
                                        ? null
                                        : () =>
                                            responder(p['id'] as int, false),
                                    child: const Text('Recusar')),
                              ]),
                          ]))),
          ],
        ]),
      );
}

class ComentariosSocial extends StatefulWidget {
  const ComentariosSocial(
      {super.key, required this.api, required this.postagem});
  final SocialApi api;
  final int postagem;
  @override
  State<ComentariosSocial> createState() => _ComentariosSocialState();
}

class _ComentariosSocialState extends State<ComentariosSocial> {
  final texto = TextEditingController();
  final List<Map<String, dynamic>> comentarios = [];
  bool carregando = false, enviando = false, pode = false, mais = false;
  String? erro;
  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar({bool continuar = false}) async {
    setState(() {
      carregando = true;
      erro = null;
    });
    try {
      final dados = await widget.api.chamar('comentarios', {
        'publicacao_id': '${widget.postagem}',
        if (continuar && comentarios.isNotEmpty)
          'apos': '${comentarios.last['id']}'
      });
      if (!mounted) return;
      setState(() {
        if (!continuar) comentarios.clear();
        comentarios.addAll(
            (dados['comentarios'] as List).cast<Map<String, dynamic>>());
        pode = dados['pode_comentar'] == true;
        mais = dados['mais'] == true;
      });
    } on FalhaSocial catch (e) {
      if (mounted) setState(() => erro = e.mensagem);
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> enviar() async {
    if (enviando || texto.text.trim().isEmpty) return;
    setState(() {
      enviando = true;
      erro = null;
    });
    try {
      await widget.api.chamar('comentar',
          {'publicacao_id': '${widget.postagem}', 'texto': texto.text.trim()});
      if (!mounted) return;
      texto.clear();
      await carregar();
    } on FalhaSocial catch (e) {
      if (mounted) setState(() => erro = e.mensagem);
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  @override
  void dispose() {
    texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !enviando,
      child: AlertDialog(
        title: const Text('Comentários'),
        content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  if (carregando) const LinearProgressIndicator(),
                  for (final c in comentarios)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['nome'] as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(c['texto'] as String),
                            ])),
                  if (!carregando && comentarios.isEmpty)
                    const Text('Ainda não há comentários.'),
                  if (mais)
                    TextButton(
                        onPressed: carregando || enviando
                            ? null
                            : () => carregar(continuar: true),
                        child: const Text('Carregar mais comentários')),
                  if (erro != null)
                    Text(erro!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  if (erro != null && !carregando)
                    TextButton(
                        onPressed: enviando ? null : () => carregar(),
                        child: const Text('Atualizar comentários')),
                  const SizedBox(height: 16),
                  if (pode) ...[
                    TextField(
                        controller: texto,
                        enabled: !enviando && !carregando,
                        maxLength: 280,
                        minLines: 1,
                        maxLines: 4,
                        onChanged: (_) => setState(() {}),
                        decoration:
                            const InputDecoration(labelText: 'Seu comentário')),
                    FilledButton(
                        onPressed:
                            enviando || carregando || texto.text.trim().isEmpty
                                ? null
                                : enviar,
                        child: Text(enviando ? 'Enviando...' : 'Comentar')),
                  ] else if (!carregando)
                    const Text(
                        'Para comentar, solicite amizade ao autor e aguarde a aprovação.'),
                ]))),
        actions: [
          TextButton(
              onPressed: enviando ? null : () => Navigator.pop(context),
              child: const Text('Fechar'))
        ],
      ));
}
