<?php
require __DIR__ . '/conexao.php';
require __DIR__ . '/sessao.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
function erroPostagem(int $codigo, string $mensagem): void {
    http_response_code($codigo);
    echo json_encode(['erro' => $mensagem], JSON_UNESCAPED_UNICODE);
    exit;
}
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Allow: POST');
    erroPostagem(405, 'Use POST para publicar.');
}
$destino = null;
try {
    $db = banco();
    $usuario = usuarioDaSessao($db, is_string($_POST['token'] ?? null) ? $_POST['token'] : '');
    if ($usuario === null) erroPostagem(401, 'Sessão inválida ou expirada. Saia e entre novamente.');
    $texto = is_string($_POST['texto'] ?? null) ? trim($_POST['texto']) : '';
    if ($texto === '' || preg_match('//u', $texto) !== 1 || preg_match_all('/./us', $texto) > 280) {
        erroPostagem(400, 'Informe um texto de 1 a 280 caracteres.');
    }
    $nomeFoto = null;
    $foto = $_FILES['foto'] ?? null;
    if ($foto && $foto['error'] !== UPLOAD_ERR_NO_FILE) {
        if (!is_int($foto['error']) || $foto['error'] !== UPLOAD_ERR_OK) erroPostagem(400, 'Falha no envio da foto. Confira o limite de upload.');
        if ($foto['size'] > 8 * 1024 * 1024) erroPostagem(413, 'A foto deve ter no máximo 8 MB.');
        $mime = (new finfo(FILEINFO_MIME_TYPE))->file($foto['tmp_name']);
        $tipos = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
        if (!isset($tipos[$mime]) || @getimagesize($foto['tmp_name']) === false) erroPostagem(415, 'Envie uma imagem JPEG, PNG ou WebP válida.');
        $pasta = __DIR__ . '/uploads';
        if (!is_dir($pasta) && !mkdir($pasta, 0755, true)) throw new RuntimeException('Pasta indisponível');
        $nomeFoto = bin2hex(random_bytes(16)) . '.' . $tipos[$mime];
        $destino = $pasta . '/' . $nomeFoto;
        if (!move_uploaded_file($foto['tmp_name'], $destino)) throw new RuntimeException('Upload indisponível');
    }
    $consulta = $db->prepare('INSERT INTO publicacoes (usuario_id, texto, foto) VALUES (?, ?, ?)');
    $consulta->execute([$usuario, $texto, $nomeFoto]);
    http_response_code(201);
    echo json_encode(['id' => (int) $db->lastInsertId(), 'foto_url' => $nomeFoto ? 'uploads/' . $nomeFoto : null], JSON_UNESCAPED_UNICODE);
} catch (Throwable $e) {
    if ($destino && is_file($destino)) unlink($destino);
    error_log($e->getMessage());
    erroPostagem(500, 'Não foi possível salvar a publicação.');
}
