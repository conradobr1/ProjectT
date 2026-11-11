<?php
require __DIR__ . '/conexao.php';
require __DIR__ . '/sessao.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
function respostaSocial(int $status, array $dados): void {
    http_response_code($status);
    echo json_encode($dados, JSON_UNESCAPED_UNICODE);
    exit;
}
function inteiroSocial(string $campo, int $minimo = 1): int {
    $valor = filter_var($_POST[$campo] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => $minimo]]);
    if ($valor === false || $valor === null) respostaSocial(400, ['erro' => 'Identificação inválida.']);
    return $valor;
}
function vinculoSocial(PDO $db, int $usuario, ?int $autor): string {
    if (!$autor) return 'indisponivel';
    if ($usuario === $autor) return 'proprio';
    $q = $db->prepare('SELECT status, solicitante_id FROM amizades WHERE usuario_a = ? AND usuario_b = ?');
    $q->execute([min($usuario, $autor), max($usuario, $autor)]);
    $v = $q->fetch();
    if (!$v) return 'nenhuma';
    if ($v['status'] === 'aprovada') return 'amigo';
    return (int) $v['solicitante_id'] === $usuario ? 'enviado' : 'recebido';
}
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Allow: POST');
    respostaSocial(405, ['erro' => 'Use POST.']);
}
try {
    $db = banco();
    $usuario = usuarioDaSessao($db, is_string($_POST['token'] ?? null) ? $_POST['token'] : '');
    if ($usuario === null) respostaSocial(401, ['erro' => 'Sessão inválida ou expirada. Saia e entre novamente.']);
    $acao = $_POST['acao'] ?? '';
    if ($acao === 'feed') {
        $antes = isset($_POST['antes']) ? inteiroSocial('antes', 0) : 0;
        $q = $db->prepare("SELECT p.id, p.usuario_id AS autor_id, p.texto, p.criado_em, u.nome,
            CASE WHEN p.foto IS NULL THEN NULL ELSE CONCAT('uploads/', p.foto) END AS foto_url,
            (SELECT COUNT(*) FROM curtidas c WHERE c.publicacao_id = p.id) AS curtidas,
            EXISTS(SELECT 1 FROM curtidas c WHERE c.publicacao_id = p.id AND c.usuario_id = ?) AS curtiu,
            (SELECT COUNT(*) FROM comentarios c WHERE c.publicacao_id = p.id) AS comentarios
            FROM publicacoes p LEFT JOIN usuarios u ON u.id = p.usuario_id
            WHERE (? = 0 OR p.id < ?) ORDER BY p.id DESC LIMIT 21");
        $q->execute([$usuario, $antes, $antes]);
        $itens = $q->fetchAll();
        $mais = count($itens) > 20;
        $itens = array_slice($itens, 0, 20);
        foreach ($itens as &$p) {
            $p['id'] = (int) $p['id'];
            $p['autor_id'] = $p['autor_id'] === null ? null : (int) $p['autor_id'];
            $p['curtiu'] = (bool) $p['curtiu'];
            $p['curtidas'] = (int) $p['curtidas'];
            $p['comentarios'] = (int) $p['comentarios'];
            $p['amizade'] = vinculoSocial($db, $usuario, $p['autor_id']);
            $p['pode_comentar'] = $p['amizade'] === 'amigo';
        }
        unset($p);
        respostaSocial(200, ['postagens' => $itens, 'mais' => $mais]);
    }
    if ($acao === 'amizades') {
        $q = $db->prepare('SELECT a.status, a.solicitante_id, u.id, u.nome FROM amizades a JOIN usuarios u ON u.id = CASE WHEN a.usuario_a = ? THEN a.usuario_b ELSE a.usuario_a END WHERE a.usuario_a = ? OR a.usuario_b = ? ORDER BY a.criado_em DESC, u.id DESC');
        $q->execute([$usuario, $usuario, $usuario]);
        $lista = [];
        foreach ($q->fetchAll() as $a) {
            $lista[] = ['id' => (int) $a['id'], 'nome' => $a['nome'], 'status' => $a['status'] === 'aprovada' ? 'amigo' : ((int) $a['solicitante_id'] === $usuario ? 'enviado' : 'recebido')];
        }
        respostaSocial(200, ['amizades' => $lista]);
    }
    if ($acao === 'solicitar' || $acao === 'responder') {
        $outro = inteiroSocial('usuario_id');
        if ($outro === $usuario) respostaSocial(400, ['erro' => 'Escolha outro usuário.']);
        $q = $db->prepare('SELECT id FROM usuarios WHERE id = ?');
        $q->execute([$outro]);
        if (!$q->fetchColumn()) respostaSocial(404, ['erro' => 'Usuário não encontrado.']);
        $a = min($usuario, $outro); $b = max($usuario, $outro);
        if ($acao === 'solicitar') {
            // A chave do par impede solicitações duplicadas, inclusive em sentidos opostos.
            $q = $db->prepare('INSERT IGNORE INTO amizades (usuario_a, usuario_b, solicitante_id) VALUES (?, ?, ?)');
            $q->execute([$a, $b, $usuario]);
            respostaSocial(200, ['amizade' => vinculoSocial($db, $usuario, $outro)]);
        }
        $aceitar = $_POST['aceitar'] ?? '';
        if (!in_array($aceitar, ['0', '1'], true)) respostaSocial(400, ['erro' => 'Resposta inválida.']);
        $sql = $aceitar === '1'
            ? "UPDATE amizades SET status = 'aprovada' WHERE usuario_a = ? AND usuario_b = ? AND solicitante_id = ? AND status = 'pendente'"
            : "DELETE FROM amizades WHERE usuario_a = ? AND usuario_b = ? AND solicitante_id = ? AND status = 'pendente'";
        $q = $db->prepare($sql);
        $q->execute([$a, $b, $outro]);
        if ($q->rowCount() !== 1) respostaSocial(403, ['erro' => 'Somente quem recebeu uma solicitação pendente pode respondê-la.']);
        respostaSocial(200, ['amizade' => vinculoSocial($db, $usuario, $outro)]);
    }
    if (in_array($acao, ['curtir', 'comentarios', 'comentar'], true)) {
        $id = inteiroSocial('publicacao_id');
        $q = $db->prepare('SELECT usuario_id FROM publicacoes WHERE id = ?');
        $q->execute([$id]);
        $post = $q->fetch();
        if (!$post) respostaSocial(404, ['erro' => 'Publicação não encontrada.']);
        $autor = $post['usuario_id'] === null ? null : (int) $post['usuario_id'];
        if ($acao === 'curtir') {
            $curtir = $_POST['curtir'] ?? '';
            if (!in_array($curtir, ['0', '1'], true)) respostaSocial(400, ['erro' => 'Curtida inválida.']);
            $q = $db->prepare($curtir === '1' ? 'INSERT IGNORE INTO curtidas (publicacao_id, usuario_id) VALUES (?, ?)' : 'DELETE FROM curtidas WHERE publicacao_id = ? AND usuario_id = ?');
            $q->execute([$id, $usuario]);
            $q = $db->prepare('SELECT COUNT(*) FROM curtidas WHERE publicacao_id = ?');
            $q->execute([$id]);
            respostaSocial(200, ['curtidas' => (int) $q->fetchColumn(), 'curtiu' => $curtir === '1']);
        }
        $pode = vinculoSocial($db, $usuario, $autor) === 'amigo';
        if ($acao === 'comentar') {
            if (!$pode) respostaSocial(403, ['erro' => 'Você só pode comentar em postagens de amigos com amizade aprovada.']);
            $texto = is_string($_POST['texto'] ?? null) ? trim($_POST['texto']) : '';
            if ($texto === '' || preg_match('//u', $texto) !== 1 || preg_match_all('/./us', $texto) > 280) respostaSocial(400, ['erro' => 'Escreva um comentário de 1 a 280 caracteres.']);
            $q = $db->prepare('INSERT INTO comentarios (publicacao_id, usuario_id, texto) VALUES (?, ?, ?)');
            $q->execute([$id, $usuario, $texto]);
            respostaSocial(201, ['id' => (int) $db->lastInsertId()]);
        }
        $apos = isset($_POST['apos']) ? inteiroSocial('apos', 0) : 0;
        $q = $db->prepare('SELECT c.id, c.texto, c.criado_em, u.nome FROM comentarios c JOIN usuarios u ON u.id = c.usuario_id WHERE c.publicacao_id = ? AND c.id > ? ORDER BY c.id ASC LIMIT 31');
        $q->execute([$id, $apos]);
        $comentarios = $q->fetchAll();
        foreach ($comentarios as &$c) $c['id'] = (int) $c['id'];
        unset($c);
        respostaSocial(200, ['comentarios' => array_slice($comentarios, 0, 30), 'mais' => count($comentarios) > 30, 'pode_comentar' => $pode]);
    }
    respostaSocial(400, ['erro' => 'Ação inválida.']);
} catch (Throwable $e) {
    error_log($e->getMessage());
    respostaSocial(500, ['erro' => 'Não foi possível concluir. Tente novamente.']);
}
