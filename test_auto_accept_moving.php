<?php
/**
 * Test: Auto-accept con simulación de movimiento del conductor
 * 
 * Este script:
 * 1. Acepta solicitudes automáticamente
 * 2. Ubica al conductor a ~2km del punto de recogida
 * 3. Simula el movimiento del conductor hacia el cliente
 * 
 * Uso: php test_auto_accept_moving.php
 * Para detener: Ctrl+C
 */
require_once 'backend/config/database.php';

$emailConductor = 'braianoquen2@gmail.com';
$emailCliente = 'braianoquendurango@gmail.com';

// Configuración de simulación
$CONDUCTOR_DISTANCE_KM = 2.0;  // Distancia inicial del conductor (2km)
$MOVE_INTERVAL_SECONDS = 3;    // Actualizar posición cada 3 segundos
$SPEED_KMH = 30;               // Velocidad de movimiento (30 km/h)

echo "==========================================================\n";
echo "🤖 AUTO-ACCEPT + SIMULACIÓN DE MOVIMIENTO\n";
echo "==========================================================\n";
echo "👤 Cliente: $emailCliente\n";
echo "🚗 Conductor: $emailConductor\n";
echo "📏 Distancia inicial: {$CONDUCTOR_DISTANCE_KM}km\n";
echo "🚀 Velocidad: {$SPEED_KMH} km/h\n";
echo "==========================================================\n\n";

$db = (new Database())->getConnection();

// Obtener IDs
$stmt = $db->prepare("SELECT id, nombre FROM usuarios WHERE email = ?");
$stmt->execute([$emailConductor]);
$conductor = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$conductor) {
    echo "❌ Conductor no encontrado: $emailConductor\n";
    exit(1);
}
$conductorId = $conductor['id'];
echo "✅ Conductor: {$conductor['nombre']} (ID: $conductorId)\n";

$stmt->execute([$emailCliente]);
$cliente = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$cliente) {
    echo "❌ Cliente no encontrado: $emailCliente\n";
    exit(1);
}
$clienteId = $cliente['id'];
echo "✅ Cliente: {$cliente['nombre']} (ID: $clienteId)\n";

// Marcar conductor como disponible
$stmt = $db->prepare("UPDATE detalles_conductor SET disponible = 1 WHERE usuario_id = ?");
$stmt->execute([$conductorId]);
echo "✅ Conductor marcado como disponible\n";

echo "\n⏳ Esperando solicitudes... (Ctrl+C para detener)\n";
echo "──────────────────────────────────────────────────\n\n";

/**
 * Calcular punto a cierta distancia de otro punto
 */
function calcularPuntoADistancia($lat, $lng, $distanciaKm, $angulo) {
    $R = 6371; // Radio de la Tierra en km
    $lat1 = deg2rad($lat);
    $lng1 = deg2rad($lng);
    $bearing = deg2rad($angulo);
    
    $lat2 = asin(sin($lat1) * cos($distanciaKm/$R) + cos($lat1) * sin($distanciaKm/$R) * cos($bearing));
    $lng2 = $lng1 + atan2(sin($bearing) * sin($distanciaKm/$R) * cos($lat1), cos($distanciaKm/$R) - sin($lat1) * sin($lat2));
    
    return [
        'lat' => rad2deg($lat2),
        'lng' => rad2deg($lng2)
    ];
}

/**
 * Calcular distancia entre dos puntos (Haversine)
 */
function calcularDistancia($lat1, $lng1, $lat2, $lng2) {
    $R = 6371;
    $dLat = deg2rad($lat2 - $lat1);
    $dLng = deg2rad($lng2 - $lng1);
    $a = sin($dLat/2) * sin($dLat/2) + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng/2) * sin($dLng/2);
    $c = 2 * atan2(sqrt($a), sqrt(1-$a));
    return $R * $c;
}

/**
 * Interpolar posición entre dos puntos
 */
function interpolarPosicion($latInicio, $lngInicio, $latFin, $lngFin, $progreso) {
    $progreso = max(0, min(1, $progreso));
    return [
        'lat' => $latInicio + ($latFin - $latInicio) * $progreso,
        'lng' => $lngInicio + ($lngFin - $lngInicio) * $progreso
    ];
}

$lastSolicitudId = 0;
$iteration = 0;
$activeTripData = null;
$lastMoveTime = 0;

while (true) {
    $iteration++;
    $currentTime = time();
    
    // Si hay un viaje activo, mover al conductor
    if ($activeTripData !== null) {
        if ($currentTime - $lastMoveTime >= $MOVE_INTERVAL_SECONDS) {
            $lastMoveTime = $currentTime;
            
            // Calcular nueva posición
            $tiempoTranscurrido = $currentTime - $activeTripData['start_time'];
            $distanciaRecorrida = ($SPEED_KMH / 3600) * $tiempoTranscurrido; // km
            $progreso = min(1, $distanciaRecorrida / $activeTripData['distancia_inicial']);
            
            $nuevaPos = interpolarPosicion(
                $activeTripData['conductor_lat_inicial'],
                $activeTripData['conductor_lng_inicial'],
                $activeTripData['pickup_lat'],
                $activeTripData['pickup_lng'],
                $progreso
            );
            
            // Actualizar posición del conductor en la base de datos
            $stmt = $db->prepare("UPDATE detalles_conductor SET latitud_actual = ?, longitud_actual = ? WHERE usuario_id = ?");
            $stmt->execute([$nuevaPos['lat'], $nuevaPos['lng'], $conductorId]);
            
            $distanciaRestante = calcularDistancia(
                $nuevaPos['lat'], $nuevaPos['lng'],
                $activeTripData['pickup_lat'], $activeTripData['pickup_lng']
            );
            
            $etaMinutos = round(($distanciaRestante / $SPEED_KMH) * 60);
            
            echo "\r🚗 Conductor moviéndose... Progreso: " . round($progreso * 100) . "% | ETA: {$etaMinutos} min | Distancia: " . round($distanciaRestante, 2) . " km    ";
            
            // Si llegó al destino
            if ($progreso >= 0.98) {
                echo "\n✅ ¡Conductor llegó al punto de encuentro!\n";
                
                // Actualizar estado del viaje
                $stmt = $db->prepare("UPDATE solicitudes_servicio SET estado = 'conductor_llego' WHERE id = ?");
                $stmt->execute([$activeTripData['solicitud_id']]);
                
                // Limpiar viaje activo
                $activeTripData = null;
                
                // Volver a marcar como disponible
                $stmt = $db->prepare("UPDATE detalles_conductor SET disponible = 1 WHERE usuario_id = ?");
                $stmt->execute([$conductorId]);
                
                echo "──────────────────────────────────────────────────\n\n";
            }
        }
        
        usleep(100000); // 100ms
        continue;
    }
    
    // Buscar nuevas solicitudes pendientes
    $stmt = $db->prepare("
        SELECT id, uuid_solicitud, latitud_recogida, longitud_recogida, direccion_recogida, direccion_destino, estado, fecha_creacion
        FROM solicitudes_servicio 
        WHERE cliente_id = ? 
          AND estado = 'pendiente'
          AND id > ?
        ORDER BY id ASC
        LIMIT 1
    ");
    $stmt->execute([$clienteId, $lastSolicitudId]);
    $solicitud = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($solicitud) {
        $solicitudId = $solicitud['id'];
        $lastSolicitudId = $solicitudId;
        
        $pickupLat = (float)$solicitud['latitud_recogida'];
        $pickupLng = (float)$solicitud['longitud_recogida'];
        
        echo "\n🆕 ¡Nueva solicitud detectada! (ID: $solicitudId)\n";
        echo "   📍 Origen: {$solicitud['direccion_recogida']}\n";
        echo "   📍 Destino: {$solicitud['direccion_destino']}\n";
        echo "   📍 Coordenadas pickup: $pickupLat, $pickupLng\n";
        echo "   ⏰ Creada: {$solicitud['fecha_creacion']}\n";
        
        // Calcular posición inicial del conductor (a CONDUCTOR_DISTANCE_KM al sur-oeste)
        $angulo = 225; // Sur-oeste
        $conductorInicial = calcularPuntoADistancia($pickupLat, $pickupLng, $CONDUCTOR_DISTANCE_KM, $angulo);
        
        echo "   🚗 Ubicando conductor a {$CONDUCTOR_DISTANCE_KM}km del punto de recogida\n";
        echo "   📍 Posición conductor: {$conductorInicial['lat']}, {$conductorInicial['lng']}\n";
        
        // Actualizar posición del conductor
        $stmt = $db->prepare("UPDATE detalles_conductor SET latitud_actual = ?, longitud_actual = ? WHERE usuario_id = ?");
        $stmt->execute([$conductorInicial['lat'], $conductorInicial['lng'], $conductorId]);
        
        echo "   ⏳ Aceptando en 2 segundos...\n";
        sleep(2);
        
        // Aceptar la solicitud
        try {
            $db->beginTransaction();
            
            // Verificar que sigue pendiente
            $stmt = $db->prepare("SELECT estado FROM solicitudes_servicio WHERE id = ? FOR UPDATE");
            $stmt->execute([$solicitudId]);
            $estado = $stmt->fetchColumn();
            
            if ($estado !== 'pendiente') {
                $db->rollBack();
                echo "   ⚠️ Solicitud ya no está pendiente (estado: $estado)\n\n";
                continue;
            }
            
            // Actualizar solicitud a aceptada
            $stmt = $db->prepare("UPDATE solicitudes_servicio SET estado = 'aceptada', aceptado_en = NOW() WHERE id = ?");
            $stmt->execute([$solicitudId]);
            
            // Crear asignación
            $stmt = $db->prepare("INSERT INTO asignaciones_conductor (solicitud_id, conductor_id, asignado_en, estado) VALUES (?, ?, NOW(), 'asignado')");
            $stmt->execute([$solicitudId, $conductorId]);
            
            // Marcar conductor como no disponible
            $stmt = $db->prepare("UPDATE detalles_conductor SET disponible = 0 WHERE usuario_id = ?");
            $stmt->execute([$conductorId]);
            
            $db->commit();
            
            echo "   ✅ ¡SOLICITUD ACEPTADA!\n";
            echo "   🚗 Iniciando simulación de movimiento hacia el cliente...\n";
            echo "──────────────────────────────────────────────────\n";
            
            // Iniciar simulación de movimiento
            $activeTripData = [
                'solicitud_id' => $solicitudId,
                'pickup_lat' => $pickupLat,
                'pickup_lng' => $pickupLng,
                'conductor_lat_inicial' => $conductorInicial['lat'],
                'conductor_lng_inicial' => $conductorInicial['lng'],
                'distancia_inicial' => $CONDUCTOR_DISTANCE_KM,
                'start_time' => time()
            ];
            $lastMoveTime = time();
            
        } catch (Exception $e) {
            if ($db->inTransaction()) $db->rollBack();
            echo "   ❌ Error aceptando: " . $e->getMessage() . "\n\n";
        }
    } else {
        // Mostrar indicador de que está escuchando
        $dots = str_repeat('.', ($iteration % 4) + 1);
        echo "\r" . "Escuchando" . $dots . "    ";
    }
    
    sleep(1);
}
