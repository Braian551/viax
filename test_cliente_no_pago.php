<?php
/**
 * Test: Cliente confirma que NO pagó el efectivo
 * 
 * Uso: php test_cliente_no_pago.php [solicitud_id] [usuario_id]
 */

require_once __DIR__ . '/backend/config/database.php';

$solicitudId = $argv[1] ?? null;
$usuarioId = $argv[2] ?? null;

if (!$solicitudId || !$usuarioId) {
    echo "❌ Uso: php test_cliente_no_pago.php [solicitud_id] [usuario_id]\n";
    echo "Ejemplo: php test_cliente_no_pago.php 123 456\n";
    exit(1);
}

echo "🧪 Test: Cliente NO pagó\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "📍 Solicitud ID: $solicitudId\n";
echo "👤 Usuario ID: $usuarioId\n";
echo "❌ Cliente dice: NO PAGUÉ\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

try {
    $db = (new Database())->getConnection();
    $db->beginTransaction();
    
    // Verificar que la solicitud existe
    $stmt = $db->prepare("SELECT cliente_id FROM solicitudes_servicio WHERE id = ?");
    $stmt->execute([$solicitudId]);
    $clienteId = $stmt->fetchColumn();
    
    if (!$clienteId || $clienteId != $usuarioId) {
        throw new Exception("El usuario no es el cliente de esta solicitud");
    }
    
    // Actualizar confirmación del cliente
    $stmt = $db->prepare("UPDATE solicitudes_servicio SET cliente_confirma_pago = FALSE WHERE id = ?");
    $stmt->execute([$solicitudId]);
    
    echo "✅ Cliente confirmó que NO pagó\n";
    echo "✓ Viaje completado normalmente (sin disputa)\n";
    
    $db->commit();
    echo "\n✅ Proceso completado\n";
    
} catch (Exception $e) {
    if (isset($db) && $db->inTransaction()) {
        $db->rollBack();
    }
    echo "❌ Error: " . $e->getMessage() . "\n";
    exit(1);
}
