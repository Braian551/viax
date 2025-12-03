<?php
/**
 * Script de prueba para crear una solicitud usando usuarios existentes
 * Este script NO crea usuarios nuevos, usa los que ya están en la BD
 */

require_once 'backend/config/database.php';

echo "==========================================================\n";
echo "🧪 TEST: CREAR SOLICITUD CON USUARIOS EXISTENTES\n";
echo "==========================================================\n\n";

$database = new Database();
$db = $database->getConnection();

try {
    // ==========================================
    // PASO 1: Buscar un conductor disponible
    // ==========================================
    echo "📝 PASO 1: Buscando conductor disponible...\n";
    
    $stmt = $db->prepare("
        SELECT u.id, u.nombre, u.apellido, u.email, 
               dc.latitud_actual, dc.longitud_actual, dc.disponible
        FROM usuarios u
        INNER JOIN detalles_conductor dc ON u.id = dc.usuario_id
        WHERE u.tipo_usuario = 'conductor'
        AND dc.estado_verificacion = 'aprobado'
        AND dc.disponible = 1
        LIMIT 1
    ");
    $stmt->execute();
    $conductor = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$conductor) {
        echo "   ❌ No se encontró ningún conductor disponible\n";
        echo "   💡 Buscando cualquier conductor aprobado...\n";
        
        $stmt = $db->prepare("
            SELECT u.id, u.nombre, u.apellido, u.email,
                   dc.latitud_actual, dc.longitud_actual, dc.disponible
            FROM usuarios u
            INNER JOIN detalles_conductor dc ON u.id = dc.usuario_id
            WHERE u.tipo_usuario = 'conductor'
            AND dc.estado_verificacion = 'aprobado'
            LIMIT 1
        ");
        $stmt->execute();
        $conductor = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$conductor) {
            die("   ❌ ERROR: No hay conductores aprobados en la BD\n");
        }
        
        // Marcar como disponible
        $stmt = $db->prepare("UPDATE detalles_conductor SET disponible = 1 WHERE usuario_id = ?");
        $stmt->execute([$conductor['id']]);
        echo "   ✅ Conductor marcado como disponible\n";
    }
    
    echo "   ✅ Conductor encontrado:\n";
    echo "      👤 {$conductor['nombre']} {$conductor['apellido']}\n";
    echo "      📧 {$conductor['email']}\n";
    echo "      🆔 ID: {$conductor['id']}\n";
    echo "      📍 Ubicación: Lat {$conductor['latitud_actual']}, Lng {$conductor['longitud_actual']}\n";
    echo "      🟢 Disponible: " . ($conductor['disponible'] ? 'Sí' : 'No') . "\n";
    
    // ==========================================
    // PASO 2: Buscar un cliente (usuario tipo cliente)
    // ==========================================
    echo "\n📝 PASO 2: Buscando cliente...\n";
    
    $stmt = $db->prepare("
        SELECT id, nombre, apellido, email, telefono
        FROM usuarios
        WHERE tipo_usuario = 'cliente'
        AND es_activo = 1
        LIMIT 1
    ");
    $stmt->execute();
    $cliente = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$cliente) {
        die("   ❌ ERROR: No hay clientes en la BD\n");
    }
    
    echo "   ✅ Cliente encontrado:\n";
    echo "      👤 {$cliente['nombre']} {$cliente['apellido']}\n";
    echo "      📧 {$cliente['email']}\n";
    echo "      🆔 ID: {$cliente['id']}\n";
    echo "      📞 {$cliente['telefono']}\n";
    
    // ==========================================
    // PASO 3: Limpiar solicitudes antiguas
    // ==========================================
    echo "\n📝 PASO 3: Limpiando solicitudes antiguas...\n";
    
    $stmt = $db->prepare("
        DELETE FROM solicitudes_servicio 
        WHERE estado IN ('pendiente', 'en_busqueda')
        AND fecha_creacion < NOW() - INTERVAL '30 minutes'
    ");
    $stmt->execute();
    $eliminadas = $stmt->rowCount();
    echo "   ✅ Eliminadas $eliminadas solicitudes antiguas\n";
    
    // ==========================================
    // PASO 4: Crear solicitud de prueba
    // ==========================================
    echo "\n📝 PASO 4: Creando solicitud de prueba...\n";
    
    // Generar UUID
    $uuid = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000,
        mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
    );
    
    // Usar la ubicación del conductor como referencia
    // Crear origen DENTRO del radio de búsqueda (5km)
    $latitudOrigen = $conductor['latitud_actual'] + 0.025; // ~2.5 km hacia el norte
    $longitudOrigen = $conductor['longitud_actual'] + 0.020; // ~2 km hacia el este
    
    // Destino a una distancia razonable del origen
    $latitudDestino = $latitudOrigen + 0.035; // ~3.5 km más hacia el norte
    $longitudDestino = $longitudOrigen + 0.030; // ~3 km más hacia el este
    
    $stmt = $db->prepare("
        INSERT INTO solicitudes_servicio (
            uuid_solicitud,
            cliente_id,
            tipo_servicio,
            latitud_recogida,
            longitud_recogida,
            direccion_recogida,
            latitud_destino,
            longitud_destino,
            direccion_destino,
            distancia_estimada,
            tiempo_estimado,
            estado,
            fecha_creacion,
            solicitado_en
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ");
    
    $stmt->execute([
        $uuid,
        $cliente['id'],
        'transporte',
        $latitudOrigen,
        $longitudOrigen,
        'Punto de Recogida - Prueba (dentro de 5km)',
        $latitudDestino,
        $longitudDestino,
        'Punto de Destino - Prueba',
        7.0, // km (distancia total razonable)
        20,  // minutos (tiempo estimado)
        'pendiente'
    ]);
    
    $solicitudId = $db->lastInsertId();
    
    echo "   ✅ ¡Solicitud creada exitosamente!\n\n";
    echo "   ╔════════════════════════════════════════════╗\n";
    echo "   ║      DETALLES DE LA SOLICITUD             ║\n";
    echo "   ╠════════════════════════════════════════════╣\n";
    echo "   ║ 🆔 ID:          $solicitudId                      ║\n";
    echo "   ║ 🔑 UUID:        " . substr($uuid, 0, 18) . "...║\n";
    echo "   ║ 👤 Cliente:     {$cliente['nombre']} {$cliente['apellido']}\n";
    echo "   ║ 📞 Teléfono:    {$cliente['telefono']}     ║\n";
    echo "   ║ 🚗 Conductor:   {$conductor['nombre']} (dentro radio)\n";
    echo "   ║                                            ║\n";
    echo "   ║ 📍 ORIGEN:                                 ║\n";
    echo "   ║    Lat: " . number_format($latitudOrigen, 4) . "                    ║\n";
    echo "   ║    Lng: " . number_format($longitudOrigen, 4) . "                   ║\n";
    echo "   ║                                            ║\n";
    echo "   ║ 📍 DESTINO:                                ║\n";
    echo "   ║    Lat: " . number_format($latitudDestino, 4) . "                    ║\n";
    echo "   ║    Lng: " . number_format($longitudDestino, 4) . "                   ║\n";
    echo "   ║                                            ║\n";
    echo "   ║ 📏 Distancia: 7.0 km                       ║\n";
    echo "   ║ ⏱️  Tiempo:    20 min                       ║\n";
    echo "   ║ ✅ Estado:    PENDIENTE                    ║\n";
    echo "   ╚════════════════════════════════════════════╝\n";
    
    // ==========================================
    // PASO 5: Verificar que el conductor pueda verla
    // ==========================================
    echo "\n📝 PASO 5: Verificando si el conductor puede ver la solicitud...\n";
    
    $radioKm = 5.0;
    
    $stmt = $db->prepare("
        SELECT 
            s.id,
            s.uuid_solicitud,
            s.cliente_id,
            s.direccion_recogida,
            s.direccion_destino,
            s.distancia_estimada,
            u.nombre as nombre_cliente,
            u.telefono,
            (6371 * acos(
                cos(radians(?)) * cos(radians(s.latitud_recogida)) *
                cos(radians(s.longitud_recogida) - radians(?)) +
                sin(radians(?)) * sin(radians(s.latitud_recogida))
            )) AS distancia_conductor_origen
        FROM solicitudes_servicio s
        INNER JOIN usuarios u ON s.cliente_id = u.id
        WHERE s.estado = 'pendiente'
        AND s.tipo_servicio = 'transporte'
        AND s.id = ?
        AND (6371 * acos(
                cos(radians(?)) * cos(radians(s.latitud_recogida)) *
                cos(radians(s.longitud_recogida) - radians(?)) +
                sin(radians(?)) * sin(radians(s.latitud_recogida))
            )) <= ?
    ");
    
    $stmt->execute([
        $conductor['latitud_actual'], // lat for SELECT expr
        $conductor['longitud_actual'], // lon for SELECT expr
        $conductor['latitud_actual'], // lat for SELECT expr (sin)
        $solicitudId,
        $conductor['latitud_actual'], // lat for WHERE distance
        $conductor['longitud_actual'], // lon for WHERE distance
        $conductor['latitud_actual'], // lat for WHERE distance (sin)
        $radioKm
    ]);
    
    $resultado = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($resultado) {
        echo "   ✅ ¡El conductor PUEDE ver la solicitud!\n";
        echo "   📊 Distancia conductor → origen: " . round($resultado['distancia_conductor_origen'], 2) . " km\n";
        echo "   📏 Radio de búsqueda: $radioKm km\n";
    } else {
        echo "   ⚠️  El conductor NO puede ver la solicitud\n";
        echo "   💡 Puede estar fuera del radio de búsqueda\n";
        
        // Calcular distancia real
        $stmt = $db->prepare("
            SELECT 
                (6371 * acos(
                    cos(radians(?)) * cos(radians(?)) *
                    cos(radians(?) - radians(?)) +
                    sin(radians(?)) * sin(radians(?))
                )) AS distancia
        ");
        $stmt->execute([
            $conductor['latitud_actual'],
            $latitudOrigen,
            $longitudOrigen,
            $conductor['longitud_actual'],
            $conductor['latitud_actual'],
            $latitudOrigen
        ]);
        $dist = $stmt->fetch(PDO::FETCH_ASSOC);
        echo "   📊 Distancia real: " . round($dist['distancia'], 2) . " km\n";
    }
    
    // ==========================================
    // RESUMEN FINAL
    // ==========================================
    echo "\n==========================================================\n";
    echo "✅ TEST COMPLETADO EXITOSAMENTE\n";
    echo "==========================================================\n";
    echo "📊 RESUMEN:\n";
    echo "   🆔 Solicitud ID: $solicitudId\n";
    echo "   👤 Cliente ID: {$cliente['id']} ({$cliente['nombre']})\n";
    echo "   🚗 Conductor ID: {$conductor['id']} ({$conductor['nombre']})\n";
    echo "   📍 Radio búsqueda: $radioKm km\n";
    echo "\n💡 NOTA: La app del conductor debería recibir esta solicitud\n";
    echo "   si está en modo búsqueda y dentro del radio configurado.\n";
    echo "==========================================================\n";
    
} catch (Exception $e) {
    echo "\n❌ ERROR: " . $e->getMessage() . "\n";
    echo "📍 En: " . $e->getFile() . " línea " . $e->getLine() . "\n";
    echo "\n🔍 Stack trace:\n";
    echo $e->getTraceAsString() . "\n";
}
