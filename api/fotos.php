<?php
require __DIR__ . '/conexao.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
try {
    $itens = banco()->query('SELECT id, arquivo, descricao, criado_em FROM fotos ORDER BY id ASC')->fetchAll();
    foreach ($itens as &$item) {
        $item['id'] = (int) $item['id'];
        $item['url'] = 'uploads/' . $item['arquivo'];
        unset($item['arquivo']);
    }
    unset($item);
    echo json_encode($itens, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
} catch (PDOException $e) {
    error_log($e->getMessage());
    http_response_code(500);
    echo json_encode(['erro' => 'Não foi possível listar as fotos.']);
}
