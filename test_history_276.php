<?php
require_once 'backend/config/database.php';

$database = new Database();
$conn = $database->getConnection();

$usuario_id = 276;

echo "--- Debugging User $usuario_id Strings ---\n";

// 1. Check Raw Count
$stmt = $conn->prepare("SELECT COUNT(*) as total FROM solicitudes_servicio WHERE cliente_id = ?");
$stmt->execute([$usuario_id]);
$total = $stmt->fetchColumn();
echo "Total solicitudes for client $usuario_id: $total\n";

if ($total > 0) {
    // 2. Dump first 3 rows basic info
    $stmt = $conn->prepare("SELECT id, estado, cliente_id, conductor_id FROM solicitudes_servicio WHERE cliente_id = ? LIMIT 3");
    $stmt->execute([$usuario_id]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "Sample Rows:\n";
    print_r($rows);
}

// 3. Test the actual Endpoint Logic (Simulated)
echo "\n--- Simulating endpoint logic ---\n";
// Copying parts of get_trip_history.php logic
$whereClause = "WHERE ss.cliente_id = :usuario_id";

// Check if tables exist
try {
    $conn->query("SELECT 1 FROM viaje_resumen_tracking LIMIT 1");
    echo "Table 'viaje_resumen_tracking' exists.\n";
} catch (Exception $e) {
    echo "Table 'viaje_resumen_tracking' ERROR: " . $e->getMessage() . "\n";
}

$query = "
    SELECT 
        ss.id,
        ss.estado,
        ss.cliente_id,
        dc.vehiculo_placa,
        dc.vehiculo_marca
    FROM solicitudes_servicio ss
    LEFT JOIN viaje_resumen_tracking vrt ON ss.id = vrt.solicitud_id
    LEFT JOIN asignaciones_conductor ac ON ss.id = ac.solicitud_id AND ac.estado IN ('aceptada', 'completada', 'completado')
    LEFT JOIN detalles_conductor dc ON ac.conductor_id = dc.usuario_id
    WHERE ss.cliente_id = :usuario_id
    LIMIT 5
";

try {
    $stmt = $conn->prepare($query);
    $stmt->execute([':usuario_id' => $usuario_id]);
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo "Query Results via JOINs:\n";
    print_r($results);
} catch (Exception $e) {
    echo "Query Error: " . $e->getMessage() . "\n";
}
?>
