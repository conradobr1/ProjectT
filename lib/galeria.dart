import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Galeria extends StatefulWidget {
  const Galeria({super.key, required this.baseUrl});
  final Uri baseUrl;
  @override
  State<Galeria> createState() => _GaleriaState();
}

class _GaleriaState extends State<Galeria> {
  List<Map<String, dynamic>> fotos = [];
  int indice = 0;
  bool carregando = true;
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
      final resposta =
          await http.get(widget.baseUrl).timeout(const Duration(seconds: 15));
      if (resposta.statusCode != 200) throw const FormatException();
      final dados = jsonDecode(utf8.decode(resposta.bodyBytes));
      if (dados is! List) throw const FormatException();
      final lista = <Map<String, dynamic>>[];
      for (final item in dados) {
        if (item is! Map<String, dynamic> ||
            item['url'] is! String ||
            item['descricao'] is! String) {
          throw const FormatException();
        }
        lista.add(item);
      }
      if (!mounted) return;
      setState(() {
        fotos = lista;
        indice = 0;
      });
    } catch (_) {
      if (mounted) {
        setState(() => erro =
            'Não foi possível carregar as fotos. Confira a API e toque em Atualizar.');
      }
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Galeria da comunidade',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Todas as fotos do site, uma por vez.'),
          const SizedBox(height: 16),
          Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                  onPressed: carregando ? null : carregar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar'))),
          if (carregando) const LinearProgressIndicator(),
          if (erro != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(erro!)),
          if (!carregando && erro == null && fotos.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Text(
                    'Nenhuma foto publicada ainda. Envie a primeira pela aba Câmera.')),
          if (fotos.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Foto ${indice + 1} de ${fotos.length}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  widget.baseUrl
                      .resolve(fotos[indice]['url'] as String)
                      .toString(),
                  key: ValueKey(fotos[indice]['id']),
                  height: 340,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progresso) => progresso == null
                      ? child
                      : const SizedBox(
                          height: 340,
                          child: Center(child: CircularProgressIndicator())),
                  errorBuilder: (_, __, ___) => const SizedBox(
                      height: 180,
                      child: Center(
                          child: Text(
                              'Imagem indisponível. Tente atualizar a galeria.'))),
                )),
            const SizedBox(height: 20),
            SelectableText(fotos[indice]['descricao'] as String,
                style: const TextStyle(fontSize: 19, height: 1.5)),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              OutlinedButton.icon(
                  onPressed: carregando || indice == 0
                      ? null
                      : () => setState(() => indice--),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Anterior')),
              FilledButton.icon(
                  onPressed: carregando || indice >= fotos.length - 1
                      ? null
                      : () => setState(() => indice++),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Próxima foto')),
            ]),
          ],
        ]),
      )));
}
