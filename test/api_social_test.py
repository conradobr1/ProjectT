"""Teste de integracao local: XAMPP e banco mini_x devem estar ligados.
Execute: py -3 test/api_social_test.py
Cria tres contas temporarias e remove somente os dados dessas contas ao terminar.
"""
import json
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid

BASE = 'http://localhost/api/'
MYSQL = 'C:/xampp/mysql/bin/mysql.exe'
usuarios = []

def pedido(endpoint, campos, status=200):
    req = urllib.request.Request(BASE + endpoint, data=urllib.parse.urlencode(campos).encode())
    try:
        r = urllib.request.urlopen(req, timeout=15)
    except urllib.error.HTTPError as e:
        r = e
    dados = json.loads(r.read())
    assert r.code == status, (endpoint, campos.get('acao'), r.code, dados)
    return dados

def social(token, acao, status=200, **campos):
    return pedido('social.php', dict(token=token, acao=acao, **campos), status)

def criar(nome):
    email = 'social-' + uuid.uuid4().hex + '@example.com'
    dados = pedido('cadastro.php', dict(nome=nome, email=email, senha='Teste123!'), 201)
    usuarios.append(dados['usuario']['id'])
    return dados['usuario']['id'], dados['token']

def publicar(token, texto):
    return pedido('postagem.php', dict(token=token, texto=texto), 201)['id']

try:
    a, ta = criar('Teste Ana')
    b, tb = criar('Teste Bruno')
    c, tc = criar('Teste Carla')
    pa = publicar(ta, 'Postagem da Ana')
    pb = publicar(tb, 'Postagem do Bruno')
    pc = publicar(tc, 'Postagem da Carla')
    social('', 'feed', 401)
    feed = social(ta, 'feed')['postagens']
    assert {pa, pb, pc}.issubset({p['id'] for p in feed})
    assert next(p for p in feed if p['id'] == pb)['autor_id'] == b
    for _ in range(2):
        assert social(ta, 'curtir', publicacao_id=pb, curtir='1')['curtidas'] == 1
    assert social(tc, 'curtir', publicacao_id=pb, curtir='1')['curtidas'] == 2
    assert social(ta, 'curtir', publicacao_id=pb, curtir='0')['curtidas'] == 1
    social(ta, 'comentar', 403, publicacao_id=pb, texto='Antes da amizade')
    social(ta, 'solicitar', 400, usuario_id=a)
    for _ in range(2):
        assert social(ta, 'solicitar', usuario_id=b)['amizade'] == 'enviado'
    assert social(tb, 'solicitar', usuario_id=a)['amizade'] == 'recebido'
    assert len(social(tb, 'amizades')['amizades']) == 1
    social(ta, 'responder', 403, usuario_id=b, aceitar='1')
    social(tc, 'responder', 403, usuario_id=a, aceitar='1')
    social(ta, 'comentar', 403, publicacao_id=pb, texto='Ainda pendente')
    assert social(tb, 'responder', usuario_id=a, aceitar='1')['amizade'] == 'amigo'
    for token in [ta, tb]:
        assert social(token, 'amizades')['amizades'][0]['status'] == 'amigo'
    social(ta, 'comentar', 201, publicacao_id=pb, texto='Agora somos amigos!')
    social(tb, 'comentar', 201, publicacao_id=pa, texto='Amizade nos dois sentidos')
    social(tc, 'comentar', 403, publicacao_id=pb, texto='Sou outra pessoa')
    social(ta, 'comentar', 403, publicacao_id=pa, texto='Minha propria postagem')
    social(ta, 'comentar', 400, publicacao_id=pb, texto=' ')
    social(ta, 'comentar', 400, publicacao_id=pb, texto='x'*281)
    comentarios = social(tc, 'comentarios', publicacao_id=pb)
    assert comentarios['comentarios'][0]['nome'] == 'Teste Ana'
    assert comentarios['pode_comentar'] is False
    social(tc, 'solicitar', usuario_id=b)
    assert social(tb, 'responder', usuario_id=c, aceitar='0')['amizade'] == 'nenhuma'
    assert social(tc, 'amizades')['amizades'] == []
    social(tc, 'comentar', 403, publicacao_id=pb, texto='Depois da recusa')
    social(ta, 'curtir', 404, publicacao_id=4294967295, curtir='1')
    # Pagina o feed sem perder nem repetir registros.
    for n in range(21):
        publicar(ta, f'Paginacao {n}')
    pagina1 = social(ta, 'feed')
    assert len(pagina1['postagens']) == 20 and pagina1['mais'] is True
    pagina2 = social(ta, 'feed', antes=pagina1['postagens'][-1]['id'])
    assert not ({p['id'] for p in pagina1['postagens']} & {p['id'] for p in pagina2['postagens']})
    # Pagina comentarios, mantendo a restricao de amizade no servidor.
    for n in range(30):
        social(ta, 'comentar', 201, publicacao_id=pb, texto=f'Comentario {n}')
    pagina1 = social(ta, 'comentarios', publicacao_id=pb)
    assert len(pagina1['comentarios']) == 30 and pagina1['mais'] is True
    pagina2 = social(ta, 'comentarios', publicacao_id=pb, apos=pagina1['comentarios'][-1]['id'])
    assert len(pagina2['comentarios']) == 1 and pagina2['mais'] is False
    print('API real aprovada: feed, curtidas unicas, amizades, aprovacao/recusa, comentarios restritos e paginacao.')
finally:
    if usuarios:
        ids = ','.join(str(int(i)) for i in usuarios)
        # FKs removem curtidas, comentarios, amizades e sessoes apenas das contas de teste.
        subprocess.run([MYSQL, '-u', 'root', 'mini_x', '-e', f'DELETE FROM publicacoes WHERE usuario_id IN ({ids}); DELETE FROM usuarios WHERE id IN ({ids});'], check=True)
