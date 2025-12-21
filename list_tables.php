<?php
require_once 'backend/config/database.php';
$db = (new Database())->getConnection();
$stmt = $db->query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name");
echo "=== TABLAS EN LA BASE DE DATOS ===\n";
while($row = $stmt->fetch(PDO::FETCH_ASSOC)) { 
    echo "  - " . $row['table_name'] . "\n"; 
}
