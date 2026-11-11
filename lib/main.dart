import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'galeria.dart';
import 'acesso.dart';
import 'social.dart';

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
        home: Acesso(
            conteudo: (servidor, nome, token, sair) => AppTwitter(
                baseUrl: servidor,
                nomeUsuario: nome,
                token: token,
                aoSair: sair)),
      );
}

class AppTwitter extends StatefulWidget {
  const AppTwitter(
      {super.key,
      this.baseUrl = apiPadrao,
      this.nomeUsuario,
      this.token,
      this.aoSair});
  final String baseUrl;
  final String? nomeUsuario;
  final String? token;
  final Future<void> Function()? aoSair;
  @override
  State<AppTwitter> createState() => _AppTwitterState();
}

class _AppTwitterState extends State<AppTwitter> {
  final controller = TextEditingController();
  final descricao = TextEditingController();
  int versaoGaleria = 0;
  late final servidor = TextEditingController(text: widget.baseUrl);
  int versaoFeed = 0;
  final picker = ImagePicker();
  int aba = 0;
  bool ocupado = false;
  XFile? foto;
  XFile? fotoPostagem;

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
      if (widget.token == null || widget.token!.isEmpty) {
        mensagem('Entre na sua conta para publicar.');
        return;
      }
      if (fotoPostagem != null &&
          await fotoPostagem!.length() > 8 * 1024 * 1024) {
        mensagem('A foto deve ter no máximo 8 MB.');
        return;
      }
      final pedido = http.MultipartRequest('POST', url('postagem.php', {}));
      pedido.fields.addAll({'texto': texto, 'token': widget.token!});
      if (fotoPostagem != null) {
        pedido.files
            .add(await http.MultipartFile.fromPath('foto', fotoPostagem!.path));
      }
      final resposta = await http.Response.fromStream(
              await pedido.send().timeout(const Duration(seconds: 30)))
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      final dados = jsonDecode(utf8.decode(resposta.bodyBytes));
      if (resposta.statusCode != 201) {
        mensagem(dados is Map && dados['erro'] is String
            ? dados['erro'] as String
            : 'Não foi possível publicar.');
        return;
      }
      setState(() {
        controller.clear();
        fotoPostagem = null;
        versaoFeed++;
      });
      FocusScope.of(context).unfocus();
      mensagem('Publicação enviada!');
    } catch (_) {
      mensagem('Não foi possível publicar. Confira o servidor e sua conexão.');
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> anexarFoto(ImageSource origem) async {
    if (ocupado) return;
    setState(() => ocupado = true);
    try {
      final imagem = await picker.pickImage(
          source: origem, maxWidth: 1600, imageQuality: 85);
      if (imagem != null) {
        if (await imagem.length() > 8 * 1024 * 1024) {
          mensagem('A foto deve ter no máximo 8 MB.');
          return;
        }
        if (mounted) setState(() => fotoPostagem = imagem);
      }
    } catch (_) {
      mensagem('Não foi possível selecionar a foto. Tente novamente.');
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
      versaoFeed++;
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
              if (widget.aoSair != null)
                IconButton(
                    onPressed: ocupado ? null : widget.aoSair,
                    tooltip: 'Sair da conta',
                    icon: const Icon(Icons.logout)),
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
                                  Wrap(spacing: 8, children: [
                                    TextButton.icon(
                                        onPressed: ocupado
                                            ? null
                                            : () =>
                                                anexarFoto(ImageSource.gallery),
                                        icon: const Icon(Icons.image_outlined),
                                        label: const Text('Adicionar foto')),
                                    TextButton.icon(
                                        onPressed: ocupado
                                            ? null
                                            : () =>
                                                anexarFoto(ImageSource.camera),
                                        icon: const Icon(
                                            Icons.camera_alt_outlined),
                                        label: const Text('Câmera')),
                                  ]),
                                  if (fotoPostagem != null) ...[
                                    Image.file(File(fotoPostagem!.path),
                                        height: 180,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const Text(
                                            'Prévia indisponível. Selecione outra foto.')),
                                    TextButton.icon(
                                        onPressed: ocupado
                                            ? null
                                            : () => setState(
                                                () => fotoPostagem = null),
                                        icon: const Icon(Icons.close),
                                        label: const Text('Remover foto')),
                                  ],
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
                                  FeedSocial(
                                      key: ValueKey(
                                          '${servidor.text}-$versaoFeed'),
                                      baseUrl: servidor.text,
                                      token: widget.token ?? ''),
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
