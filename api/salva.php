<?php
require __DIR__ . '/conexao.php';
header('Content-Type: text/plain; charset=utf-8');
$texto = trim($_POST['txt'] ?? $_GET['txt'] ?? '');
if ($texto === '' || preg_match('//u', $texto) !== 1 || preg_match_all('/./us', $texto) > 280) {
    http_response_code(400);
    exit('Informe um texto de 1 a 280 caracteres.');
}
try {
    $consulta = banco()->prepare('INSERT INTO publicacoes (texto) VALUES (:texto)');
    $consulta->execute(['texto' => $texto]);
    echo 'Texto salvo!';
} catch (PDOException $e) {
    error_log($e->getMessage());
    http_response_code(500);
    echo 'Erro ao salvar o texto.';
}
