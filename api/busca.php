<?php
require __DIR__ . '/conexao.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
$id = filter_var($_GET['id'] ?? '0', FILTER_VALIDATE_INT, ['options' => ['min_range' => 0]]);
if ($id === false) {
    http_response_code(400);
    exit(json_encode(['erro' => 'ID inválido.'], JSON_UNESCAPED_UNICODE));
}
try {
    $consulta = banco()->prepare("SELECT p.id, p.texto, u.nome, CASE WHEN p.foto IS NULL THEN NULL ELSE CONCAT('uploads/', p.foto) END AS foto_url FROM publicacoes p LEFT JOIN usuarios u ON u.id = p.usuario_id WHERE p.id > :id ORDER BY p.id ASC LIMIT 1");
    $consulta->bindValue(':id', $id, PDO::PARAM_INT);
    $consulta->execute();
    $item = $consulta->fetch();
    if ($item) $item['id'] = (int) $item['id'];
    echo json_encode($item ?: null, JSON_UNESCAPED_UNICODE);
} catch (PDOException $e) {
    error_log($e->getMessage());
    http_response_code(500);
    echo json_encode(['erro' => 'Erro ao consultar os textos.']);
}
