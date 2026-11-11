<?php
require __DIR__ . '/autenticacao.php';
$nome = trim(campo('nome'));
if ($nome === '' || preg_match('//u', $nome) !== 1 || preg_match_all('/./us', $nome) > 100 || strlen($senha) < 8) {
    responder(400, ['erro' => 'Informe nome de até 100 caracteres e senha de 8 a 72 bytes.']);
}
try {
    $db = banco();
    $consulta = $db->prepare('INSERT INTO usuarios (nome, email, senha_hash) VALUES (?, ?, ?)');
    $consulta->execute([$nome, $email, password_hash($senha, PASSWORD_DEFAULT)]);
    responder(201, ['usuario' => ['id' => (int) $db->lastInsertId(), 'nome' => $nome, 'email' => $email]]);
} catch (PDOException $e) {
    if ($e->getCode() === '23000') responder(409, ['erro' => 'Este e-mail já está cadastrado.']);
    error_log($e->getMessage());
    responder(500, ['erro' => 'Não foi possível cadastrar. Confira o servidor.']);
}
