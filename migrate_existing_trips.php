<?php
/**
 * Script para migrar viajes completados existentes a transacciones
 * Esto es necesario para los viajes que se completaron antes de la corrección
 */

require_once 'backend/config/database.php';

try {
    $database = new Database();
    $db = $database->getConnection();
    
    echo "=== Migrando viajes completados a transacciones ===\n\n";
    
    // Obtener viajes completados sin transacción
    $stmt = $db->query("
        SELECT s.id, s.cliente_id, s.precio_estimado, s.precio_final, s.metodo_pago,
               s.completado_en, ac.conductor_id
        FROM solicitudes_servicio s
        INNER JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id
        LEFT JOIN transacciones t ON s.id = t.solicitud_id
        WHERE s.estado IN ('completada', 'entregado')
        AND t.id IS NULL
    ");
    
    $viajes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Viajes completados sin transacción: " . count($viajes) . "\n\n";
    
    $creados = 0;
    $errores = 0;
    
    foreach ($viajes as $viaje) {
        try {
            // Determinar monto - usar precio_final si existe, si no precio_estimado, si no un valor por defecto
            $montoTotal = $viaje['precio_final'] > 0 ? $viaje['precio_final'] : 
                         ($viaje['precio_estimado'] > 0 ? $viaje['precio_estimado'] : 50000); // 50,000 COP por defecto
            
            $montoConductor = $montoTotal * 0.90;
            $comisionPlataforma = $montoTotal * 0.10;
            $metodoPago = $viaje['metodo_pago'] ?? 'efectivo';
            
            // Crear transacción
            $stmt = $db->prepare("
                INSERT INTO transacciones (
                    solicitud_id, cliente_id, conductor_id,
                    monto_total, monto_conductor, comision_plataforma,
                    metodo_pago, estado, estado_pago,
                    fecha_transaccion, completado_en
                ) VALUES (?, ?, ?, ?, ?, ?, ?, 'completada', 'completado', ?, ?)
            ");
            $stmt->execute([
                $viaje['id'],
                $viaje['cliente_id'],
                $viaje['conductor_id'],
                $montoTotal,
                $montoConductor,
                $comisionPlataforma,
                $metodoPago,
                $viaje['completado_en'] ?? date('Y-m-d H:i:s'),
                $viaje['completado_en'] ?? date('Y-m-d H:i:s')
            ]);
            
            // Actualizar precio_final en solicitud si no existe
            if ($viaje['precio_final'] == 0 || $viaje['precio_final'] === null) {
                $stmt = $db->prepare("UPDATE solicitudes_servicio SET precio_final = ? WHERE id = ?");
                $stmt->execute([$montoTotal, $viaje['id']]);
            }
            
            // Registrar en pagos_viaje
            $stmt = $db->prepare("
                INSERT INTO pagos_viaje (solicitud_id, conductor_id, cliente_id, monto, metodo_pago, estado, confirmado_en)
                VALUES (?, ?, ?, ?, ?, 'confirmado', ?)
                ON CONFLICT (solicitud_id) DO NOTHING
            ");
            $stmt->execute([
                $viaje['id'],
                $viaje['conductor_id'],
                $viaje['cliente_id'],
                $montoTotal,
                $metodoPago,
                $viaje['completado_en'] ?? date('Y-m-d H:i:s')
            ]);
            
            echo "✅ Viaje #{$viaje['id']} - Conductor #{$viaje['conductor_id']} - Monto: \${$montoTotal}\n";
            $creados++;
            
        } catch (PDOException $e) {
            echo "❌ Error viaje #{$viaje['id']}: " . $e->getMessage() . "\n";
            $errores++;
        }
    }
    
    // Actualizar ganancias totales de conductores
    echo "\n=== Actualizando ganancias totales de conductores ===\n";
    
    $stmt = $db->query("
        SELECT conductor_id, SUM(monto_conductor) as total_ganancias, COUNT(*) as total_viajes
        FROM transacciones
        WHERE estado = 'completada'
        GROUP BY conductor_id
    ");
    
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $stmtUpdate = $db->prepare("
            UPDATE detalles_conductor 
            SET ganancias_totales = ?,
                total_viajes = ?
            WHERE usuario_id = ?
        ");
        $stmtUpdate->execute([$row['total_ganancias'], $row['total_viajes'], $row['conductor_id']]);
        echo "Conductor #{$row['conductor_id']}: Ganancias = \${$row['total_ganancias']}, Viajes = {$row['total_viajes']}\n";
    }
    
    echo "\n=== Resumen ===\n";
    echo "Transacciones creadas: $creados\n";
    echo "Errores: $errores\n";
    
    // Verificación final
    echo "\n=== Verificación ===\n";
    $stmt = $db->query("SELECT COUNT(*) FROM transacciones WHERE estado = 'completada'");
    echo "Total transacciones completadas: " . $stmt->fetchColumn() . "\n";
    
    $stmt = $db->query("SELECT COUNT(*) FROM solicitudes_servicio WHERE estado IN ('completada', 'entregado')");
    echo "Total viajes completados: " . $stmt->fetchColumn() . "\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
}
