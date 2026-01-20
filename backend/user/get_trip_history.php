<?php
/**
 * get_trip_history.php
 * Obtiene el historial de viajes de un usuario
 */

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once '../config/database.php';

try {
    $database = new Database();
    $conn = $database->getConnection();
    
    // Obtener parámetros
    $usuario_id = isset($_GET['usuario_id']) ? intval($_GET['usuario_id']) : 0;
    $page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
    $limit = isset($_GET['limit']) ? min(50, max(1, intval($_GET['limit']))) : 20;
    $estado = isset($_GET['estado']) ? $_GET['estado'] : null;
    $fecha_inicio = isset($_GET['fecha_inicio']) ? $_GET['fecha_inicio'] : null;
    $fecha_fin = isset($_GET['fecha_fin']) ? $_GET['fecha_fin'] : null;
    
    if ($usuario_id <= 0) {
        echo json_encode([
            'success' => false,
            'error' => 'usuario_id es requerido'
        ]);
        exit;
    }
    
    $offset = ($page - 1) * $limit;
    
    // Construir query base - NOTA: la columna es cliente_id, no usuario_id
    $whereClause = "WHERE ss.cliente_id = :usuario_id";
    $params = [':usuario_id' => $usuario_id];
    
    // Filtro por estado
    if ($estado && $estado !== 'all') {
        if ($estado === 'completada') {
            $whereClause .= " AND ss.estado IN ('completada', 'entregado')";
        } else {
            $whereClause .= " AND ss.estado = :estado";
            $params[':estado'] = $estado;
        }
    }
    // Filtro por fecha
    if ($fecha_inicio) {
        $whereClause .= " AND DATE(COALESCE(ss.solicitado_en, ss.fecha_creacion)) >= :fecha_inicio";
        $params[':fecha_inicio'] = $fecha_inicio;
    }

    if ($fecha_fin) {
        $whereClause .= " AND DATE(COALESCE(ss.solicitado_en, ss.fecha_creacion)) <= :fecha_fin";
        $params[':fecha_fin'] = $fecha_fin;
    }
    
    // Obtener total de registros
    $countQuery = "SELECT COUNT(*) as total FROM solicitudes_servicio ss $whereClause";
    $countStmt = $conn->prepare($countQuery);
    foreach ($params as $key => $value) {
        $countStmt->bindValue($key, $value);
    }
    $countStmt->execute();
    $totalRecords = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    $totalPages = ceil($totalRecords / $limit);
    
    // Query principal con JOIN a conductores
    // Usar datos reales (distancia_recorrida, tiempo_transcurrido) cuando estén disponibles
    // y datos estimados como fallback
    $query = "
        SELECT 
            ss.id,
            COALESCE(ss.tipo_servicio, 'transporte') as tipo_servicio,
            ss.estado,
            COALESCE(ss.direccion_recogida, '') as origen,
            COALESCE(ss.direccion_destino, '') as destino,
            ss.distancia_estimada,
            ss.tiempo_estimado,
            -- Usar datos reales si existen, sino estimados
            COALESCE(ss.distancia_recorrida, ss.distancia_estimada) as distancia_real,
            COALESCE(ss.tiempo_transcurrido, ss.tiempo_estimado) as tiempo_real,
            COALESCE(ss.precio_estimado, 0) as precio_estimado,
            COALESCE(ss.precio_final, ss.precio_estimado, 0) as precio_final,
            COALESCE(ss.metodo_pago, 'efectivo') as metodo_pago,
            COALESCE(ss.pago_confirmado, false) as pago_confirmado,
            COALESCE(ss.solicitado_en, ss.fecha_creacion) as fecha_solicitud,
            ss.completado_en as fecha_completado,
            ac.conductor_id,
            u.nombre as conductor_nombre,
            u.apellido as conductor_apellido,
            u.foto_perfil as conductor_foto,
            COALESCE(dc.calificacion_promedio, 0) as calificacion_conductor,
            -- Obtener la calificación que el cliente dio al conductor en este viaje
            cal.calificacion as calificacion_dada,
            cal.comentario as comentario_dado
        FROM solicitudes_servicio ss
        LEFT JOIN asignaciones_conductor ac ON ss.id = ac.solicitud_id AND ac.estado IN ('aceptada', 'completada', 'completado')
        LEFT JOIN detalles_conductor dc ON ac.conductor_id = dc.usuario_id
        LEFT JOIN usuarios u ON ac.conductor_id = u.id
        LEFT JOIN calificaciones cal ON cal.solicitud_id = ss.id AND cal.usuario_calificador_id = ss.cliente_id
        $whereClause
        ORDER BY COALESCE(ss.solicitado_en, ss.fecha_creacion) DESC
        LIMIT :limit OFFSET :offset
    ";
    
    $stmt = $conn->prepare($query);
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();
    
    $viajes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Formatear datos
    $viajesFormateados = array_map(function($viaje) {
        // Usar precio_final si está disponible, sino precio_estimado
        $precioMostrar = ($viaje['precio_final'] && $viaje['precio_final'] > 0) 
            ? (float)$viaje['precio_final'] 
            : (float)$viaje['precio_estimado'];
            
        return [
            'id' => (int)$viaje['id'],
            'tipo_servicio' => $viaje['tipo_servicio'] ?? 'transporte',
            'estado' => $viaje['estado'],
            'origen' => $viaje['origen'] ?? '',
            'destino' => $viaje['destino'] ?? '',
            // Usar datos reales en lugar de estimados
            'distancia_km' => $viaje['distancia_real'] ? (float)$viaje['distancia_real'] : null,
            'duracion_minutos' => $viaje['tiempo_real'] ? (int)$viaje['tiempo_real'] : null,
            // Mantener estimados para referencia si se necesitan
            'distancia_estimada' => $viaje['distancia_estimada'] ? (float)$viaje['distancia_estimada'] : null,
            'duracion_estimada' => $viaje['tiempo_estimado'] ? (int)$viaje['tiempo_estimado'] : null,
            'precio_estimado' => (float)$viaje['precio_estimado'],
            'precio_final' => $precioMostrar,
            'metodo_pago' => $viaje['metodo_pago'],
            'pago_confirmado' => (bool)$viaje['pago_confirmado'],
            'fecha_solicitud' => $viaje['fecha_solicitud'],
            'fecha_completado' => $viaje['fecha_completado'],
            'conductor_id' => isset($viaje['conductor_id']) ? (int)$viaje['conductor_id'] : null,
            'conductor_nombre' => $viaje['conductor_nombre'],
            'conductor_apellido' => $viaje['conductor_apellido'],
            'conductor_foto' => $viaje['conductor_foto'],
            'calificacion_conductor' => $viaje['calificacion_conductor'] ? (float)$viaje['calificacion_conductor'] : null,
            // Calificación que el cliente dio en este viaje
            'calificacion_dada' => $viaje['calificacion_dada'] ? (int)$viaje['calificacion_dada'] : null,
            'comentario_dado' => $viaje['comentario_dado'],
        ];
    }, $viajes);
    
    echo json_encode([
        'success' => true,
        'viajes' => $viajesFormateados,
        'pagination' => [
            'current_page' => $page,
            'total_pages' => $totalPages,
            'total_records' => (int)$totalRecords,
            'per_page' => $limit
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Error del servidor: ' . $e->getMessage()
    ]);
}
?>
