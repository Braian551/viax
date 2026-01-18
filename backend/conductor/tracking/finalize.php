<?php
/**
 * API: Finalizar tracking y calcular precio final
 * Endpoint: conductor/tracking/finalize.php
 * Método: POST
 * 
 * Este endpoint se llama cuando el viaje termina para:
 * 1. Cerrar el tracking
 * 2. Calcular el precio final basado en distancia/tiempo REAL
 * 3. Actualizar la solicitud con los valores finales
 * 4. Retornar el precio que coincide para conductor y cliente
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Método no permitido']);
    exit();
}

require_once '../../config/database.php';

try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    // Validar campos requeridos
    $solicitud_id = isset($input['solicitud_id']) ? intval($input['solicitud_id']) : 0;
    $conductor_id = isset($input['conductor_id']) ? intval($input['conductor_id']) : 0;
    
    // Valores finales del tracking (enviados por la app del conductor)
    $distancia_final_km = isset($input['distancia_final_km']) ? floatval($input['distancia_final_km']) : null;
    $tiempo_final_seg = isset($input['tiempo_final_seg']) ? intval($input['tiempo_final_seg']) : null;
    
    if ($solicitud_id <= 0 || $conductor_id <= 0) {
        throw new Exception('solicitud_id y conductor_id son requeridos');
    }
    
    $database = new Database();
    $db = $database->getConnection();
    
    $db->beginTransaction();
    
    // Obtener datos del viaje
    $stmt = $db->prepare("
        SELECT 
            s.id,
            s.tipo_servicio,
            s.tipo_vehiculo,
            s.empresa_id,
            s.estado,
            s.distancia_estimada,
            s.tiempo_estimado,
            s.precio_estimado,
            s.distancia_recorrida,
            s.tiempo_transcurrido
        FROM solicitudes_servicio s
        WHERE s.id = :solicitud_id
    ");
    $stmt->execute([':solicitud_id' => $solicitud_id]);
    $viaje = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$viaje) {
        throw new Exception('Viaje no encontrado');
    }
    
    // Obtener el último punto de tracking para valores más precisos
    $stmt = $db->prepare("
        SELECT 
            distancia_acumulada_km,
            tiempo_transcurrido_seg,
            precio_parcial,
            timestamp_gps
        FROM viaje_tracking_realtime
        WHERE solicitud_id = :solicitud_id
        ORDER BY timestamp_gps DESC
        LIMIT 1
    ");
    $stmt->execute([':solicitud_id' => $solicitud_id]);
    $ultimo_tracking = $stmt->fetch(PDO::FETCH_ASSOC);
    
    // Usar valores del tracking si existen, si no, usar los enviados por la app
    // IMPORTANTE: El tiempo del cronómetro del conductor tiene PRIORIDAD
    // porque es el tiempo REAL desde "comenzar viaje" hasta "finalizar"
    if ($ultimo_tracking) {
        // Distancia del tracking GPS (más precisa)
        $distancia_real = floatval($ultimo_tracking['distancia_acumulada_km']);
        // Tiempo: usar el del conductor (cronómetro) si se envió, sino el del tracking
        $tiempo_real_seg = $tiempo_final_seg ?? intval($ultimo_tracking['tiempo_transcurrido_seg']);
    } else {
        // Sin tracking: usar valores enviados por la app, o los guardados en la solicitud
        // NUNCA usar distancia estimada como fallback - si no hay tracking, es 0
        $distancia_real = $distancia_final_km ?? floatval($viaje['distancia_recorrida'] ?? 0);
        $tiempo_real_seg = $tiempo_final_seg ?? intval($viaje['tiempo_transcurrido'] ?? 0);
    }
    
    $tiempo_real_min = ceil($tiempo_real_seg / 60);
    
    // =====================================================
    // OBTENER CONFIGURACIÓN DE PRECIOS (por empresa o global)
    // =====================================================
    $empresa_id = $viaje['empresa_id'];
    $config = null;
    
    // Primero buscar tarifa de la empresa
    if ($empresa_id) {
        $stmt = $db->prepare("
            SELECT 
                tarifa_base,
                costo_por_km,
                costo_por_minuto,
                tarifa_minima,
                tarifa_maxima,
                comision_plataforma,
                recargo_hora_pico,
                hora_pico_inicio_manana,
                hora_pico_fin_manana,
                hora_pico_inicio_tarde,
                hora_pico_fin_tarde,
                recargo_nocturno,
                hora_nocturna_inicio,
                hora_nocturna_fin,
                umbral_km_descuento,
                descuento_distancia_larga
            FROM configuracion_precios 
            WHERE empresa_id = :empresa_id AND tipo_vehiculo = :tipo AND activo = 1
            LIMIT 1
        ");
        $stmt->execute([':empresa_id' => $empresa_id, ':tipo' => $viaje['tipo_vehiculo'] ?? 'moto']);
        $config = $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    // Si no hay tarifa de empresa, usar tarifa global
    if (!$config) {
        $stmt = $db->prepare("
            SELECT 
                tarifa_base,
                costo_por_km,
                costo_por_minuto,
                tarifa_minima,
                tarifa_maxima,
                comision_plataforma,
                recargo_hora_pico,
                hora_pico_inicio_manana,
                hora_pico_fin_manana,
                hora_pico_inicio_tarde,
                hora_pico_fin_tarde,
                recargo_nocturno,
                hora_nocturna_inicio,
                hora_nocturna_fin,
                umbral_km_descuento,
                descuento_distancia_larga
            FROM configuracion_precios 
            WHERE empresa_id IS NULL AND tipo_vehiculo = :tipo AND activo = 1
            LIMIT 1
        ");
        $stmt->execute([':tipo' => $viaje['tipo_vehiculo'] ?? 'moto']);
        $config = $stmt->fetch(PDO::FETCH_ASSOC);
    }
    
    if (!$config) {
        throw new Exception('No hay configuración de precios para este tipo de vehículo');
    }
    
    // =====================================================
    // CALCULAR PRECIO FINAL
    // =====================================================
    
    $tarifa_base = floatval($config['tarifa_base']);
    $precio_distancia = $distancia_real * floatval($config['costo_por_km']);
    $precio_tiempo = $tiempo_real_min * floatval($config['costo_por_minuto']);
    
    $subtotal = $tarifa_base + $precio_distancia + $precio_tiempo;
    
    // Descuento por distancia larga
    $descuento = 0;
    if ($distancia_real >= floatval($config['umbral_km_descuento'])) {
        $descuento = $subtotal * (floatval($config['descuento_distancia_larga']) / 100);
    }
    
    $subtotal_con_descuento = $subtotal - $descuento;
    
    // Recargos por horario
    $hora_actual = date('H:i:s');
    $recargo = 0;
    $tipo_recargo = 'normal';
    
    // Hora pico mañana
    if ($hora_actual >= $config['hora_pico_inicio_manana'] && 
        $hora_actual <= $config['hora_pico_fin_manana']) {
        $recargo = $subtotal_con_descuento * (floatval($config['recargo_hora_pico']) / 100);
        $tipo_recargo = 'hora_pico_manana';
    }
    // Hora pico tarde
    elseif ($hora_actual >= $config['hora_pico_inicio_tarde'] && 
            $hora_actual <= $config['hora_pico_fin_tarde']) {
        $recargo = $subtotal_con_descuento * (floatval($config['recargo_hora_pico']) / 100);
        $tipo_recargo = 'hora_pico_tarde';
    }
    // Nocturno
    elseif ($hora_actual >= $config['hora_nocturna_inicio'] || 
            $hora_actual <= $config['hora_nocturna_fin']) {
        $recargo = $subtotal_con_descuento * (floatval($config['recargo_nocturno']) / 100);
        $tipo_recargo = 'nocturno';
    }
    
    $precio_total = $subtotal_con_descuento + $recargo;
    
    // Aplicar tarifa mínima
    $tarifa_minima = floatval($config['tarifa_minima']);
    if ($precio_total < $tarifa_minima) {
        $precio_total = $tarifa_minima;
    }
    
    // Aplicar tarifa máxima si existe
    if ($config['tarifa_maxima'] !== null) {
        $tarifa_maxima = floatval($config['tarifa_maxima']);
        if ($precio_total > $tarifa_maxima) {
            $precio_total = $tarifa_maxima;
        }
    }
    
    // Redondear a 100 COP más cercano (típico en Colombia)
    $precio_final = round($precio_total / 100) * 100;
    
    // Calcular comisiones
    $comision_plataforma_porcentaje = floatval($config['comision_plataforma']);
    $comision_plataforma = $precio_final * ($comision_plataforma_porcentaje / 100);
    $ganancia_conductor = $precio_final - $comision_plataforma;
    
    // =====================================================
    // DETECTAR DESVÍOS SIGNIFICATIVOS
    // =====================================================
    
    $distancia_estimada = floatval($viaje['distancia_estimada']);
    $diferencia_distancia = $distancia_real - $distancia_estimada;
    $porcentaje_desvio = $distancia_estimada > 0 
        ? ($diferencia_distancia / $distancia_estimada) * 100 
        : 0;
    
    $tuvo_desvio = abs($porcentaje_desvio) > 20; // Más del 20% de diferencia
    
    // =====================================================
    // ACTUALIZAR RESUMEN DE TRACKING
    // =====================================================
    
    $stmt = $db->prepare("
        INSERT INTO viaje_resumen_tracking (
            solicitud_id,
            distancia_real_km,
            tiempo_real_minutos,
            distancia_estimada_km,
            tiempo_estimado_minutos,
            diferencia_distancia_km,
            diferencia_tiempo_min,
            porcentaje_desvio_distancia,
            precio_estimado,
            precio_final_calculado,
            precio_final_aplicado,
            tiene_desvio_ruta,
            fin_viaje_real,
            actualizado_en
        ) VALUES (
            :solicitud_id,
            :distancia_real,
            :tiempo_real,
            :distancia_estimada,
            :tiempo_estimado,
            :diff_distancia,
            :diff_tiempo,
            :porcentaje_desvio,
            :precio_estimado,
            :precio_calculado,
            :precio_aplicado,
            :tuvo_desvio,
            NOW(),
            NOW()
        )
        ON CONFLICT (solicitud_id) DO UPDATE SET
            distancia_real_km = EXCLUDED.distancia_real_km,
            tiempo_real_minutos = EXCLUDED.tiempo_real_minutos,
            distancia_estimada_km = EXCLUDED.distancia_estimada_km,
            tiempo_estimado_minutos = EXCLUDED.tiempo_estimado_minutos,
            diferencia_distancia_km = EXCLUDED.diferencia_distancia_km,
            diferencia_tiempo_min = EXCLUDED.diferencia_tiempo_min,
            porcentaje_desvio_distancia = EXCLUDED.porcentaje_desvio_distancia,
            precio_estimado = EXCLUDED.precio_estimado,
            precio_final_calculado = EXCLUDED.precio_final_calculado,
            precio_final_aplicado = EXCLUDED.precio_final_aplicado,
            tiene_desvio_ruta = EXCLUDED.tiene_desvio_ruta,
            fin_viaje_real = NOW(),
            actualizado_en = NOW()
    ");
    
    $tiempo_estimado_min = intval($viaje['tiempo_estimado']);
    $diff_tiempo_min = $tiempo_real_min - $tiempo_estimado_min;
    
    $stmt->execute([
        ':solicitud_id' => $solicitud_id,
        ':distancia_real' => $distancia_real,
        ':tiempo_real' => $tiempo_real_min,
        ':distancia_estimada' => $distancia_estimada,
        ':tiempo_estimado' => $tiempo_estimado_min,
        ':diff_distancia' => $diferencia_distancia,
        ':diff_tiempo' => $diff_tiempo_min,
        ':porcentaje_desvio' => $porcentaje_desvio,
        ':precio_estimado' => floatval($viaje['precio_estimado']),
        ':precio_calculado' => $precio_final,
        ':precio_aplicado' => $precio_final,
        ':tuvo_desvio' => $tuvo_desvio
    ]);
    
    // =====================================================
    // ACTUALIZAR SOLICITUD
    // =====================================================
    
    $stmt = $db->prepare("
        UPDATE solicitudes_servicio SET
            precio_final = :precio_final,
            distancia_recorrida = :distancia,
            tiempo_transcurrido = :tiempo,
            precio_ajustado_por_tracking = TRUE,
            tuvo_desvio_ruta = :tuvo_desvio
        WHERE id = :solicitud_id
    ");
    
    $stmt->execute([
        ':precio_final' => $precio_final,
        ':distancia' => $distancia_real,
        ':tiempo' => $tiempo_real_seg,
        ':tuvo_desvio' => $tuvo_desvio,
        ':solicitud_id' => $solicitud_id
    ]);
    
    $db->commit();
    
    // =====================================================
    // RESPUESTA
    // =====================================================
    
    $response = [
        'success' => true,
        'message' => 'Tracking finalizado y precio calculado',
        'precio_final' => $precio_final,
        'desglose' => [
            'tarifa_base' => $tarifa_base,
            'precio_distancia' => round($precio_distancia, 2),
            'precio_tiempo' => round($precio_tiempo, 2),
            'subtotal' => round($subtotal, 2),
            'descuento_distancia' => round($descuento, 2),
            'recargo' => round($recargo, 2),
            'tipo_recargo' => $tipo_recargo,
            'total_antes_redondeo' => round($precio_total, 2),
            'total_final' => $precio_final
        ],
        'tracking' => [
            'distancia_real_km' => round($distancia_real, 2),
            'tiempo_real_min' => $tiempo_real_min,
            'tiempo_real_seg' => $tiempo_real_seg,
            'distancia_estimada_km' => $distancia_estimada,
            'tiempo_estimado_min' => $tiempo_estimado_min
        ],
        'diferencias' => [
            'diferencia_distancia_km' => round($diferencia_distancia, 2),
            'diferencia_tiempo_min' => $diff_tiempo_min,
            'porcentaje_desvio' => round($porcentaje_desvio, 1),
            'tuvo_desvio_significativo' => $tuvo_desvio
        ],
        'comisiones' => [
            'comision_plataforma_porcentaje' => $comision_plataforma_porcentaje,
            'comision_plataforma' => round($comision_plataforma, 2),
            'ganancia_conductor' => round($ganancia_conductor, 2)
        ],
        'comparacion_precio' => [
            'precio_estimado' => floatval($viaje['precio_estimado']),
            'precio_final' => $precio_final,
            'diferencia' => $precio_final - floatval($viaje['precio_estimado'])
        ]
    ];
    
    echo json_encode($response);
    
} catch (Exception $e) {
    if (isset($db) && $db->inTransaction()) {
        $db->rollBack();
    }
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
