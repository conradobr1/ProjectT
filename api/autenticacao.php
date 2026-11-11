<?php
require __DIR__ . '/conexao.php';
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
function responder(int $status, array $dados): void {
    http_response_code($status);
    echo json_encode($dados, JSON_UNESCAPED_UNICODE);
    exit;
}
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Allow: POST');
    responder(405, ['erro' => 'Use POST.']);
}
function campo(string $nome): string {
    if (!isset($_POST[$nome]) || !is_string($_POST[$nome])) {
        responder(400, ['erro' => 'Preencha todos os campos.']);
    }
    return $_POST[$nome];
}
$email = strtolower(trim(campo('email')));
$senha = campo('senha');
if (strlen($email) > 254 || !filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($senha) < 1 || strlen($senha) > 72) {
    responder(400, ['erro' => 'Informe e-mail e senha válidos.']);
}
function perfil(array $usuario): array {
    return ['id' => (int) $usuario['id'], 'nome' => $usuario['nome'], 'email' => $usuario['email']];
}
