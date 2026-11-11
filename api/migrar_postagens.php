<?php
// Execute apenas pelo terminal: php api/migrar_postagens.php
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require __DIR__ . '/conexao.php';
$db = banco();
$db->exec(file_get_contents(__DIR__ . '/sessoes.sql'));
foreach (['usuario_id' => 'INT UNSIGNED NULL', 'foto' => 'VARCHAR(100) NULL'] as $coluna => $tipo) {
    $consulta = $db->prepare('SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?');
    $consulta->execute(['publicacoes', $coluna]);
    if (!$consulta->fetchColumn()) $db->exec("ALTER TABLE publicacoes ADD COLUMN $coluna $tipo");
}
$db->exec(file_get_contents(__DIR__ . '/interacoes.sql'));
echo "Migração de postagens concluída.\n";
