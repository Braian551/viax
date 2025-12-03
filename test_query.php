<?php
require_once 'backend/config/database.php';

$db = (new Database())->getConnection();

echo "=== Columnas de asignaciones_conductor ===\n";
$stmt = $db->query("SELECT column_name FROM information_schema.columns WHERE table_name = 'asignaciones_conductor'");
while ($row = $stmt->fetch()) {
    echo "- " . $row['column_name'] . "\n";
}

echo "\n=== Probando query del endpoint ===\n";

// Intentar el query completo
try {
    $stmt = $db->prepare("
        SELECT 
            s.*,
            ac.conductor_id,
            ac.estado as estado_asignacion,
            ac.asignado_en as fecha_asignacion,
            u.nombre as conductor_nombre,
            u.apellido as conductor_apellido,
            u.telefono as conductor_telefono,
            u.foto_perfil as conductor_foto,
            dc.vehiculo_tipo,
            dc.vehiculo_marca,
            dc.vehiculo_modelo,
            dc.vehiculo_placa,
            dc.vehiculo_color,
            dc.calificacion_promedio as conductor_calificacion,
            dc.latitud_actual as conductor_latitud,
            dc.longitud_actual as conductor_longitud,
            (6371 * acos(
                cos(radians(s.latitud_recogida)) * cos(radians(dc.latitud_actual)) *
                cos(radians(dc.longitud_actual) - radians(s.longitud_recogida)) +
                sin(radians(s.latitud_recogida)) * sin(radians(dc.latitud_actual))
            )) AS distancia_conductor_km
        FROM solicitudes_servicio s
        LEFT JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id AND ac.estado = 'asignado'
        LEFT JOIN usuarios u ON ac.conductor_id = u.id
        LEFT JOIN detalles_conductor dc ON u.id = dc.usuario_id
        WHERE s.id = ?
    ");
    $stmt->execute([584]);
    $trip = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "Estado: " . $trip['estado'] . "\n";
    echo "Conductor ID: " . $trip['conductor_id'] . "\n";
    echo "Conductor nombre: " . $trip['conductor_nombre'] . "\n";
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
}
