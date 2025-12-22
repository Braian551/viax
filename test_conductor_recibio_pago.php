<?php
/**
 * Test: Conductor confirma que SÍ recibió el pago
 * 
 * Uso: php test_conductor_recibio_pago.php [solicitud_id] [usuario_id]
 */

require_once __DIR__ . '/backend/config/database.php';

$solicitudId = $argv[1] ?? null;
$usuarioId = $argv[2] ?? null;

if (!$solicitudId || !$usuarioId) {
    echo "❌ Uso: php test_conductor_recibio_pago.php [solicitud_id] [usuario_id]\n";
    echo "Ejemplo: php test_conductor_recibio_pago.php 123 789\n";
    exit(1);
}

echo "🧪 Test: Conductor confirma pago recibido\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "📍 Solicitud ID: $solicitudId\n";
echo "👤 Usuario ID (conductor): $usuarioId\n";
echo "✅ Conductor dice: SÍ RECIBÍ EL PAGO\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

try {
    $db = (new Database())->getConnection();
    $db->beginTransaction();
    
    // Verificar que el conductor está asignado a esta solicitud
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
    $stmt = $db->prepare("UPDATE solicitudes_servicio SET conductor_confirma_recibo = TRUE WHERE id = ?");
    $stmt->execute([$solicitudId]);
    
    echo "✅ Conductor confirmó que SÍ recibió el pago\n";
    
    // Verificar estado del cliente
    $clienteConfirma = $solicitud['cliente_confirma_pago'];
    
    if ($clienteConfirma === true) {
        echo "✓ Cliente también confirmó haber pagado\n";
        echo "✅ Viaje completado exitosamente sin disputas\n";
    } else if ($clienteConfirma === false) {
        echo "⚠️  Cliente reportó que NO pagó\n";
        echo "✓ Ambos de acuerdo en que no hubo pago (sin disputa)\n";
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
