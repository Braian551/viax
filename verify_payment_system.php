<?php
/**
 * Test de verificación del sistema de pagos corregido
 */

require_once 'backend/config/database.php';

$db = (new Database())->getConnection();

echo "=== VERIFICACIÓN COMPLETA DEL SISTEMA DE PAGOS ===\n\n";

// 1. Verificar estructura de tablas
echo "1. ESTRUCTURA DE TABLAS\n";
echo "========================\n";

$tables = [
    'transacciones' => ['monto_conductor', 'estado', 'comision_plataforma'],
    'solicitudes_servicio' => ['precio_estimado', 'precio_final', 'metodo_pago', 'pago_confirmado'],
    'detalles_conductor' => ['ganancias_totales', 'total_viajes'],
    'pagos_viaje' => ['solicitud_id', 'monto', 'estado']
];

foreach ($tables as $table => $columns) {
    $stmt = $db->query("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = '$table')");
    $exists = $stmt->fetchColumn();
    echo "Tabla $table: " . ($exists ? '✅' : '❌') . "\n";
    
    if ($exists) {
        foreach ($columns as $col) {
            $stmt = $db->prepare("SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = ? AND column_name = ?)");
            $stmt->execute([$table, $col]);
            $colExists = $stmt->fetchColumn();
            echo "  - $col: " . ($colExists ? '✅' : '❌') . "\n";
        }
    }
}

// 2. Verificar datos
echo "\n2. DATOS DEL SISTEMA\n";
echo "====================\n";

$stmt = $db->query("SELECT COUNT(*) FROM solicitudes_servicio WHERE estado IN ('completada', 'entregado')");
echo "Viajes completados: " . $stmt->fetchColumn() . "\n";

$stmt = $db->query("SELECT COUNT(*) FROM transacciones WHERE estado = 'completada'");
echo "Transacciones completadas: " . $stmt->fetchColumn() . "\n";

$stmt = $db->query("SELECT COUNT(*) FROM pagos_viaje");
echo "Pagos registrados: " . $stmt->fetchColumn() . "\n";

// 3. Verificar ganancias
echo "\n3. GANANCIAS POR CONDUCTOR\n";
echo "==========================\n";

$stmt = $db->query("
    SELECT dc.usuario_id, u.nombre, u.apellido, 
           dc.ganancias_totales, dc.total_viajes,
           (SELECT COALESCE(SUM(monto_conductor), 0) FROM transacciones WHERE conductor_id = dc.usuario_id AND estado = 'completada') as ganancias_transacciones
    FROM detalles_conductor dc
    INNER JOIN usuarios u ON dc.usuario_id = u.id
    WHERE dc.total_viajes > 0 OR dc.ganancias_totales > 0
");

while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "Conductor #{$row['usuario_id']} ({$row['nombre']} {$row['apellido']})\n";
    echo "  - Ganancias en detalles_conductor: \${$row['ganancias_totales']}\n";
    echo "  - Ganancias en transacciones: \${$row['ganancias_transacciones']}\n";
    echo "  - Total viajes: {$row['total_viajes']}\n";
    
    if ($row['ganancias_totales'] != $row['ganancias_transacciones']) {
        echo "  ⚠️ INCONSISTENCIA: Los valores no coinciden\n";
    } else {
        echo "  ✅ Datos consistentes\n";
    }
}

// 4. Verificar historial de viajes del conductor
echo "\n4. ÚLTIMO VIAJE CON PRECIOS\n";
echo "===========================\n";

$stmt = $db->query("
    SELECT s.id, s.tipo_servicio, s.estado, s.precio_estimado, s.precio_final,
           s.metodo_pago, s.pago_confirmado,
           t.monto_total, t.monto_conductor, t.estado as estado_transaccion
    FROM solicitudes_servicio s
    LEFT JOIN transacciones t ON s.id = t.solicitud_id
    WHERE s.estado IN ('completada', 'entregado')
    ORDER BY s.completado_en DESC
    LIMIT 3
");

while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
    echo "Viaje #{$row['id']} - {$row['tipo_servicio']} ({$row['estado']})\n";
    echo "  Precio estimado: \${$row['precio_estimado']}\n";
    echo "  Precio final: \${$row['precio_final']}\n";
    echo "  Método pago: {$row['metodo_pago']}\n";
    echo "  Transacción: \${$row['monto_total']} (conductor: \${$row['monto_conductor']})\n";
}

echo "\n=== VERIFICACIÓN COMPLETADA ===\n";
