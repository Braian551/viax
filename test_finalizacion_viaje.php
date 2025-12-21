<?php
/**
 * Test: Flujo completo de finalización de viaje
 * 
 * Este script prueba:
 * 1. Completar un viaje
 * 2. Confirmar pago (si es efectivo)
 * 3. Calificar (conductor -> cliente y cliente -> conductor)
 */

require_once 'backend/config/database.php';

echo "═══════════════════════════════════════════════════════════════\n";
echo "   🎉 TEST: Flujo de finalización de viaje\n";
echo "═══════════════════════════════════════════════════════════════\n\n";

try {
    $database = new Database();
    $db = $database->getConnection();

    // ========================================
    // 1. Buscar un viaje completado o en curso
    // ========================================
    echo "📋 Paso 1: Buscando viaje en curso o completado...\n";
    
    $stmt = $db->prepare("
        SELECT 
            s.id as solicitud_id,
            s.cliente_id,
            s.estado,
            s.direccion_recogida,
            s.direccion_destino,
            s.distancia_estimada,
            s.tiempo_estimado,
            ac.conductor_id,
            u_cliente.nombre as cliente_nombre,
            u_conductor.nombre as conductor_nombre
        FROM solicitudes_servicio s
        INNER JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id
        INNER JOIN usuarios u_cliente ON s.cliente_id = u_cliente.id
        INNER JOIN usuarios u_conductor ON ac.conductor_id = u_conductor.id
        WHERE s.estado IN ('en_curso', 'completada')
        ORDER BY s.id DESC
        LIMIT 1
    ");
    $stmt->execute();
    $viaje = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$viaje) {
        echo "\n❌ No hay viajes en curso o completados.\n";
        echo "   Primero completa un viaje usando test_conductor_llego.php\n\n";
        exit(1);
    }

    $solicitudId = $viaje['solicitud_id'];
    $conductorId = $viaje['conductor_id'];
    $clienteId = $viaje['cliente_id'];
    
    // Calcular precio estimado basado en distancia (como en la app)
    $distancia = floatval($viaje['distancia_estimada']);
    $precioEstimado = 4500 + ($distancia * 1200); // Tarifa base + km

    echo "\n✅ Viaje encontrado:\n";
    echo "   📍 ID Solicitud: $solicitudId\n";
    echo "   👤 Cliente: {$viaje['cliente_nombre']} (ID: $clienteId)\n";
    echo "   🚗 Conductor: {$viaje['conductor_nombre']} (ID: $conductorId)\n";
    echo "   📍 Origen: {$viaje['direccion_recogida']}\n";
    echo "   📍 Destino: {$viaje['direccion_destino']}\n";
    echo "   📊 Estado: {$viaje['estado']}\n";
    echo "   📏 Distancia: " . number_format($distancia, 2) . " km\n";
    echo "   💰 Precio Est.: \$" . number_format($precioEstimado, 0) . "\n";
    echo "   💳 Método: Efectivo\n\n";

    // ========================================
    // 2. Si no está completado, completarlo
    // ========================================
    if ($viaje['estado'] !== 'completada') {
        echo "📋 Paso 2: Completando el viaje...\n";
        
        $stmt = $db->prepare("
            UPDATE solicitudes_servicio 
            SET estado = 'completada',
                completado_en = NOW()
            WHERE id = ?
        ");
        $stmt->execute([$solicitudId]);
        
        $stmt = $db->prepare("
            UPDATE detalles_conductor 
            SET disponible = 1,
                total_viajes = COALESCE(total_viajes, 0) + 1
            WHERE usuario_id = ?
        ");
        $stmt->execute([$conductorId]);
        
        echo "   ✅ Viaje marcado como completado\n\n";
    } else {
        echo "📋 Paso 2: El viaje ya está completado ✅\n\n";
    }

    // ========================================
    // 3. Simular confirmación de pago (solo log, tabla no tiene columna)
    // ========================================
    echo "📋 Paso 3: Confirmando pago en efectivo...\n";
    echo "   ✅ Pago confirmado (simulado)\n\n";

    // ========================================
    // 4. Verificar si ya hay calificaciones
    // ========================================
    echo "📋 Paso 4: Verificando calificaciones existentes...\n";
    
    $stmt = $db->prepare("
        SELECT usuario_calificador_id, usuario_calificado_id, calificacion, comentarios
        FROM calificaciones
        WHERE solicitud_id = ?
    ");
    $stmt->execute([$solicitudId]);
    $calificacionesExistentes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $clienteYaCalificó = false;
    $conductorYaCalificó = false;
    
    foreach ($calificacionesExistentes as $cal) {
        if ($cal['usuario_calificador_id'] == $clienteId) {
            $clienteYaCalificó = true;
            echo "   ✓ Cliente ya calificó: {$cal['calificacion']} ⭐\n";
        }
        if ($cal['usuario_calificador_id'] == $conductorId) {
            $conductorYaCalificó = true;
            echo "   ✓ Conductor ya calificó: {$cal['calificacion']} ⭐\n";
        }
    }
    
    if (empty($calificacionesExistentes)) {
        echo "   ℹ️ No hay calificaciones previas\n";
    }

    // ========================================
    // 5. Simular calificación del cliente al conductor
    // ========================================
    if (!$clienteYaCalificó) {
        echo "\n📋 Paso 5: Cliente califica al conductor...\n";
        
        $calificacionCliente = rand(4, 5); // Simulamos entre 4 y 5 estrellas
        
        $stmt = $db->prepare("
            INSERT INTO calificaciones (
                solicitud_id,
                usuario_calificador_id,
                usuario_calificado_id,
                calificacion,
                comentarios,
                creado_en
            ) VALUES (?, ?, ?, ?, 'Excelente servicio!', NOW())
        ");
        $stmt->execute([$solicitudId, $clienteId, $conductorId, $calificacionCliente]);
        
        // Actualizar promedio del conductor
        $stmt = $db->prepare("
            UPDATE detalles_conductor 
            SET calificacion_promedio = (
                SELECT AVG(c.calificacion)
                FROM calificaciones c
                WHERE c.usuario_calificado_id = ?
            ),
            total_calificaciones = (
                SELECT COUNT(*)
                FROM calificaciones c
                WHERE c.usuario_calificado_id = ?
            )
            WHERE usuario_id = ?
        ");
        $stmt->execute([$conductorId, $conductorId, $conductorId]);
        
        echo "   ✅ Cliente calificó con $calificacionCliente ⭐\n";
    } else {
        echo "\n📋 Paso 5: Cliente ya había calificado ✅\n";
    }

    // ========================================
    // 6. Simular calificación del conductor al cliente
    // ========================================
    if (!$conductorYaCalificó) {
        echo "\n📋 Paso 6: Conductor califica al cliente...\n";
        
        $calificacionConductor = rand(4, 5);
        
        $stmt = $db->prepare("
            INSERT INTO calificaciones (
                solicitud_id,
                usuario_calificador_id,
                usuario_calificado_id,
                calificacion,
                comentarios,
                creado_en
            ) VALUES (?, ?, ?, ?, 'Buen pasajero', NOW())
        ");
        $stmt->execute([$solicitudId, $conductorId, $clienteId, $calificacionConductor]);
        
        echo "   ✅ Conductor calificó con $calificacionConductor ⭐\n";
    } else {
        echo "\n📋 Paso 6: Conductor ya había calificado ✅\n";
    }

    // ========================================
    // 7. Mostrar resumen final
    // ========================================
    echo "\n═══════════════════════════════════════════════════════════════\n";
    echo "   📊 RESUMEN FINAL DEL VIAJE\n";
    echo "═══════════════════════════════════════════════════════════════\n\n";
    
    // Obtener datos actualizados
    $stmt = $db->prepare("
        SELECT 
            s.*,
            u_cliente.nombre as cliente_nombre,
            u_conductor.nombre as conductor_nombre,
            dc.calificacion_promedio as conductor_rating,
            COALESCE(dc.total_viajes, 0) as viajes_completados,
            COALESCE(dc.total_calificaciones, 0) as total_calificaciones
        FROM solicitudes_servicio s
        INNER JOIN usuarios u_cliente ON s.cliente_id = u_cliente.id
        INNER JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id
        INNER JOIN usuarios u_conductor ON ac.conductor_id = u_conductor.id
        LEFT JOIN detalles_conductor dc ON ac.conductor_id = dc.usuario_id
        WHERE s.id = ?
    ");
    $stmt->execute([$solicitudId]);
    $resumen = $stmt->fetch(PDO::FETCH_ASSOC);
    
    // Calcular rating del cliente desde calificaciones
    $stmt = $db->prepare("SELECT AVG(calificacion) as rating FROM calificaciones WHERE usuario_calificado_id = ?");
    $stmt->execute([$clienteId]);
    $clienteRating = $stmt->fetch(PDO::FETCH_ASSOC)['rating'] ?? 5.0;
    
    echo "   👤 Cliente: {$resumen['cliente_nombre']}\n";
    echo "      ⭐ Rating: " . number_format($clienteRating, 1) . "\n\n";
    
    echo "   🚗 Conductor: {$resumen['conductor_nombre']}\n";
    echo "      ⭐ Rating: " . number_format($resumen['conductor_rating'] ?? 5.0, 1) . "\n";
    echo "      🏆 Viajes: {$resumen['viajes_completados']}\n";
    echo "      📝 Calificaciones: {$resumen['total_calificaciones']}\n\n";
    
    echo "   💰 Pago:\n";
    echo "      Monto: \$" . number_format($precioEstimado, 0) . "\n";
    echo "      Confirmado: Sí ✅\n\n";
    
    // Mostrar todas las calificaciones
    $stmt = $db->prepare("
        SELECT c.*, 
               uc.nombre as nombre_calificador,
               ur.nombre as nombre_calificado
        FROM calificaciones c
        JOIN usuarios uc ON c.usuario_calificador_id = uc.id
        JOIN usuarios ur ON c.usuario_calificado_id = ur.id
        WHERE c.solicitud_id = ?
    ");
    $stmt->execute([$solicitudId]);
    $todasCalificaciones = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "   📝 Calificaciones del viaje:\n";
    foreach ($todasCalificaciones as $cal) {
        echo "      • {$cal['nombre_calificador']} → {$cal['nombre_calificado']}: {$cal['calificacion']} ⭐";
        if ($cal['comentarios']) {
            echo " - \"{$cal['comentarios']}\"";
        }
        echo "\n";
    }

    echo "\n═══════════════════════════════════════════════════════════════\n";
    echo "   ✅ TEST COMPLETADO EXITOSAMENTE\n";
    echo "═══════════════════════════════════════════════════════════════\n\n";

} catch (Exception $e) {
    echo "\n❌ ERROR: " . $e->getMessage() . "\n";
    echo "   Línea: " . $e->getLine() . "\n\n";
    exit(1);
}
