<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Access-Control-Allow-Headers: Content-Type, Accept');

require_once '../config/database.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Método no permitido']);
    exit();
}

try {
    $database = new Database();
    $db = $database->getConnection();

    $conductor_id = isset($_GET['conductor_id']) ? intval($_GET['conductor_id']) : 0;
    $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 20;
    $offset = ($page - 1) * $limit;

    if ($conductor_id <= 0) {
        throw new Exception('ID de conductor inválido');
    }

    // Contar total de viajes
    $query_count = "SELECT COUNT(*) as total
                    FROM solicitudes_servicio s
                    INNER JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id
                    WHERE ac.conductor_id = :conductor_id
                    AND s.estado IN ('completada', 'entregado')";
    
    $stmt_count = $db->prepare($query_count);
    $stmt_count->bindParam(':conductor_id', $conductor_id, PDO::PARAM_INT);
    $stmt_count->execute();
    $total = $stmt_count->fetch(PDO::FETCH_ASSOC)['total'];

    // Obtener historial de viajes - Usar datos REALES, NO estimados como fallback
    $query = "SELECT 
                s.id,
                s.tipo_servicio,
                s.estado,
                -- Distancia REAL solamente (tracking o recorrida), NO usar estimada
                COALESCE(
                    NULLIF(vrt.distancia_real_km, 0),
                    NULLIF(s.distancia_recorrida, 0)
                ) as distancia_km,
                -- Tiempo en SEGUNDOS para mayor precisión
                COALESCE(
                    NULLIF(vrt.tiempo_real_minutos, 0) * 60,
                    CASE 
                        WHEN s.completado_en IS NOT NULL AND s.aceptado_en IS NOT NULL 
                        THEN EXTRACT(EPOCH FROM (s.completado_en - s.aceptado_en))
                        ELSE NULL
                    END
                ) as duracion_segundos,
                s.tiempo_estimado as duracion_estimada,
                s.distancia_estimada as distancia_estimada,
                s.solicitado_en as fecha_solicitud,
                s.completado_en as fecha_completado,
                s.aceptado_en as fecha_aceptado,
                s.direccion_recogida as origen,
                s.direccion_destino as destino,
                -- Usar precio FINAL si existe y es > 0, sino estimado
                CASE 
                    WHEN s.precio_final IS NOT NULL AND s.precio_final > 0 
                    THEN s.precio_final
                    ELSE s.precio_estimado
                END as precio,
                s.precio_estimado,
                s.precio_final,
                s.metodo_pago,
                s.pago_confirmado,
                u.nombre as cliente_nombre,
                u.apellido as cliente_apellido,
                -- Buscar calificación que el CLIENTE dio al conductor
                c.calificacion,
                c.comentarios,
                -- Datos de tracking para referencia
                vrt.distancia_real_km as tracking_distancia,
                vrt.tiempo_real_minutos as tracking_tiempo,
                vrt.precio_final_aplicado as tracking_precio
              FROM solicitudes_servicio s
              INNER JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id
              INNER JOIN usuarios u ON s.cliente_id = u.id
              LEFT JOIN calificaciones c ON s.id = c.solicitud_id AND c.usuario_calificado_id = :conductor_id2
              LEFT JOIN viaje_resumen_tracking vrt ON s.id = vrt.solicitud_id
              WHERE ac.conductor_id = :conductor_id
              AND s.estado IN ('completada', 'entregado')
              ORDER BY s.id DESC
              LIMIT :limit OFFSET :offset";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':conductor_id', $conductor_id, PDO::PARAM_INT);
    $stmt->bindParam(':conductor_id2', $conductor_id, PDO::PARAM_INT);
    $stmt->bindParam(':limit', $limit, PDO::PARAM_INT);
    $stmt->bindParam(':offset', $offset, PDO::PARAM_INT);
    $stmt->execute();

    $viajes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Asegurar que los valores numéricos sean del tipo correcto
    $viajes = array_map(function($viaje) {
        // Precio REAL: prioridad -> tracking_precio > precio_final > precio (calculado) > precio_estimado
        $precioReal = 0;
        if (isset($viaje['tracking_precio']) && $viaje['tracking_precio'] > 0) {
            $precioReal = (float)$viaje['tracking_precio'];
        } elseif (isset($viaje['precio_final']) && $viaje['precio_final'] > 0) {
            $precioReal = (float)$viaje['precio_final'];
        } elseif (isset($viaje['precio']) && $viaje['precio'] > 0) {
            $precioReal = (float)$viaje['precio'];
        } else {
            $precioReal = (float)($viaje['precio_estimado'] ?? 0);
        }
        
        // Ganancia = tarifa real - comisión (10%)
        // Es decir, el conductor recibe el 90% del precio real
        $comisionEmpresa = $precioReal * 0.10;
        $gananciaViaje = $precioReal - $comisionEmpresa; // 90% del precio real
        
        // Distancia: usar SOLO la real, mostrar 0 si no hay datos reales
        $distanciaKm = (float)($viaje['distancia_km'] ?? 0);
        
        // Duración en segundos (real o null)
        $duracionSegundos = isset($viaje['duracion_segundos']) ? (int)round((float)$viaje['duracion_segundos']) : null;
        
        return [
            'id' => (int)$viaje['id'],
            'tipo_servicio' => $viaje['tipo_servicio'],
            'estado' => $viaje['estado'],
            // Distancia real (0 si no hay tracking)
            'distancia_km' => $distanciaKm,
            'distancia_estimada' => $viaje['distancia_estimada'] ? (float)$viaje['distancia_estimada'] : null,
            // Duración en segundos (para formato flexible en frontend)
            'duracion_segundos' => $duracionSegundos,
            'duracion_minutos' => $duracionSegundos ? (int)ceil($duracionSegundos / 60) : null,
            'duracion_estimada' => $viaje['duracion_estimada'] ? (int)$viaje['duracion_estimada'] : null,
            'fecha_solicitud' => $viaje['fecha_solicitud'],
            'fecha_completado' => $viaje['fecha_completado'],
            'fecha_aceptado' => $viaje['fecha_aceptado'] ?? null,
            'origen' => $viaje['origen'],
            'destino' => $viaje['destino'],
            'cliente_nombre' => $viaje['cliente_nombre'],
            'cliente_apellido' => $viaje['cliente_apellido'],
            'calificacion' => $viaje['calificacion'] ? (int)$viaje['calificacion'] : null,
            'comentario' => $viaje['comentarios'],
            // Precios - usar precio REAL (del tracking o final)
            'precio_estimado' => (float)($viaje['precio_estimado'] ?? 0),
            'precio_final' => $precioReal,
            'metodo_pago' => $viaje['metodo_pago'] ?? 'efectivo',
            'pago_confirmado' => (bool)$viaje['pago_confirmado'],
            // Ganancias y comisiones (basadas en precio real)
            'ganancia_viaje' => $gananciaViaje,
            'comision_empresa' => $comisionEmpresa
        ];
    }, $viajes);

    echo json_encode([
        'success' => true,
        'viajes' => $viajes,
        'pagination' => [
            'page' => (int)$page,
            'limit' => (int)$limit,
            'total' => (int)$total,
            'total_pages' => (int)ceil($total / $limit)
        ],
        'message' => 'Historial obtenido exitosamente'
    ], JSON_NUMERIC_CHECK);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'viajes' => []
    ]);
}
?>
