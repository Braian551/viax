<?php
require_once 'backend/config/database.php';

$db = (new Database())->getConnection();

$stmt = $db->query("SELECT column_name, is_nullable, data_type, column_default FROM information_schema.columns WHERE table_name = 'detalles_conductor' ORDER BY ordinal_position");
echo "=== ESTRUCTURA DETALLES_CONDUCTOR ===\n";
while($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    $nullable = $row['is_nullable'] == 'YES' ? 'NULL' : 'NOT NULL';
    $default = $row['column_default'] ? " DEFAULT {$row['column_default']}" : '';
    echo "{$row['column_name']} - {$row['data_type']} - {$nullable}{$default}\n";
}
