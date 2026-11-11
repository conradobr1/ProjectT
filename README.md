# Mini X - atividade completa

App Flutter Android simples inspirado no X, com API PHP e banco MySQL.

[Baixar APK Android](https://github.com/conradobr1/ProjectT/raw/refs/heads/main/dist/mini_x.apk)

Para continuar o desenvolvimento, clone este repositório e abra a pasta que contém `pubspec.yaml` no Android Studio. Instale os plugins Flutter e Dart e execute `flutter pub get`.

## Funções

- Publicar textos e ler o próximo texto por ID; voltar pelo histórico da sessão.
- Tirar uma foto com image_picker e exibir a imagem capturada.
- Enviar a foto com descrição por multipart/form-data para o site PHP.
- Consultar todas as fotos salvas no servidor e navegar uma por vez na aba Galeria.
- Site PHP com formulário de foto + descrição e galeria com todas as fotos.

## Usar neste computador

1. Mantenha Apache e MySQL ligados no XAMPP.
2. Abra http://localhost/api/ para acessar o site de fotos.
3. No emulador, o app usa http://10.0.2.2/api por padrão.
4. Na aba Câmera, tire uma foto, escreva a descrição e toque em Enviar foto para o site.
5. A aba Galeria abre após o envio. Use Anterior, Próxima foto e Atualizar.
6. Fotos enviadas pelo site também aparecem no app após atualizar.

No celular físico, use a engrenagem para informar http://IP_DO_COMPUTADOR/api. Computador e celular precisam estar na mesma rede, com acesso ao Apache liberado. A configuração editada vale durante a sessão.

## Instalar em outro computador

1. Inicie Apache e MySQL no XAMPP.
2. Importe api/banco.sql pelo phpMyAdmin para criar o banco mini_x e as duas tabelas.
3. Copie os arquivos PHP de api para C:/xampp/htdocs/api.
4. Ajuste as credenciais MySQL em api/conexao.php.
5. A pasta api/uploads será criada automaticamente no primeiro envio; PHP precisa poder escrever nela.
6. Em uma instalação anterior que já tenha publicações, importe somente api/fotos.sql para adicionar a tabela de fotos sem apagar os textos.
7. Abra a pasta mini_x no Android Studio (a pasta que contém pubspec.yaml, não o APK).

```sh
flutter pub get
flutter run
flutter build apk
```

JDK 17, compileSdk 34 e Kotlin 1.8.22. O APK usa a assinatura de depuração para a atividade, sem configuração de distribuição em loja.

## API

- salva.php?txt=texto: salva texto e retorna Texto salvo!
- busca.php?id=0: retorna o registro de menor ID maior que o informado, ou null.
- POST upload.php: campos foto (arquivo) e descricao; retorna HTTP 201 com ID, URL relativa e descrição.
- fotos.php: retorna a lista de fotos com id, url, descricao e criado_em.
- index.php: formulário e galeria do site.

Fotos aceitas: JPEG, PNG e WebP, até 8 MB, respeitando também upload_max_filesize e post_max_size do PHP. Se precisar aumentar o limite, ajuste php.ini e reinicie o Apache. Arquivos ficam em uploads; nome do arquivo e descrição ficam no MySQL. Descrições e textos aceitam até 280 caracteres.

A câmera usa o app de câmera do Android por intent. O manifesto declara Internet e suporte opcional a câmera; não é necessário acesso amplo ao armazenamento. HTTP está habilitado para o servidor local da aula.

## Conferência dos exercícios

### Como demonstrar os três requisitos de fotos

Tudo funciona no mesmo projeto e no mesmo aplicativo Flutter:

| Requisito | Implementação | Como conferir |
| --- | --- | --- |
| Site que recebe foto e descrição | [Formulário PHP](api/index.php) e [upload](api/upload.php) | Com Apache e MySQL ligados, abra `http://localhost/api/`, escolha uma foto, escreva a descrição e envie. |
| App que envia fotos para o site | [Tela de câmera e envio](lib/main.dart) | Na aba **Câmera**, tire a foto, preencha a descrição e toque em **Enviar foto para o site**. |
| Janela que mostra todas as fotos, uma por vez | [Galeria Flutter](lib/galeria.dart) e [consulta PHP](api/fotos.php) | Na aba **Galeria**, toque em **Atualizar** e navegue com **Anterior** e **Próxima foto**. O contador mostra a posição na lista. |

As fotos enviadas pelo app aparecem no site, e as enviadas pelo site aparecem no app após atualizar a galeria. `localhost` se refere ao computador com XAMPP; no emulador Android o endereço é `http://10.0.2.2/api/`. O GitHub guarda o código e o APK; o PHP e o MySQL precisam ser executados no XAMPP ou em uma hospedagem compatível.

- API que salva texto no banco: implementada.
- API que retorna JSON do próximo ID: implementada.
- App que envia e lê textos: implementado.
- Foto com image_picker e visualização local: implementada.
- Foto enviada ao site PHP: implementada.
- Exibição de todas as fotos do site: implementada no site e na consulta do app.
- Site que recebe foto e descrição: implementado.
- Janela do app com fotos uma por vez: implementada.

## Validação

Análise estática do Flutter sem problemas; três testes de interface aprovados (publicações, galeria vazia e navegação de fotos). Sintaxe de todos os PHP validada. Upload real no XAMPP retornou 201; a descrição foi recuperada na listagem e os bytes da imagem foram conferidos por HTTP. Arquivo inválido e descrição vazia foram rejeitados. O teste temporário foi removido da galeria.

A captura física da câmera depende do dispositivo. Para testar, tire uma foto no emulador/celular, envie com descrição e confira tanto a Galeria do app quanto http://localhost/api/ no computador. O projeto não foi enviado ao formulário do professor.

## Login e cadastro

Ao abrir o app, entre com e-mail e senha ou toque em **Criar uma conta** e informe nome, e-mail e senha (8 a 72 bytes UTF-8). O cadastro entra automaticamente no app. Use **Sair da conta** no topo para encerrar a sessão local.

- Importe `api/usuarios.sql` no MySQL para adicionar a tabela sem apagar os dados existentes. Em instalações novas, `api/banco.sql` já contém todas as tabelas.
- Copie também `autenticacao.php`, `cadastro.php` e `login.php` para a pasta da API no servidor, junto de `conexao.php`.
- Na tela de entrada, **Configurar servidor** permite informar a URL da API. No emulador: `http://10.0.2.2/api`. No celular, use o IP do computador.
- `POST cadastro.php`: campos `nome`, `email`, `senha`; retorna 201 com `usuario`. E-mail repetido retorna 409.
- `POST login.php`: campos `email`, `senha`; retorna 200 com `usuario`. Credenciais incorretas retornam 401.
- O MySQL guarda somente o hash da senha (`password_hash` / `password_verify`). As consultas usam parâmetros preparados.
- O `shared_preferences` salva o perfil (ID, nome, e-mail) e a URL da API para manter o login entre aberturas. A senha não é salva no celular.
- Este fluxo mantém uma sessão local. Os endpoints anteriores de publicações/fotos continuam públicos, sem autorização por usuário. Em hospedagem pública, use HTTPS e implemente tokens de sessão e limitação de tentativas antes de expor dados privados.
