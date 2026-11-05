<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Mini X · Fotos</title>
  <style>
    *{box-sizing:border-box}body{margin:0;background:#080b10;color:#edf1f7;font:16px system-ui,sans-serif}main{max-width:1000px;margin:auto;padding:32px 20px}header{border-bottom:1px solid #293240;margin-bottom:28px}h1{font-size:32px}p{color:#abb7c9}form{background:#141b25;padding:24px;border-radius:18px;display:grid;gap:14px;max-width:600px}input,textarea,button{font:inherit}textarea,input{width:100%;background:#080b10;color:#edf1f7;padding:12px;border:1px solid #526078;border-radius:8px}button{border:0;border-radius:24px;padding:12px 22px;background:#1d9bf0;color:#fff;cursor:pointer;justify-self:start}button:disabled{opacity:.5}#fotos{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:20px}figure{margin:0;border:1px solid #293240;border-radius:16px;overflow:hidden;background:#141b25}figure img{width:100%;height:260px;object-fit:contain;background:#000}figcaption{padding:16px;white-space:pre-wrap;overflow-wrap:anywhere}#mensagem{min-height:24px;color:#a8d9ff}label{display:grid;gap:8px}
  </style>
</head>
<body><main>
  <header><h1>𝕏 Mini X · Fotos</h1><p>Um registro do seu dia, com uma história para contar.</p></header>
  <h2>Enviar foto</h2>
  <form id="envio" enctype="multipart/form-data" method="post" action="upload.php">
    <label>Foto<input type="file" name="foto" accept="image/jpeg,image/png,image/webp" required></label>
    <label>Descrição<textarea name="descricao" maxlength="280" rows="3" placeholder="Conte sobre esta foto" required></textarea></label>
    <small>JPEG, PNG ou WebP. Até 8 MB, respeitando o limite configurado no PHP.</small>
    <button id="enviar">Enviar foto</button>
  </form>
  <p id="mensagem" role="status" aria-live="polite"></p>
  <h2>Todas as fotos</h2><button type="button" id="atualizar">Atualizar galeria</button>
  <p id="estado" role="status"></p><section id="fotos" aria-label="Galeria de fotos"></section>
  <script>
    const formulario=document.querySelector('#envio'), mensagem=document.querySelector('#mensagem'), estado=document.querySelector('#estado'), galeria=document.querySelector('#fotos');
    async function carregar(){
      estado.textContent='Carregando fotos…';
      try{
        const resposta=await fetch('fotos.php',{cache:'no-store'}), fotos=await resposta.json();
        if(!resposta.ok||!Array.isArray(fotos))throw Error('Não foi possível carregar a galeria.');
        galeria.replaceChildren();
        for(const foto of fotos){
          const figura=document.createElement('figure'), imagem=document.createElement('img'), legenda=document.createElement('figcaption');
          imagem.src=foto.url;imagem.alt=foto.descricao;imagem.loading='lazy';legenda.textContent=foto.descricao;
          figura.append(imagem,legenda);galeria.append(figura);
        }
        estado.textContent=fotos.length?`${fotos.length} foto(s) publicada(s).`:'Ainda não há fotos. Envie a primeira!';
      }catch(erro){estado.textContent=erro.message;}
    }
    formulario.addEventListener('submit',async(evento)=>{
      evento.preventDefault();
      if(!formulario.descricao.value.trim()){mensagem.textContent='Escreva uma descrição.';return;}
      document.querySelector('#enviar').disabled=true;mensagem.textContent='Enviando…';
      try{
        const resposta=await fetch('upload.php',{method:'POST',body:new FormData(formulario)});
        const dados=await resposta.json();
        if(!resposta.ok)throw Error(dados.erro||'Erro ao enviar foto.');
        formulario.reset();mensagem.textContent='Foto enviada com sucesso!';await carregar();
      }catch(erro){mensagem.textContent=erro.message;}
      finally{document.querySelector('#enviar').disabled=false;}
    });
    document.querySelector('#atualizar').addEventListener('click',carregar);carregar();
  </script>
</main></body></html>
