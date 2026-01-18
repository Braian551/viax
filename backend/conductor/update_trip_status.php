<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once '../config/database.php';

try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $solicitud_id = $input['solicitud_id'] ?? null;
    $conductor_id = $input['conductor_id'] ?? null;
    $nuevo_estado = $input['nuevo_estado'] ?? null;
    
    if (!$solicitud_id || !$conductor_id || !$nuevo_estado) {
        throw new Exception('solicitud_id, conductor_id y nuevo_estado son requeridos');
    }
    
    // Validar estados permitidos
    $estados_validos = ['conductor_llego', 'recogido', 'en_curso', 'completada', 'cancelada'];
    if (!in_array($nuevo_estado, $estados_validos)) {
        throw new Exception('Estado no válido');
    }

    // Preparar campos opcionales
    $distancia_recorrida = isset($input['distancia_recorrida']) ? floatval($input['distancia_recorrida']) : null;
    $tiempo_transcurrido = isset($input['tiempo_transcurrido']) ? intval($input['tiempo_transcurrido']) : null;
    $motivo_cancelacion = isset($input['motivo_cancelacion']) ? $input['motivo_cancelacion'] : null;
    $precio_final = isset($input['precio_final']) ? floatval($input['precio_final']) : null;

    $database = new Database();
    $db = $database->getConnection();
    
    // Verificar que el conductor está asignado a esta solicitud
    $stmt = $db->prepare("
        SELECT s.*, ac.conductor_id 
        FROM solicitudes_servicio s
        LEFT JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id AND ac.estado IN ('asignado', 'llegado', 'en_curso', 'completado')
        WHERE s.id = ?
    ");
    $stmt->execute([$solicitud_id]);
    $solicitud = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$solicitud) {
        throw new Exception('Solicitud no encontrada');
    }
    
    if ($solicitud['conductor_id'] && $solicitud['conductor_id'] != $conductor_id) {
        throw new Exception('No tienes permiso para actualizar esta solicitud');
    }
    
    // Construir QUERY dinámico
    $update_fields = ["estado = :estado"];
    $params = [
        ':estado' => $nuevo_estado,
        ':solicitud_id' => $solicitud_id
    ];

    // Actualizar timestamps y estados
    if ($nuevo_estado === 'conductor_llego') {
        $update_fields[] = "conductor_llego_en = NOW()";
        
        // Actualizar asignación
        $stmtAsig = $db->prepare("UPDATE asignaciones_conductor SET estado = 'llegado' WHERE solicitud_id = ? AND conductor_id = ?");
        $stmtAsig->execute([$solicitud_id, $conductor_id]);
        
    } elseif ($nuevo_estado === 'recogido' || $nuevo_estado === 'en_curso') {
        $update_fields[] = "recogido_en = NOW()";
        
        // Actualizar asignación a 'en_curso'
        $stmtAsig = $db->prepare("UPDATE asignaciones_conductor SET estado = 'en_curso' WHERE solicitud_id = ? AND conductor_id = ?");
        $stmtAsig->execute([$solicitud_id, $conductor_id]);
        
    } elseif ($nuevo_estado === 'completada') {
        $update_fields[] = "completado_en = NOW()";
        $update_fields[] = "entregado_en = NOW()";
        
        if ($precio_final !== null) {
            $update_fields[] = "precio_final = :precio";
            $params[':precio'] = $precio_final;
        }
    } elseif ($nuevo_estado === 'cancelada') {
        $update_fields[] = "cancelado_en = NOW()";
        if ($motivo_cancelacion) {
            $update_fields[] = "motivo_cancelacion = :motivo";
            $params[':motivo'] = $motivo_cancelacion;
        }
    }

    // --- GUARDAR DATOS FINALES DEL VIAJE ---
    // NOTA: Si el estado es 'completada', finalize.php ya guardó los datos correctos
    // con el precio calculado. No sobrescribimos para evitar perder esos datos.
    if ($nuevo_estado !== 'completada') {
        if ($distancia_recorrida !== null) {
            $update_fields[] = "distancia_recorrida = :distancia";
            $params[':distancia'] = $distancia_recorrida;
        }
        if ($tiempo_transcurrido !== null) {
            $update_fields[] = "tiempo_transcurrido = :tiempo";
            $params[':tiempo'] = $tiempo_transcurrido;
        }
    }

    $query = "UPDATE solicitudes_servicio SET " . implode(', ', $update_fields) . " WHERE id = :solicitud_id";
    $stmt = $db->prepare($query);
    $stmt->execute($params);

    // Si se completó el viaje, actualizar disponibilidad del conductor y asignación
    if ($nuevo_estado === 'completada') {
        $stmt = $db->prepare("
            UPDATE detalles_conductor 
            SET disponible = 1,
                total_viajes = COALESCE(total_viajes, 0) + 1
            WHERE usuario_id = ?
        ");
        $stmt->execute([$conductor_id]);
        
        // Actualizar estado de la asignación a 'completado'
        $stmt = $db->prepare("UPDATE asignaciones_conductor SET estado = 'completado' WHERE solicitud_id = ? AND conductor_id = ?");
        $stmt->execute([$solicitud_id, $conductor_id]);
    }
    
    // Si se canceló, liberar al conductor
    if ($nuevo_estado === 'cancelada') {
        $stmt = $db->prepare("UPDATE detalles_conductor SET disponible = 1 WHERE usuario_id = ?");
        $stmt->execute([$conductor_id]);
        
        $stmt = $db->prepare("UPDATE asignaciones_conductor SET estado = 'cancelado' WHERE solicitud_id = ? AND conductor_id = ?");
        $stmt->execute([$solicitud_id, $conductor_id]);
    }
    
    echo json_encode([
        'success' => true,
        'message' => 'Estado actualizado correctamente',
        'nuevo_estado' => $nuevo_estado
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
