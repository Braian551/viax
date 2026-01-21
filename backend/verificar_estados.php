<?php
require_once 'config/database.php';

try {
    $database = new Database();
    $db = $database->getConnection();
    
    echo "<pre>\n";
    echo "=== Verificación de Estados en Solicitudes y Viajes ===\n\n";
    
    // Ver estados en solicitudes_servicio
    $stmt = $db->query("
        SELECT estado, COUNT(*) as cantidad
        FROM solicitudes_servicio
        GROUP BY estado
        ORDER BY cantidad DESC
    ");
    echo "Estados en solicitudes_servicio:\n";
    foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $row) {
        echo "  - {$row['estado']}: {$row['cantidad']}\n";
    }
    
    // Ver viajes en viaje_resumen_tracking
    $stmt2 = $db->query("
        SELECT COUNT(*) as total,
               SUM(CASE WHEN comision_admin_valor > 0 THEN 1 ELSE 0 END) as con_comision
        FROM viaje_resumen_tracking
    ");
    $data = $stmt2->fetch(PDO::FETCH_ASSOC);
    echo "\nViajes en viaje_resumen_tracking:\n";
    echo "  Total: {$data['total']}\n";
    echo "  Con comision_admin_valor > 0: {$data['con_comision']}\n";
    
    // Ver muestra de viajes con comision
    echo "\nMuestra de viajes con comision_admin_valor:\n";
    $stmt3 = $db->query("
        SELECT vrt.id, vrt.solicitud_id, vrt.comision_admin_valor, vrt.empresa_id,
               ss.estado as solicitud_estado
        FROM viaje_resumen_tracking vrt
        LEFT JOIN solicitudes_servicio ss ON ss.id = vrt.solicitud_id
        WHERE vrt.comision_admin_valor > 0
        LIMIT 5
    ");
    foreach ($stmt3->fetchAll(PDO::FETCH_ASSOC) as $row) {
        echo "  - Viaje ID {$row['id']}, Solicitud {$row['solicitud_id']}, ";
        echo "Comision: {$row['comision_admin_valor']}, ";
        echo "Estado solicitud: {$row['solicitud_estado']}, ";
        echo "Empresa: {$row['empresa_id']}\n";
    }
    
    echo "\n</pre>";
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage();
}
?>
