<?php
require_once 'backend/config/database.php';

$db = (new Database())->getConnection();

function checkColumns($table, $db) {
    $stmt = $db->prepare("SELECT column_name FROM information_schema.columns WHERE table_name = ? ORDER BY ordinal_position");
    $stmt->execute([$table]);
    echo "Columnas de $table:\n";
    $cols = $stmt->fetchAll(PDO::FETCH_COLUMN);
    print_r($cols);
    echo "\n";
}

checkColumns('viaje_resumen_tracking', $db);
checkColumns('asignaciones_conductor', $db);
checkColumns('detalles_conductor', $db);
?>
