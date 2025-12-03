<?php
require_once 'backend/config/database.php';

$db = (new Database())->getConnection();

// Verificar estado de solicitud 584
$stmt = $db->prepare('SELECT id, estado FROM solicitudes_servicio WHERE id = ?');
$stmt->execute([584]);
$solicitud = $stmt->fetch(PDO::FETCH_ASSOC);

echo "=== Estado de solicitud 584 ===\n";
print_r($solicitud);

// Verificar asignación
$stmt = $db->prepare('SELECT * FROM asignaciones_conductor WHERE solicitud_id = ?');
$stmt->execute([584]);
$asignacion = $stmt->fetch(PDO::FETCH_ASSOC);

echo "\n=== Asignación ===\n";
print_r($asignacion);

// Probar el endpoint directamente (simular la llamada)
echo "\n=== Probando get_trip_status.php ===\n";

// Simular $_GET
$_GET['solicitud_id'] = 584;
$_SERVER['REQUEST_METHOD'] = 'GET';

// Capturar output
ob_start();
include 'backend/user/get_trip_status.php';
$output = ob_get_clean();

echo $output;
