<?php
require __DIR__ . '/conexao.php';
header('Content-Type: application/json; charset=utf-8');
function falha(int $codigo, string $mensagem): void {
    http_response_code($codigo);
    echo json_encode(['erro' => $mensagem], JSON_UNESCAPED_UNICODE);
    exit;
}
if ($_SERVER['REQUEST_METHOD'] !== 'POST') falha(405, 'Use POST para enviar uma foto.');
$descricao = trim($_POST['descricao'] ?? '');
if ($descricao === '' || preg_match('//u', $descricao) !== 1 || preg_match_all('/./us', $descricao) > 280) {
    falha(400, 'Informe uma descrição de 1 a 280 caracteres.');
}
$foto = $_FILES['foto'] ?? null;
if (!$foto || $foto['error'] !== UPLOAD_ERR_OK) falha(400, 'Selecione uma foto. Confira também o limite de upload do PHP.');
if ($foto['size'] > 8 * 1024 * 1024) falha(413, 'A foto deve ter no máximo 8 MB.');
$mime = (new finfo(FILEINFO_MIME_TYPE))->file($foto['tmp_name']);
$tipos = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
if (!isset($tipos[$mime]) || @getimagesize($foto['tmp_name']) === false) falha(415, 'Envie uma imagem JPEG, PNG ou WebP válida.');
$pasta = __DIR__ . '/uploads';
if (!is_dir($pasta) && !mkdir($pasta, 0755, true)) falha(500, 'Não foi possível criar a pasta de fotos.');
$nome = bin2hex(random_bytes(16)) . '.' . $tipos[$mime];
$destino = $pasta . '/' . $nome;
if (!move_uploaded_file($foto['tmp_name'], $destino)) falha(500, 'Não foi possível salvar a foto.');
try {
    $pdo = banco();
    $consulta = $pdo->prepare('INSERT INTO fotos (arquivo, descricao) VALUES (:arquivo, :descricao)');
    $consulta->execute(['arquivo' => $nome, 'descricao' => $descricao]);
    http_response_code(201);
    echo json_encode(['id' => (int) $pdo->lastInsertId(), 'url' => 'uploads/' . $nome, 'descricao' => $descricao], JSON_UNESCAPED_UNICODE);
} catch (PDOException $e) {
    unlink($destino);
    error_log($e->getMessage());
    falha(500, 'Não foi possível registrar a foto no banco.');
}
