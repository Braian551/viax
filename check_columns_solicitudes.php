<?php
require_once __DIR__ . '/backend/config/database.php';

$db = (new Database())->getConnection();
$stmt = $db->query("SELECT column_name FROM information_schema.columns WHERE table_name = 'solicitudes_servicio' ORDER BY ordinal_position");

echo "Columnas de solicitudes_servicio:\n";
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "- " . $row['column_name'] . "\n";
}
