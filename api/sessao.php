<?php
function criarSessao(PDO $db, int $usuario): string {
    $token = bin2hex(random_bytes(32));
    $consulta = $db->prepare('INSERT INTO sessoes (token_hash, usuario_id, expira_em) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 30 DAY))');
    $consulta->execute([hash('sha256', $token), $usuario]);
    return $token;
}
function usuarioDaSessao(PDO $db, string $token): ?int {
    if (!preg_match('/^[a-f0-9]{64}$/D', $token)) return null;
    $consulta = $db->prepare('SELECT s.usuario_id FROM sessoes s JOIN usuarios u ON u.id = s.usuario_id WHERE s.token_hash = ? AND s.expira_em > NOW()');
    $consulta->execute([hash('sha256', $token)]);
    $id = $consulta->fetchColumn();
    return $id === false ? null : (int) $id;
}
