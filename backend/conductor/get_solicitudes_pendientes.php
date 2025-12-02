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
    $data = json_decode(file_get_contents('php://input'), true);
    
    // Validar datos requeridos
    if (!isset($data['conductor_id']) || !isset($data['latitud_actual']) || !isset($data['longitud_actual'])) {
        throw new Exception('Datos requeridos: conductor_id, latitud_actual, longitud_actual');
    }
    
    $conductorId = $data['conductor_id'];
    $latitudActual = $data['latitud_actual'];
    $longitudActual = $data['longitud_actual'];
    $radioKm = $data['radio_km'] ?? 5.0;
    
    $database = new Database();
    $db = $database->getConnection();
    
    // Verificar que sea un conductor válido y disponible
    $stmt = $db->prepare("
        SELECT u.id, dc.disponible, dc.vehiculo_tipo
        FROM usuarios u
        INNER JOIN detalles_conductor dc ON u.id = dc.usuario_id
        WHERE u.id = ? 
        AND u.tipo_usuario = 'conductor'
        AND dc.estado_verificacion = 'aprobado'
    ");
    $stmt->execute([$conductorId]);
    $conductor = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$conductor) {
        throw new Exception('Conductor no encontrado o no verificado');
    }
    
    // Actualizar ubicación del conductor
    $stmt = $db->prepare("
        UPDATE detalles_conductor 
        SET latitud_actual = ?,
            longitud_actual = ?,
            ultima_actualizacion = NOW()
        WHERE usuario_id = ?
    ");
    $stmt->execute([$latitudActual, $longitudActual, $conductorId]);
    
    if (!$conductor['disponible']) {
        echo json_encode([
            'success' => true,
            'message' => 'Conductor no disponible',
            'solicitudes' => []
        ]);
        exit;
    }
    
    // Buscar solicitudes pendientes cercanas al conductor
    // Usa la fórmula de Haversine para calcular distancia
    // Nota: Compatible con PostgreSQL - usa WHERE en lugar de HAVING y sintaxis de intervalo PostgreSQL
    $stmt = $db->prepare("
        SELECT 
            s.id,
            s.cliente_id,
            s.latitud_recogida,
            s.longitud_recogida,
            s.direccion_recogida,
            s.latitud_destino,
            s.longitud_destino,
            s.direccion_destino,
            s.tipo_servicio,
            s.distancia_estimada,
            s.tiempo_estimado,
            s.estado,
            COALESCE(s.solicitado_en, s.fecha_creacion) as fecha_solicitud,
            u.nombre as nombre_usuario,
            u.telefono as telefono_usuario,
            u.foto_perfil as foto_usuario,
            (6371 * acos(
                cos(radians(?)) * cos(radians(s.latitud_recogida)) *
                cos(radians(s.longitud_recogida) - radians(?)) +
                sin(radians(?)) * sin(radians(s.latitud_recogida))
            )) AS distancia_conductor_origen
        FROM solicitudes_servicio s
        INNER JOIN usuarios u ON s.cliente_id = u.id
        WHERE s.estado = 'pendiente'
        AND s.tipo_servicio = 'transporte'
        AND COALESCE(s.solicitado_en, s.fecha_creacion) >= NOW() - INTERVAL '15 minutes'
        AND (6371 * acos(
            cos(radians(?)) * cos(radians(s.latitud_recogida)) *
            cos(radians(s.longitud_recogida) - radians(?)) +
            sin(radians(?)) * sin(radians(s.latitud_recogida))
        )) <= ?
        ORDER BY distancia_conductor_origen ASC, COALESCE(s.solicitado_en, s.fecha_creacion) ASC
        LIMIT 10
    ");
    
    $stmt->execute([
        $latitudActual,
        $longitudActual,
        $latitudActual,
        $latitudActual,
        $longitudActual,
        $latitudActual,
        $radioKm
    ]);
    
    $solicitudes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Formatear las solicitudes
    $solicitudesFormateadas = array_map(function($solicitud) {
        // Calcular precio estimado (provisional - debería venir del sistema de precios)
        $precioEstimado = 5000 + ($solicitud['distancia_estimada'] * 2000);
        
        return [
            'id' => (int)$solicitud['id'],
            'usuario_id' => (int)$solicitud['cliente_id'],
            'nombre_usuario' => $solicitud['nombre_usuario'],
            'telefono_usuario' => $solicitud['telefono_usuario'],
            'foto_usuario' => $solicitud['foto_usuario'],
            'latitud_origen' => (float)$solicitud['latitud_recogida'],
            'longitud_origen' => (float)$solicitud['longitud_recogida'],
            'direccion_origen' => $solicitud['direccion_recogida'],
            'latitud_destino' => (float)$solicitud['latitud_destino'],
            'longitud_destino' => (float)$solicitud['longitud_destino'],
            'direccion_destino' => $solicitud['direccion_destino'],
            'tipo_servicio' => $solicitud['tipo_servicio'],
            'tipo_vehiculo' => 'motocicleta', // Por ahora fijo
            'distancia_km' => (float)$solicitud['distancia_estimada'],
            'duracion_minutos' => (int)$solicitud['tiempo_estimado'],
            'precio_estimado' => (float)$precioEstimado,
            'distancia_conductor_origen' => round((float)$solicitud['distancia_conductor_origen'], 2),
            'fecha_solicitud' => $solicitud['fecha_solicitud'],
        ];
    }, $solicitudes);
    
    echo json_encode([
        'success' => true,
        'total' => count($solicitudesFormateadas),
        'solicitudes' => $solicitudesFormateadas,
        'conductor_lat' => (float)$latitudActual,
        'conductor_lng' => (float)$longitudActual,
        'radio_busqueda_km' => (float)$radioKm,
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
