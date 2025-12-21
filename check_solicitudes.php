<?php
require_once 'backend/config/database.php';

$db = (new Database())->getConnection();

// Estructura de calificaciones
$stmt = $db->query("SELECT column_name, is_nullable, data_type FROM information_schema.columns WHERE table_name = 'calificaciones' ORDER BY ordinal_position");
echo "=== ESTRUCTURA CALIFICACIONES ===\n";
while($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    $nullable = $row['is_nullable'] == 'YES' ? 'NULL' : 'NOT NULL';
    echo "{$row['column_name']} - {$row['data_type']} - {$nullable}\n";
}
