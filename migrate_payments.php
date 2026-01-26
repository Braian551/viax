<?php
/**
 * Script de migración: Marcar viajes completados como pagados
 * Ejecutar una sola vez
 */

require_once 'backend/config/database.php';

echo "Iniciando migración de pagos...\n";

try {
    $database = new Database();
    $db = $database->getConnection();
    
    // 1. Contar cuántos viajes se van a actualizar
    $stmtCount = $db->query("
        SELECT COUNT(*) 
        FROM solicitudes_servicio 
        WHERE estado IN ('completada', 'entregado') 
        AND (pago_confirmado = false OR pago_confirmado IS NULL)
    ");
    $count = $stmtCount->fetchColumn();
    
    echo "Se encontraron $count viajes completados sin pago confirmado.\n";
    
    if ($count > 0) {
        $db->beginTransaction();
        
        // 2. Actualizar viajes
        // Usamos completado_en si existe, sino la fecha actual (NOW)
        // Set payment method to 'efectivo' if null, assuming cash for old trips or whatever logic fits best, 
        // but here we just confirm payment.
        
        $sql = "
            UPDATE solicitudes_servicio 
            SET 
                pago_confirmado = true,
                pago_confirmado_en = COALESCE(completado_en, NOW())
            WHERE 
                estado IN ('completada', 'entregado') 
                AND (pago_confirmado = false OR pago_confirmado IS NULL)
        ";
        
        $stmtUpdate = $db->prepare($sql);
        $stmtUpdate->execute();
        $updated = $stmtUpdate->rowCount();
        
        $db->commit();
        
        echo "Migración completada con éxito. Registros actualizados: $updated\n";
    } else {
        echo "No se requieren cambios.\n";
    }
    
} catch (Exception $e) {
    if (isset($db) && $db->inTransaction()) {
        $db->rollBack();
    }
    echo "ERROR: " . $e->getMessage() . "\n";
}
?>
