import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const apiPadrao =
    String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2/api');

class Acesso extends StatefulWidget {
  const Acesso({super.key, required this.conteudo});
  final Widget Function(
      String servidor, String nome, Future<void> Function() sair) conteudo;
  @override
  State<Acesso> createState() => _AcessoState();
}

class _AcessoState extends State<Acesso> {
  final formulario = GlobalKey<FormState>();
  final nome = TextEditingController();
  final email = TextEditingController();
  final senha = TextEditingController();
  final servidor = TextEditingController(text: apiPadrao);
  SharedPreferences? preferencias;
  Map<String, dynamic>? usuario;
  bool carregando = true,
      cadastro = false,
      ocupado = false,
      mostrarSenha = false;
  String? erro;

  @override
  void initState() {
    super.initState();
    restaurar();
  }

  Future<void> restaurar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salvo = prefs.getString('usuario');
      Map<String, dynamic>? dados;
      if (salvo != null) {
        try {
          final valor = jsonDecode(salvo);
          if (valor is Map<String, dynamic> &&
              valor['id'] is int &&
              valor['nome'] is String &&
              valor['email'] is String) dados = valor;
        } catch (_) {
          await prefs.remove('usuario');
        }
      }
      if (!mounted) return;
      setState(() {
        preferencias = prefs;
        servidor.text = prefs.getString('api_url') ?? apiPadrao;
        usuario = dados;
        carregando = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          carregando = false;
          erro = 'Não foi possível carregar a sessão. Reinicie o aplicativo.';
        });
      }
    }
  }

  Future<void> sair() async {
    try {
      if (!await preferencias!.remove('usuario')) throw StateError('Sessão');
      if (!mounted) return;
      setState(() {
        usuario = null;
        senha.clear();
        erro = null;
        cadastro = false;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Não foi possível encerrar a sessão. Tente novamente.')));
      }
    }
  }

  Future<void> enviar() async {
    if (ocupado || !formulario.currentState!.validate()) return;
    setState(() {
      ocupado = true;
      erro = null;
    });
    try {
      final base = servidor.text.trim().replaceFirst(RegExp(r'/+$'), '');
      final resposta = await http.post(
          Uri.parse('$base/${cadastro ? 'cadastro' : 'login'}.php'),
          body: {
            if (cadastro) 'nome': nome.text.trim(),
            'email': email.text.trim(),
            'senha': senha.text,
          }).timeout(const Duration(seconds: 15));
      final dados = jsonDecode(utf8.decode(resposta.bodyBytes));
      if (resposta.statusCode != 200 && resposta.statusCode != 201) {
        throw FormatException(dados is Map && dados['erro'] is String
            ? dados['erro'] as String
            : 'Não foi possível entrar.');
      }
      final perfil = dados['usuario'];
      if (perfil is! Map<String, dynamic> ||
          perfil['id'] is! int ||
          perfil['nome'] is! String ||
          perfil['email'] is! String) {
        throw const FormatException('Resposta inválida do servidor.');
      }
      final prefs = preferencias ?? await SharedPreferences.getInstance();
      if (!await prefs.setString('api_url', base) ||
          !await prefs.setString('usuario', jsonEncode(perfil))) {
        throw StateError('Persistência');
      }
      if (!mounted) return;
      setState(() {
        preferencias = prefs;
        servidor.text = base;
        usuario = perfil;
        senha.clear();
      });
    } on FormatException catch (e) {
      if (mounted) {
        setState(() => erro = e.message.toString().startsWith('Unexpected')
            ? 'Resposta inválida. Confira a URL da API.'
            : e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => erro =
            'Não foi possível entrar. Confira a conexão e o servidor PHP/MySQL.');
      }
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  void dispose() {
    nome.dispose();
    email.dispose();
    senha.dispose();
    servidor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (usuario != null) {
      return widget.conteudo(servidor.text, usuario!['nome'] as String, sair);
    }
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AutofillGroup(
              child: Form(
            key: formulario,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.forum_outlined,
                      size: 56, color: Color(0xff1d9bf0)),
                  const SizedBox(height: 20),
                  Text(cadastro ? 'Crie sua conta' : 'Bem-vindo ao Mini X',
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(cadastro
                      ? 'Cadastre-se para compartilhar suas ideias.'
                      : 'Entre para continuar suas conversas.'),
                  const SizedBox(height: 28),
                  if (cadastro) ...[
                    TextFormField(
                        controller: nome,
                        enabled: !ocupado,
                        autofillHints: const [AutofillHints.name],
                        textCapitalization: TextCapitalization.words,
                        maxLength: 100,
                        decoration: const InputDecoration(labelText: 'Nome'),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Informe seu nome.'
                            : null),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                      controller: email,
                      enabled: !ocupado,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      validator: (v) => !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch((v ?? '').trim())
                          ? 'Informe um e-mail válido.'
                          : null),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: senha,
                      enabled: !ocupado,
                      obscureText: !mostrarSenha,
                      autofillHints: [
                        cadastro
                            ? AutofillHints.newPassword
                            : AutofillHints.password
                      ],
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                          labelText: 'Senha',
                          helperText:
                              cadastro ? 'Use de 8 a 72 bytes (UTF-8).' : null,
                          suffixIcon: IconButton(
                              tooltip: mostrarSenha
                                  ? 'Ocultar senha'
                                  : 'Mostrar senha',
                              onPressed: () =>
                                  setState(() => mostrarSenha = !mostrarSenha),
                              icon: Icon(mostrarSenha
                                  ? Icons.visibility_off
                                  : Icons.visibility))),
                      validator: (v) => (v ?? '').isEmpty
                          ? 'Informe sua senha.'
                          : cadastro &&
                                  (utf8.encode(v!).length < 8 ||
                                      utf8.encode(v).length > 72)
                              ? 'Use uma senha de 8 a 72 bytes.'
                              : null,
                      onFieldSubmitted: (_) => enviar()),
                  const SizedBox(height: 20),
                  if (erro != null)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(erro!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  FilledButton(
                      onPressed: ocupado ? null : enviar,
                      child: Text(ocupado
                          ? 'Aguarde...'
                          : cadastro
                              ? 'Cadastrar'
                              : 'Entrar')),
                  TextButton(
                      onPressed: ocupado
                          ? null
                          : () {
                              setState(() {
                                cadastro = !cadastro;
                                erro = null;
                                senha.clear();
                              });
                              formulario.currentState?.reset();
                            },
                      child: Text(cadastro
                          ? 'Já tenho conta. Entrar'
                          : 'Criar uma conta')),
                  ExpansionTile(
                      title: const Text('Configurar servidor'),
                      tilePadding: EdgeInsets.zero,
                      children: [
                        TextFormField(
                            controller: servidor,
                            enabled: !ocupado,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                                labelText: 'URL da API',
                                hintText: 'http://10.0.2.2/api'),
                            validator: (v) {
                              final uri = Uri.tryParse((v ?? '').trim());
                              return uri == null ||
                                      !uri.hasAuthority ||
                                      !['http', 'https'].contains(uri.scheme) ||
                                      uri.hasQuery ||
                                      uri.hasFragment
                                  ? 'Informe a URL HTTP da API.'
                                  : null;
                            }),
                      ]),
                ]),
          ))),
    ))));
  }
}
