<?php
require_once __DIR__ . '/backend/config/database.php';

$db = (new Database())->getConnection();

echo "Columnas de disputas_pago:\n";
$stmt = $db->query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'disputas_pago' ORDER BY ordinal_position");
while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "- {$row['column_name']} ({$row['data_type']})\n";
}
