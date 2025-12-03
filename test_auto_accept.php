<?php
/**
 * Test: Monitor de solicitudes - Acepta automáticamente solicitudes del cliente
 * 
 * Este script escucha solicitudes pendientes del cliente braianoquendurango@gmail.com
 * y las acepta automáticamente con el conductor braianoquen2@gmail.com
 * 
 * Uso: php test_auto_accept.php
 * Para detener: Ctrl+C
 */
require_once 'backend/config/database.php';

$emailConductor = 'braianoquen2@gmail.com';
$emailCliente = 'braianoquendurango@gmail.com';

echo "==========================================================\n";
echo "🤖 AUTO-ACCEPT: Esperando solicitudes del cliente\n";
echo "==========================================================\n";
echo "👤 Cliente: $emailCliente\n";
echo "🚗 Conductor: $emailConductor\n";
echo "==========================================================\n\n";

$db = (new Database())->getConnection();

// 1) Obtener IDs
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

// 2) Marcar conductor como disponible
$stmt = $db->prepare("UPDATE detalles_conductor SET disponible = 1 WHERE usuario_id = ?");
$stmt->execute([$conductorId]);
echo "✅ Conductor marcado como disponible\n";

echo "\n⏳ Esperando solicitudes... (Ctrl+C para detener)\n";
echo "──────────────────────────────────────────────────\n\n";

$lastSolicitudId = 0;
$iteration = 0;

while (true) {
    $iteration++;
    
    // Buscar solicitudes pendientes del cliente
    $stmt = $db->prepare("
        SELECT id, uuid_solicitud, direccion_recogida, direccion_destino, estado, fecha_creacion
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
        
        echo "🆕 ¡Nueva solicitud detectada! (ID: $solicitudId)\n";
        echo "   📍 Origen: {$solicitud['direccion_recogida']}\n";
        echo "   📍 Destino: {$solicitud['direccion_destino']}\n";
        echo "   ⏰ Creada: {$solicitud['fecha_creacion']}\n";
        
        // Esperar 2 segundos para simular tiempo de respuesta real
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
            
            // Verificar conductor disponible
            $stmt = $db->prepare("SELECT disponible FROM detalles_conductor WHERE usuario_id = ?");
            $stmt->execute([$conductorId]);
            $disponible = $stmt->fetchColumn();
            
            if (!$disponible) {
                // Forzar disponibilidad para el test
                $stmt = $db->prepare("UPDATE detalles_conductor SET disponible = 1 WHERE usuario_id = ?");
                $stmt->execute([$conductorId]);
            }
            
            // Actualizar solicitud a aceptada
            $stmt = $db->prepare("UPDATE solicitudes_servicio SET estado = 'aceptada', aceptado_en = NOW() WHERE id = ?");
            $stmt->execute([$solicitudId]);
            
            // Crear asignación
            $stmt = $db->prepare("INSERT INTO asignaciones_conductor (solicitud_id, conductor_id, asignado_en, estado) VALUES (?, ?, NOW(), 'asignado')");
            $stmt->execute([$solicitudId, $conductorId]);
            
            // Marcar conductor como no disponible (tiene viaje activo)
            $stmt = $db->prepare("UPDATE detalles_conductor SET disponible = 0 WHERE usuario_id = ?");
            $stmt->execute([$conductorId]);
            
            $db->commit();
            
            echo "   ✅ ¡SOLICITUD ACEPTADA!\n";
            echo "   🚗 El cliente debería ver la pantalla de 'Conductor en camino'\n";
            echo "──────────────────────────────────────────────────\n\n";
            
            // Volver a marcar como disponible para la siguiente solicitud
            sleep(1);
            $stmt = $db->prepare("UPDATE detalles_conductor SET disponible = 1 WHERE usuario_id = ?");
            $stmt->execute([$conductorId]);
            
        } catch (Exception $e) {
            if ($db->inTransaction()) $db->rollBack();
            echo "   ❌ Error aceptando: " . $e->getMessage() . "\n\n";
        }
    } else {
        // Mostrar indicador de que está escuchando
        $dots = str_repeat('.', ($iteration % 4) + 1);
        echo "\r⏳ Escuchando$dots    ";
    }
    
    // Esperar 1 segundo antes de la siguiente verificación
    sleep(1);
}
