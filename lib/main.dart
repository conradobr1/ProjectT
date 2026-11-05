import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'galeria.dart';

void main() => runApp(const MiniX());

class MiniX extends StatelessWidget {
  const MiniX({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mini X',
        theme: ThemeData.dark(useMaterial3: true).copyWith(
          scaffoldBackgroundColor: const Color(0xff080b10),
          colorScheme: const ColorScheme.dark(primary: Color(0xff1d9bf0)),
          inputDecorationTheme:
              const InputDecorationTheme(border: OutlineInputBorder()),
        ),
        home: const AppTwitter(),
      );
}

class AppTwitter extends StatefulWidget {
  const AppTwitter({super.key});
  @override
  State<AppTwitter> createState() => _AppTwitterState();
}

class _AppTwitterState extends State<AppTwitter> {
  final controller = TextEditingController();
  final descricao = TextEditingController();
  int versaoGaleria = 0;
  final servidor = TextEditingController(
      text: const String.fromEnvironment('API_URL',
          defaultValue: 'http://10.0.2.2/api'));
  final List<Map<String, dynamic>> historico = [];
  final picker = ImagePicker();
  int indice = -1;
  int aba = 0;
  bool ocupado = false;
  XFile? foto;
  String aviso = 'Toque em Próximo para ler as publicações.';

  Uri url(String pagina, Map<String, String> parametros) {
    final base = servidor.text.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/$pagina');
    if (!uri.hasAuthority || !['http', 'https'].contains(uri.scheme)) {
      throw const FormatException(
          'Informe uma URL HTTP válida nas configurações.');
    }
    return uri.replace(queryParameters: parametros);
  }

  void mensagem(String texto) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));
    }
  }

  Future<void> enviar() async {
    final texto = controller.text.trim();
    if (ocupado || texto.isEmpty) return;
    setState(() => ocupado = true);
    try {
      final resposta = await http
          .get(url('salva.php', {'txt': texto}))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (resposta.statusCode != 200 ||
          !utf8.decode(resposta.bodyBytes).contains('Texto salvo!')) {
        throw const HttpException('O servidor não confirmou a publicação.');
      }
      controller.clear();
      FocusScope.of(context).unfocus();
      mensagem('Publicação enviada! Toque em Próximo para continuar lendo.');
    } catch (_) {
      mensagem('Não foi possível publicar. Confira o servidor e sua conexão.');
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> proximo() async {
    if (ocupado) return;
    if (indice < historico.length - 1) {
      setState(() => indice++);
      return;
    }
    setState(() => ocupado = true);
    final ultimoId = historico.isEmpty ? 0 : historico.last['id'] as int;
    try {
      final resposta = await http
          .get(url('busca.php', {'id': '$ultimoId'}))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (resposta.statusCode != 200) {
        throw const HttpException('Falha na consulta');
      }
      final dados = jsonDecode(utf8.decode(resposta.bodyBytes));
      if (dados == null || (dados is Map && dados.isEmpty)) {
        setState(() => aviso =
            'Você chegou ao fim. Tente novamente após uma nova publicação.');
        mensagem('Não há próximo texto disponível.');
        return;
      }
      if (dados is! Map || dados['texto'] is! String) {
        throw const FormatException();
      }
      final id = int.tryParse('${dados['id']}');
      if (id == null || id <= ultimoId) throw const FormatException();
      setState(() {
        historico.add({'id': id, 'texto': dados['texto']});
        indice = historico.length - 1;
        aviso = '';
      });
    } catch (_) {
      mensagem('Não foi possível buscar o texto. Confira a API e a conexão.');
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> tirarFoto() async {
    if (ocupado) return;
    setState(() => ocupado = true);
    try {
      final imagem = await picker.pickImage(
          source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
      if (mounted && imagem != null) setState(() => foto = imagem);
    } catch (_) {
      mensagem(
          'Não foi possível abrir a câmera. Verifique a permissão do aplicativo.');
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> configurar() async {
    final edicao = TextEditingController(text: servidor.text);
    final valor = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Servidor da API'),
              content: TextField(
                  controller: edicao,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                      labelText: 'URL', hintText: 'http://192.168.0.10/api')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, edicao.text.trim()),
                    child: const Text('Aplicar'))
              ],
            ));
    if (!mounted || valor == null) return;
    final uri = Uri.tryParse(valor);
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme)) {
      mensagem('Informe uma URL HTTP válida.');
      return;
    }
    setState(() {
      servidor.text = valor;
      historico.clear();
      indice = -1;
      aviso = 'Servidor alterado. Toque em Próximo.';
    });
  }

  Future<void> enviarFoto() async {
    if (ocupado || foto == null || descricao.text.trim().isEmpty) return;
    setState(() => ocupado = true);
    try {
      if (await foto!.length() > 8 * 1024 * 1024) {
        mensagem('A foto deve ter no máximo 8 MB.');
        return;
      }
      final pedido = http.MultipartRequest('POST', url('upload.php', {}));
      pedido.fields['descricao'] = descricao.text.trim();
      pedido.files.add(await http.MultipartFile.fromPath('foto', foto!.path));
      final resposta = await http.Response.fromStream(
          await pedido.send().timeout(const Duration(seconds: 30)));
      final dados = jsonDecode(utf8.decode(resposta.bodyBytes));
      if (!mounted) return;
      if (resposta.statusCode != 201) {
        mensagem(dados is Map
            ? '${dados['erro']}'
            : 'Não foi possível enviar a foto.');
        return;
      }
      setState(() {
        foto = null;
        descricao.clear();
        versaoGaleria++;
        aba = 2;
      });
      mensagem('Foto e descrição enviadas com sucesso!');
    } catch (_) {
      mensagem('Falha ao enviar a foto. Confira o servidor e a conexão.');
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    descricao.dispose();
    servidor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('𝕏  Mini X',
                style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                  onPressed: ocupado ? null : configurar,
                  tooltip: 'Configurar servidor',
                  icon: const Icon(Icons.settings_outlined))
            ]),
        body: aba == 2
            ? Galeria(
                key: ValueKey('${servidor.text}-$versaoGaleria'),
                baseUrl: url('fotos.php', {}),
              )
            : SafeArea(
                child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: aba == 0
                              ? [
                                  const Text('Compartilhe uma ideia',
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  const Text(
                                      'Textos curtos. Conversas simples.',
                                      style: TextStyle(color: Colors.grey)),
                                  const SizedBox(height: 24),
                                  TextField(
                                      controller: controller,
                                      maxLength: 280,
                                      minLines: 3,
                                      maxLines: 6,
                                      enabled: !ocupado,
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(
                                          hintText: 'O que está acontecendo?')),
                                  Align(
                                      alignment: Alignment.centerRight,
                                      child: FilledButton.icon(
                                          onPressed: ocupado ||
                                                  controller.text.trim().isEmpty
                                              ? null
                                              : enviar,
                                          icon: const Icon(Icons.send_outlined,
                                              size: 18),
                                          label: const Text('Publicar'))),
                                  const Divider(height: 48),
                                  const Text('Publicações',
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 16),
                                  Card(
                                      child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(children: [
                                                  const CircleAvatar(
                                                      child: Icon(Icons
                                                          .person_outline)),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                      child: Text(
                                                          indice < 0
                                                              ? 'Comunidade'
                                                              : 'Comunidade • #${historico[indice]['id']}',
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)))
                                                ]),
                                                const SizedBox(height: 20),
                                                SelectableText(
                                                    indice < 0
                                                        ? aviso
                                                        : historico[indice]
                                                            ['texto'] as String,
                                                    style: const TextStyle(
                                                        fontSize: 19,
                                                        height: 1.5)),
                                              ]))),
                                  if (aviso.isNotEmpty && indice >= 0)
                                    Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(aviso)),
                                  const SizedBox(height: 16),
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        OutlinedButton.icon(
                                            onPressed: ocupado || indice <= 0
                                                ? null
                                                : () =>
                                                    setState(() => indice--),
                                            icon: const Icon(Icons.arrow_back),
                                            label: const Text('Voltar')),
                                        FilledButton.icon(
                                            onPressed: ocupado ? null : proximo,
                                            icon:
                                                const Icon(Icons.arrow_forward),
                                            label: const Text('Próximo')),
                                      ]),
                                  if (ocupado)
                                    const Padding(
                                        padding: EdgeInsets.only(top: 20),
                                        child: LinearProgressIndicator()),
                                ]
                              : [
                                  const Text('Um registro do seu dia',
                                      style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  const Text(
                                      'Tire uma foto, escreva uma descrição e envie para a galeria do site.'),
                                  const SizedBox(height: 24),
                                  if (foto == null)
                                    const SizedBox(
                                        height: 260,
                                        child: Icon(Icons.add_a_photo_outlined,
                                            size: 72, color: Colors.grey))
                                  else
                                    ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Image.file(File(foto!.path),
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const Text(
                                                    'Não foi possível exibir a foto. Tire outra.'))),
                                  const SizedBox(height: 24),
                                  FilledButton.icon(
                                      onPressed: ocupado ? null : tirarFoto,
                                      icon:
                                          const Icon(Icons.camera_alt_outlined),
                                      label: Text(foto == null
                                          ? 'Tirar foto'
                                          : 'Tirar outra foto')),
                                  const SizedBox(height: 20),
                                  TextField(
                                    controller: descricao,
                                    enabled: !ocupado,
                                    maxLength: 280,
                                    minLines: 2,
                                    maxLines: 4,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      labelText: 'Descrição da foto',
                                      hintText: 'Conte sobre este momento',
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: ocupado ||
                                            foto == null ||
                                            descricao.text.trim().isEmpty
                                        ? null
                                        : enviarFoto,
                                    icon:
                                        const Icon(Icons.cloud_upload_outlined),
                                    label:
                                        const Text('Enviar foto para o site'),
                                  ),
                                  if (ocupado) const LinearProgressIndicator(),
                                ]),
                    ))),
        bottomNavigationBar: NavigationBar(
            selectedIndex: aba,
            onDestinationSelected: (valor) => setState(() => aba = valor),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Início'),
              NavigationDestination(
                  icon: Icon(Icons.camera_alt_outlined),
                  selectedIcon: Icon(Icons.camera_alt),
                  label: 'Câmera'),
              NavigationDestination(
                  icon: Icon(Icons.photo_library_outlined),
                  selectedIcon: Icon(Icons.photo_library),
                  label: 'Galeria')
            ]),
      );
}
