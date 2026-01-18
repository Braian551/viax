<?php
require_once 'backend/config/database.php';

$db = (new Database())->getConnection();
$stmt = $db->query("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'solicitudes_servicio' AND column_name LIKE '%precio%'");
$columns = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Columnas de precio en solicitudes_servicio:\n";
print_r($columns);

// Verificar si existe precio_en_tracking
$has_precio_en_tracking = false;
foreach ($columns as $col) {
    if ($col['column_name'] === 'precio_en_tracking') {
        $has_precio_en_tracking = true;
        break;
    }
}

if (!$has_precio_en_tracking) {
    echo "\n❌ La columna precio_en_tracking NO existe. Creándola...\n";
    try {
        $db->exec("ALTER TABLE solicitudes_servicio ADD COLUMN precio_en_tracking DECIMAL(10,2) DEFAULT NULL");
        echo "✅ Columna precio_en_tracking creada correctamente\n";
    } catch (Exception $e) {
        echo "Error: " . $e->getMessage() . "\n";
    }
} else {
    echo "\n✅ La columna precio_en_tracking ya existe\n";
}
