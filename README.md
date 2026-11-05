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
