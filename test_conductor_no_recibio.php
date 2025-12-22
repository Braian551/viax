<?php
/**
 * Test: Conductor reporta que NO recibió el pago
 * 
 * Uso: php test_conductor_no_recibio.php [solicitud_id] [usuario_id]
 */

require_once __DIR__ . '/backend/config/database.php';

$solicitudId = $argv[1] ?? null;
$usuarioId = $argv[2] ?? null;

if (!$solicitudId || !$usuarioId) {
    echo "❌ Uso: php test_conductor_no_recibio.php [solicitud_id] [usuario_id]\n";
    echo "Ejemplo: php test_conductor_no_recibio.php 123 789\n";
    exit(1);
}

echo "🧪 Test: Conductor NO recibió el pago\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "📍 Solicitud ID: $solicitudId\n";
echo "👤 Usuario ID (conductor): $usuarioId\n";
echo "❌ Conductor dice: NO RECIBÍ EL PAGO\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

try {
    $db = (new Database())->getConnection();
    $db->beginTransaction();
    
    // Verificar que el conductor está asignado
    $stmt = $db->prepare("SELECT conductor_id FROM asignaciones_conductor WHERE solicitud_id = ?");
    $stmt->execute([$solicitudId]);
    $conductorId = $stmt->fetchColumn();
    
    if (!$conductorId || $conductorId != $usuarioId) {
        throw new Exception("El usuario no es el conductor de esta solicitud");
    }
    
    // Obtener estado actual
    $stmt = $db->prepare("SELECT cliente_confirma_pago, conductor_confirma_recibo, cliente_id FROM solicitudes_servicio WHERE id = ?");
    $stmt->execute([$solicitudId]);
    $solicitud = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$solicitud) {
        throw new Exception("Solicitud no encontrada");
    }
    
    // Actualizar confirmación del conductor
    $stmt = $db->prepare("UPDATE solicitudes_servicio SET conductor_confirma_recibo = FALSE WHERE id = ?");
    $stmt->execute([$solicitudId]);
    
    echo "⚠️  Conductor reportó que NO recibió el pago\n";
    
    // Verificar si hay conflicto (disputa)
    $clienteConfirma = $solicitud['cliente_confirma_pago'];
    
    if ($clienteConfirma === true) {
        echo "\n🔥 CONFLICTO DETECTADO:\n";
        echo "   • Cliente dice: SÍ pagué\n";
        echo "   • Conductor dice: NO recibí\n\n";
        echo "🔒 CREANDO DISPUTA...\n";
        
        // Crear disputa
        $stmt = $db->prepare("
            INSERT INTO disputas_pago (solicitud_id, cliente_id, conductor_id, cliente_confirma_pago, conductor_confirma_recibo, estado, creado_en)
            VALUES (?, ?, ?, TRUE, FALSE, 'pendiente', NOW())
            RETURNING id
        ");
        $stmt->execute([$solicitudId, $solicitud['cliente_id'], $usuarioId]);
        $disputaId = $stmt->fetchColumn();
        
        // Actualizar solicitud
        $stmt = $db->prepare("UPDATE solicitudes_servicio SET tiene_disputa = TRUE, disputa_id = ? WHERE id = ?");
        $stmt->execute([$disputaId, $solicitudId]);
        
        // Suspender ambas cuentas
        $stmt = $db->prepare("UPDATE usuarios SET tiene_disputa_activa = TRUE, disputa_activa_id = ? WHERE id IN (?, ?)");
        $stmt->execute([$disputaId, $solicitud['cliente_id'], $usuarioId]);
        
        echo "🔒 Ambas cuentas SUSPENDIDAS\n";
        echo "📋 Disputa ID: $disputaId\n";
        
    } else if ($clienteConfirma === false) {
        echo "✓ Cliente también confirmó que NO pagó\n";
        echo "✅ Ambos de acuerdo (sin disputa)\n";
    } else {
        echo "⏳ Esperando confirmación del cliente\n";
    }
    
    $db->commit();
    echo "\n✅ Proceso completado\n";
    
} catch (Exception $e) {
    if (isset($db) && $db->inTransaction()) {
        $db->rollBack();
    }
    echo "❌ Error: " . $e->getMessage() . "\n";
    exit(1);
}
