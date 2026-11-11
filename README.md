# Mini X - atividade completa

App Flutter Android simples inspirado no X, com API PHP e banco MySQL.

[Baixar APK Android](https://github.com/conradobr1/ProjectT/raw/refs/heads/main/dist/mini_x.apk)

Para continuar o desenvolvimento, clone este repositório e abra a pasta que contém `pubspec.yaml` no Android Studio. Instale os plugins Flutter e Dart e execute `flutter pub get`.

## Funções

- Publicar texto com foto opcional, ver as postagens de todos, curtir e interagir com amigos.
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

- POST postagem.php (ou salva.php): recebe token, texto e foto opcional; retorna 201 com ID e foto_url.
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

- API que salva texto e foto opcional no banco: implementada.
- API que retorna JSON do próximo ID: implementada.
- App que envia e lê textos: implementado.
- Foto com image_picker e visualização local: implementada.
- Foto enviada ao site PHP: implementada.
- Exibição de todas as fotos do site: implementada no site e na consulta do app.
- Site que recebe foto e descrição: implementado.
- Janela do app com fotos uma por vez: implementada.

## Validação

Análise estática do Flutter sem problemas; testes de interface aprovados (acesso, publicações, galeria e interações sociais). Sintaxe de todos os PHP validada. Upload real no XAMPP retornou 201; a descrição foi recuperada na listagem e os bytes da imagem foram conferidos por HTTP. Arquivo inválido e descrição vazia foram rejeitados. O teste temporário foi removido da galeria.

A captura física da câmera depende do dispositivo. Para testar, tire uma foto no emulador/celular, envie com descrição e confira tanto a Galeria do app quanto http://localhost/api/ no computador. O projeto não foi enviado ao formulário do professor.

## Login e cadastro

Ao abrir o app, entre com e-mail e senha ou toque em **Criar uma conta** e informe nome, e-mail e senha (8 a 72 bytes UTF-8). O cadastro entra automaticamente no app. Use **Sair da conta** no topo para encerrar a sessão local.

- Importe `api/usuarios.sql` no MySQL para adicionar a tabela sem apagar os dados existentes. Em instalações novas, `api/banco.sql` já contém todas as tabelas.
- Copie também `autenticacao.php`, `cadastro.php` e `login.php` para a pasta da API no servidor, junto de `conexao.php`.
- Na tela de entrada, **Configurar servidor** permite informar a URL da API. No emulador: `http://10.0.2.2/api`. No celular, use o IP do computador.
- `POST cadastro.php`: campos `nome`, `email`, `senha`; retorna 201 com `usuario`. E-mail repetido retorna 409.
- `POST login.php`: campos `email`, `senha`; retorna 200 com `usuario`. Credenciais incorretas retornam 401.
- O MySQL guarda somente o hash da senha (`password_hash` / `password_verify`). As consultas usam parâmetros preparados.
- O `shared_preferences` salva o perfil (ID, nome, e-mail), o token da sessão e a URL da API para manter o login entre aberturas. A senha não é salva no celular.
- O servidor valida o token para publicar e associa o autor à sessão. A leitura das publicações e a galeria antiga são públicas. Em hospedagem pública, use HTTPS e limite tentativas de login.

## Postagem com foto opcional

Na aba **Início**, escreva um texto de até 280 caracteres e, se quiser, toque em **Adicionar foto** (galeria) ou **Câmera**. A imagem aparece na prévia e pode ser removida antes de publicar. As publicações exibem autor, texto e foto, quando enviada. O texto é obrigatório; a imagem é opcional (JPEG, PNG ou WebP, até 8 MB).

Para atualizar um banco existente sem apagar publicações, execute `C:/xampp/php/php.exe api/migrar_postagens.php`. A migração pode ser repetida. Copie os PHP atualizados para a pasta da API. Para banco novo, importe `api/banco.sql`.

Login e cadastro agora retornam um token válido por 30 dias, salvo junto do perfil no `shared_preferences`. O banco guarda apenas o hash do token. O endpoint de postagem valida a sessão e determina o autor no servidor. Instalações com perfil antigo sem token precisam entrar novamente. A foto da publicação é independente dos envios da aba Câmera/Galeria.

## Interação e amizade

O **Início** exibe um feed com as postagens de todos, incluindo nome do autor, texto, foto opcional, curtidas e comentários. Use **Carregar mais postagens** para continuar e o ícone de atualizar para buscar novidades. Cada pessoa pode curtir uma vez por postagem; tocar novamente remove sua curtida.

Na postagem de outra pessoa, toque em **Solicitar amizade**. Abra **Amizades** no cabeçalho do feed para ver solicitações recebidas, enviadas e amigos. Somente o destinatário pode **Aprovar** ou **Recusar** o pedido. Pedidos repetidos ou em sentidos opostos não criam amizades duplicadas nem aprovação automática.

Todos os usuários logados podem ler as postagens e os comentários. Só é permitido **comentar em postagens de amigos com amizade aprovada**, nos dois sentidos. Antes da aprovação o campo de comentário fica bloqueado; o PHP também verifica a amizade e a sessão em cada envio. Comentários têm de 1 a 280 caracteres. A regra também impede comentar a própria postagem, pois o autor não é amigo de si mesmo.

### Atualizar banco e API

Execute `C:/xampp/php/php.exe api/migrar_postagens.php` para criar as tabelas de amizades, curtidas e comentários sem apagar dados. A migração pode ser repetida. Instalações novas podem importar `api/banco.sql`. Copie os PHP atualizados para o servidor; se executar a migração na cópia do servidor, copie também `sessoes.sql` e `interacoes.sql`.

`POST social.php` recebe `token` da sessão e `acao`:

- `feed`: postagens de todos, 20 por página; `antes` é o último ID da página anterior.
- `curtir`: `publicacao_id` e `curtir` (`1` para curtir, `0` para remover).
- `comentarios`: `publicacao_id`; `apos` pagina a lista, com 30 comentários por página.
- `comentar`: `publicacao_id` e `texto`; exige amizade aprovada com o autor.
- `solicitar`: `usuario_id` do autor.
- `amizades`: lista de amigos e solicitações recebidas/enviadas.
- `responder`: `usuario_id` do solicitante e `aceitar` (`1` aprovar, `0` recusar).

As ações determinam a identidade pelo token e não confiam em um ID do usuário logado enviado pelo aplicativo. Os testes Flutter cobrem o feed, curtidas, pedidos, aprovação e comentários. Com o XAMPP local ligado, execute `py -3 test/api_social_test.py` para conferir as regras e a paginação na API real. Esse teste cria e remove somente suas três contas temporárias e os registros delas.
