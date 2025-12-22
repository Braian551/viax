<?php
require_once __DIR__ . '/backend/config/database.php';

$db = (new Database())->getConnection();

echo "Buscando tabla de asignaciones...\n\n";

// Ver todas las tablas
$stmt = $db->query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE '%asign%' OR table_name LIKE '%conductor%'");
echo "Tablas relacionadas:\n";
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "- " . $row['table_name'] . "\n";
}

echo "\n\nColumnas de asignaciones_conductor:\n";
$stmt = $db->query("SELECT column_name FROM information_schema.columns WHERE table_name = 'asignaciones_conductor' ORDER BY ordinal_position");
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "- " . $row['column_name'] . "\n";
}
