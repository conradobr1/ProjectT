<?php
// Configure conforme seu MySQL (exemplo de instalação local XAMPP).
function banco(): PDO {
    return new PDO('mysql:host=localhost;dbname=mini_x;charset=utf8mb4', 'root', '', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
}
