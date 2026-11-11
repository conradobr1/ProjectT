CREATE TABLE IF NOT EXISTS sessoes (
    token_hash CHAR(64) PRIMARY KEY,
    usuario_id INT UNSIGNED NOT NULL,
    expira_em DATETIME NOT NULL,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
);
