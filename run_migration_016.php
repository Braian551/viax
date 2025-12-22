<?php
/**
 * Script para ejecutar la migración del sistema de disputas
 */

require_once 'backend/config/database.php';

echo "═══════════════════════════════════════════════════════════════\n";
echo "   🔄 Ejecutando migración: Sistema de Disputas de Pago\n";
echo "═══════════════════════════════════════════════════════════════\n\n";

try {
    $db = (new Database())->getConnection();
    
    // Leer archivo SQL
    $sql = file_get_contents('backend/migrations/016_payment_dispute_system.sql');
    
    // Ejecutar migración
    $db->exec($sql);
    
    echo "✅ Migración ejecutada correctamente\n\n";
    
    // Verificar que las tablas se crearon
    $stmt = $db->query("SELECT table_name FROM information_schema.tables WHERE table_name = 'disputas_pago'");
    if ($stmt->fetch()) {
        echo "✅ Tabla 'disputas_pago' creada\n";
    }
    
    // Verificar columnas en solicitudes_servicio
    $stmt = $db->query("SELECT column_name FROM information_schema.columns WHERE table_name = 'solicitudes_servicio' AND column_name IN ('cliente_confirma_pago', 'conductor_confirma_recibo', 'tiene_disputa')");
    $cols = $stmt->fetchAll(PDO::FETCH_COLUMN);
    echo "✅ Columnas agregadas a solicitudes_servicio: " . implode(', ', $cols) . "\n";
    
    // Verificar columnas en usuarios
    $stmt = $db->query("SELECT column_name FROM information_schema.columns WHERE table_name = 'usuarios' AND column_name IN ('tiene_disputa_activa', 'disputa_activa_id')");
    $cols = $stmt->fetchAll(PDO::FETCH_COLUMN);
    echo "✅ Columnas agregadas a usuarios: " . implode(', ', $cols) . "\n";
    
    echo "\n═══════════════════════════════════════════════════════════════\n";
    echo "   ✅ MIGRACIÓN COMPLETADA\n";
    echo "═══════════════════════════════════════════════════════════════\n\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n\n";
}
