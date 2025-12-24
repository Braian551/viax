<?php
require_once __DIR__ . '/backend/config/database.php';

$db = (new Database())->getConnection();

echo "=== COLUMNAS DE asignaciones_conductor ===\n";
$stmt = $db->query("SELECT column_name FROM information_schema.columns WHERE table_name = 'asignaciones_conductor'");
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "- " . $row['column_name'] . "\n";
}

echo "\n=== COLUMNAS DE detalles_conductor ===\n";
$stmt = $db->query("SELECT column_name FROM information_schema.columns WHERE table_name = 'detalles_conductor'");
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "- " . $row['column_name'] . "\n";
}
