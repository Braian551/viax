<?php
/**
 * Test: Conductor llega al punto de encuentro
 * 
 * Este script simula el flujo completo cuando el conductor
 * marca que llegó al punto de recogida.
 * 
 * Estados del viaje:
 * - pendiente: Esperando conductor
 * - aceptada/conductor_asignado: Conductor en camino
 * - conductor_llego: Conductor en el punto de encuentro
 * - en_curso: Viaje iniciado (cliente recogido)
 * - completada: Viaje finalizado
 */

require_once 'backend/config/database.php';

echo "═══════════════════════════════════════════════════════════════\n";
echo "   🚗 TEST: Conductor llega al punto de encuentro\n";
echo "═══════════════════════════════════════════════════════════════\n\n";

try {
    $database = new Database();
    $db = $database->getConnection();

    // ========================================
    // 1. Buscar una solicitud activa con conductor asignado
    // ========================================
    echo "📋 Paso 1: Buscando solicitud con conductor asignado...\n";
    
    $stmt = $db->prepare("
        SELECT 
            s.id as solicitud_id,
            s.cliente_id,
            s.estado,
            s.direccion_recogida,
            s.direccion_destino,
            s.latitud_recogida,
            s.longitud_recogida,
            s.latitud_destino,
            s.longitud_destino,
            ac.conductor_id,
            u_cliente.nombre as cliente_nombre,
            u_conductor.nombre as conductor_nombre,
            dc.latitud_actual as conductor_lat,
            dc.longitud_actual as conductor_lng
        FROM solicitudes_servicio s
        INNER JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id
        INNER JOIN usuarios u_cliente ON s.cliente_id = u_cliente.id
        INNER JOIN usuarios u_conductor ON ac.conductor_id = u_conductor.id
        LEFT JOIN detalles_conductor dc ON ac.conductor_id = dc.usuario_id
        WHERE s.estado IN ('aceptada', 'conductor_asignado')
        AND ac.estado = 'asignado'
        ORDER BY s.id DESC
        LIMIT 1
    ");
    $stmt->execute();
    $solicitud = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$solicitud) {
        echo "\n❌ No hay solicitudes con conductor asignado.\n";
        echo "   Primero ejecuta: php test_auto_accept.php\n\n";
        exit(1);
    }

    $solicitudId = $solicitud['solicitud_id'];
    $conductorId = $solicitud['conductor_id'];
    $clienteId = $solicitud['cliente_id'];

    echo "\n✅ Solicitud encontrada:\n";
    echo "   📍 ID Solicitud: $solicitudId\n";
    echo "   👤 Cliente: {$solicitud['cliente_nombre']} (ID: $clienteId)\n";
    echo "   🚗 Conductor: {$solicitud['conductor_nombre']} (ID: $conductorId)\n";
    echo "   📍 Origen: {$solicitud['direccion_recogida']}\n";
    echo "   📍 Destino: {$solicitud['direccion_destino']}\n";
    echo "   📊 Estado actual: {$solicitud['estado']}\n\n";

    // ========================================
    // 2. Simular llegada al punto de encuentro
    // ========================================
    echo "📋 Paso 2: Actualizando posición del conductor al punto de recogida...\n";

    // Mover conductor al punto de recogida
    $stmt = $db->prepare("
        UPDATE detalles_conductor 
        SET latitud_actual = ?,
            longitud_actual = ?
        WHERE usuario_id = ?
    ");
    $stmt->execute([
        $solicitud['latitud_recogida'],
        $solicitud['longitud_recogida'],
        $conductorId
    ]);

    echo "   ✅ Conductor movido a: {$solicitud['latitud_recogida']}, {$solicitud['longitud_recogida']}\n\n";

    // ========================================
    // 3. Marcar que el conductor llegó
    // ========================================
    echo "📋 Paso 3: Marcando 'conductor_llego' en la solicitud...\n";

    $stmt = $db->prepare("
        UPDATE solicitudes_servicio 
        SET estado = 'conductor_llego'
        WHERE id = ?
    ");
    $stmt->execute([$solicitudId]);

    // También actualizar la asignación
    $stmt = $db->prepare("
        UPDATE asignaciones_conductor 
        SET estado = 'llegado'
        WHERE solicitud_id = ? AND conductor_id = ?
    ");
    $stmt->execute([$solicitudId, $conductorId]);

    echo "   ✅ Estado actualizado a 'conductor_llego'\n\n";

    // ========================================
    // 4. Verificar el estado actualizado
    // ========================================
    echo "📋 Paso 4: Verificando estado actualizado...\n";

    $stmt = $db->prepare("
        SELECT 
            s.id,
            s.estado,
            ac.estado as estado_asignacion
        FROM solicitudes_servicio s
        LEFT JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id
        WHERE s.id = ?
    ");
    $stmt->execute([$solicitudId]);
    $verificacion = $stmt->fetch(PDO::FETCH_ASSOC);

    echo "\n   📊 Estado de la solicitud: {$verificacion['estado']}\n";
    echo "   📊 Estado de asignación: {$verificacion['estado_asignacion']}\n\n";

    // ========================================
    // 5. Simular lo que el cliente vería
    // ========================================
    echo "═══════════════════════════════════════════════════════════════\n";
    echo "   📱 SIMULACIÓN: Lo que vería el cliente\n";
    echo "═══════════════════════════════════════════════════════════════\n\n";

    // Simular la respuesta del endpoint get_trip_status.php
    $stmt = $db->prepare("
        SELECT 
            s.id,
            s.estado,
            s.latitud_recogida,
            s.longitud_recogida,
            s.direccion_recogida,
            s.latitud_destino,
            s.longitud_destino,
            s.direccion_destino,
            u.id as conductor_id,
            u.nombre as conductor_nombre,
            u.telefono as conductor_telefono,
            dc.vehiculo_marca,
            dc.vehiculo_modelo,
            dc.vehiculo_placa,
            dc.vehiculo_color,
            dc.calificacion_promedio,
            dc.latitud_actual as conductor_lat,
            dc.longitud_actual as conductor_lng
        FROM solicitudes_servicio s
        INNER JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id
        INNER JOIN usuarios u ON ac.conductor_id = u.id
        LEFT JOIN detalles_conductor dc ON u.id = dc.usuario_id
        WHERE s.id = ?
    ");
    $stmt->execute([$solicitudId]);
    $tripStatus = $stmt->fetch(PDO::FETCH_ASSOC);

    echo "   🔔 NOTIFICACIÓN: ¡Tu conductor ha llegado!\n\n";
    echo "   👤 Conductor: {$tripStatus['conductor_nombre']}\n";
    echo "   📞 Teléfono: {$tripStatus['conductor_telefono']}\n";
    echo "   🚗 Vehículo: {$tripStatus['vehiculo_marca']} {$tripStatus['vehiculo_modelo']}\n";
    echo "   📋 Placa: {$tripStatus['vehiculo_placa']}\n";
    echo "   🎨 Color: {$tripStatus['vehiculo_color']}\n";
    echo "   ⭐ Calificación: " . number_format($tripStatus['calificacion_promedio'] ?? 0, 1) . "\n\n";
    
    echo "   📍 El conductor te espera en:\n";
    echo "   {$tripStatus['direccion_recogida']}\n\n";

    // ========================================
    // 6. Opciones para continuar
    // ========================================
    echo "═══════════════════════════════════════════════════════════════\n";
    echo "   ¿Qué deseas hacer ahora?\n";
    echo "═══════════════════════════════════════════════════════════════\n\n";
    echo "   1. Iniciar viaje (cliente se subió al vehículo)\n";
    echo "   2. Salir sin cambios\n\n";
    echo "   Selecciona (1-2): ";
    
    $handle = fopen("php://stdin", "r");
    $line = trim(fgets($handle));
    fclose($handle);

    if ($line === '1') {
        echo "\n📋 Iniciando viaje (cliente recogido)...\n";
        
        $stmt = $db->prepare("
            UPDATE solicitudes_servicio 
            SET estado = 'en_curso',
                recogido_en = NOW()
            WHERE id = ?
        ");
        $stmt->execute([$solicitudId]);
        
        // Actualizar también asignación
        $stmt = $db->prepare("
            UPDATE asignaciones_conductor 
            SET estado = 'en_curso'
            WHERE solicitud_id = ? AND conductor_id = ?
        ");
        $stmt->execute([$solicitudId, $conductorId]);

        echo "\n   ✅ ¡Viaje iniciado! Estado: 'en_curso'\n";
        echo "   📱 El cliente ahora verá la pantalla de viaje activo\n";
        echo "   🗺️  El mapa mostrará la ruta hacia el destino\n\n";
        
        // Mostrar estado final
        $stmt = $db->prepare("SELECT estado, recogido_en FROM solicitudes_servicio WHERE id = ?");
        $stmt->execute([$solicitudId]);
        $final = $stmt->fetch(PDO::FETCH_ASSOC);
        
        echo "   📊 Estado final: {$final['estado']}\n";
        echo "   ⏰ Recogido en: {$final['recogido_en']}\n";
        
        // Opción de completar el viaje
        echo "\n   ¿Simular llegada al destino? (s/n): ";
        $handle2 = fopen("php://stdin", "r");
        $line2 = trim(fgets($handle2));
        fclose($handle2);
        
        if (strtolower($line2) === 's') {
            echo "\n📋 Completando viaje...\n";
            
            $stmt = $db->prepare("
                UPDATE solicitudes_servicio 
                SET estado = 'completada',
                    completado_en = NOW()
                WHERE id = ?
            ");
            $stmt->execute([$solicitudId]);
            
            // Liberar conductor
            $stmt = $db->prepare("
                UPDATE detalles_conductor 
                SET disponible = 1,
                    viajes_completados = viajes_completados + 1
                WHERE usuario_id = ?
            ");
            $stmt->execute([$conductorId]);
            
            echo "\n   ✅ ¡Viaje completado exitosamente!\n";
            echo "   🎉 El cliente verá la pantalla de calificación\n";
        }
    } else {
        echo "\n   ℹ️ Sin cambios adicionales.\n";
    }

    echo "\n═══════════════════════════════════════════════════════════════\n";
    echo "   ✅ TEST COMPLETADO\n";
    echo "═══════════════════════════════════════════════════════════════\n\n";

} catch (Exception $e) {
    echo "\n❌ ERROR: " . $e->getMessage() . "\n";
    echo "   Línea: " . $e->getLine() . "\n\n";
    exit(1);
}
