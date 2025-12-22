<?php
/**
 * Test: Cliente confirma que SÍ pagó el efectivo
 * 
 * Uso: php test_cliente_confirma_pago.php [solicitud_id] [usuario_id]
 */

require_once __DIR__ . '/backend/config/database.php';

$solicitudId = $argv[1] ?? null;
$usuarioId = $argv[2] ?? null;

if (!$solicitudId || !$usuarioId) {
    echo "❌ Uso: php test_cliente_confirma_pago.php [solicitud_id] [usuario_id]\n";
    echo "Ejemplo: php test_cliente_confirma_pago.php 123 456\n";
    exit(1);
}

echo "🧪 Test: Cliente confirma pago\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "📍 Solicitud ID: $solicitudId\n";
echo "👤 Usuario ID: $usuarioId\n";
echo "✅ Cliente dice: SÍ PAGUÉ\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

try {
    $db = (new Database())->getConnection();
    $db->beginTransaction();
    
    // Verificar que la solicitud existe
    $stmt = $db->prepare("SELECT cliente_id, cliente_confirma_pago, conductor_confirma_recibo FROM solicitudes_servicio WHERE id = ?");
    $stmt->execute([$solicitudId]);
    $solicitud = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$solicitud) {
        throw new Exception("Solicitud no encontrada");
    }
    
    if ($solicitud['cliente_id'] != $usuarioId) {
        throw new Exception("El usuario no es el cliente de esta solicitud");
    }
    
    // Actualizar confirmación del cliente
    $stmt = $db->prepare("UPDATE solicitudes_servicio SET cliente_confirma_pago = TRUE WHERE id = ?");
    $stmt->execute([$solicitudId]);
    
    echo "✅ Cliente confirmó que SÍ pagó\n";
    
    // Verificar si hay conflicto (disputa)
    $conductorConfirma = $solicitud['conductor_confirma_recibo'];
    
    if ($conductorConfirma === false) {
        echo "\n⚠️  CONFLICTO DETECTADO:\n";
        echo "   • Cliente dice: SÍ pagué\n";
        echo "   • Conductor dice: NO recibí\n\n";
        echo "🔥 CREANDO DISPUTA...\n";
        
        // Obtener conductor_id
        $stmt = $db->prepare("SELECT conductor_id FROM asignaciones_conductor WHERE solicitud_id = ?");
        $stmt->execute([$solicitudId]);
        $conductorId = $stmt->fetchColumn();
        
        // Crear disputa
        $stmt = $db->prepare("
            INSERT INTO disputas_pago (solicitud_id, cliente_id, conductor_id, cliente_confirma_pago, conductor_confirma_recibo, estado, creado_en)
            VALUES (?, ?, ?, TRUE, FALSE, 'pendiente', NOW())
            RETURNING id
        ");
        $stmt->execute([$solicitudId, $usuarioId, $conductorId]);
        $disputaId = $stmt->fetchColumn();
        
        // Actualizar solicitud
        $stmt = $db->prepare("UPDATE solicitudes_servicio SET tiene_disputa = TRUE, disputa_id = ? WHERE id = ?");
        $stmt->execute([$disputaId, $solicitudId]);
        
        // Suspender ambas cuentas
        $stmt = $db->prepare("UPDATE usuarios SET tiene_disputa_activa = TRUE, disputa_activa_id = ? WHERE id IN (?, ?)");
        $stmt->execute([$disputaId, $usuarioId, $conductorId]);
        
        echo "🔒 Ambas cuentas SUSPENDIDAS\n";
        echo "📋 Disputa ID: $disputaId\n";
        
    } else if ($conductorConfirma === true) {
        echo "✓ Conductor también confirmó recibir el pago\n";
        echo "✅ Viaje completado sin disputas\n";
    } else {
        echo "⏳ Esperando confirmación del conductor\n";
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
