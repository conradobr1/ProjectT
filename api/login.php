<?php
require __DIR__ . '/autenticacao.php';
try {
    $consulta = banco()->prepare('SELECT id, nome, email, senha_hash FROM usuarios WHERE email = ? LIMIT 1');
    $consulta->execute([$email]);
    $usuario = $consulta->fetch();
    if (!$usuario || !password_verify($senha, $usuario['senha_hash'])) {
        responder(401, ['erro' => 'E-mail ou senha incorretos.']);
    }
    responder(200, ['usuario' => perfil($usuario)]);
} catch (PDOException $e) {
    error_log($e->getMessage());
    responder(500, ['erro' => 'Não foi possível entrar. Confira o servidor.']);
}
