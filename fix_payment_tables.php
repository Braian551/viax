<?php
/**
 * Script para ejecutar migración 017 paso a paso
 */

require_once __DIR__ . '/backend/config/database.php';

try {
    $database = new Database();
    $db = $database->getConnection();
    
    echo "=== Migración 017: Corrección del Sistema de Pagos ===\n\n";
    
    $steps = [
        // Paso 1: Columnas en solicitudes_servicio
        [
            'name' => 'Agregar precio_estimado a solicitudes_servicio',
            'sql' => "ALTER TABLE solicitudes_servicio ADD COLUMN IF NOT EXISTS precio_estimado NUMERIC(10,2) DEFAULT 0"
        ],
        [
            'name' => 'Agregar precio_final a solicitudes_servicio',
            'sql' => "ALTER TABLE solicitudes_servicio ADD COLUMN IF NOT EXISTS precio_final NUMERIC(10,2) DEFAULT 0"
        ],
        [
            'name' => 'Agregar metodo_pago a solicitudes_servicio',
            'sql' => "ALTER TABLE solicitudes_servicio ADD COLUMN IF NOT EXISTS metodo_pago VARCHAR(50) DEFAULT 'efectivo'"
        ],
        [
            'name' => 'Agregar pago_confirmado a solicitudes_servicio',
            'sql' => "ALTER TABLE solicitudes_servicio ADD COLUMN IF NOT EXISTS pago_confirmado BOOLEAN DEFAULT FALSE"
        ],
        [
            'name' => 'Agregar pago_confirmado_en a solicitudes_servicio',
            'sql' => "ALTER TABLE solicitudes_servicio ADD COLUMN IF NOT EXISTS pago_confirmado_en TIMESTAMP"
        ],
        
        // Paso 2: Columnas en transacciones
        [
            'name' => 'Agregar monto_conductor a transacciones',
            'sql' => "ALTER TABLE transacciones ADD COLUMN IF NOT EXISTS monto_conductor NUMERIC(10,2) DEFAULT 0"
        ],
        [
            'name' => 'Agregar estado a transacciones',
            'sql' => "ALTER TABLE transacciones ADD COLUMN IF NOT EXISTS estado VARCHAR(50) DEFAULT 'pendiente'"
        ],
        [
            'name' => 'Agregar comision_plataforma a transacciones',
            'sql' => "ALTER TABLE transacciones ADD COLUMN IF NOT EXISTS comision_plataforma NUMERIC(10,2) DEFAULT 0"
        ],
        
        // Paso 3: Crear tabla pagos_viaje
        [
            'name' => 'Crear tabla pagos_viaje',
            'sql' => "CREATE TABLE IF NOT EXISTS pagos_viaje (
                id SERIAL PRIMARY KEY,
                solicitud_id INT UNIQUE NOT NULL,
                conductor_id INT NOT NULL,
                cliente_id INT,
                monto NUMERIC(10,2) NOT NULL,
                metodo_pago VARCHAR(50) DEFAULT 'efectivo',
                estado VARCHAR(20) DEFAULT 'pendiente',
                confirmado_en TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )"
        ],
        
        // Paso 4: Índices
        [
            'name' => 'Crear índice transacciones_conductor',
            'sql' => "CREATE INDEX IF NOT EXISTS idx_transacciones_conductor ON transacciones(conductor_id)"
        ],
        [
            'name' => 'Crear índice transacciones_estado',
            'sql' => "CREATE INDEX IF NOT EXISTS idx_transacciones_estado ON transacciones(estado)"
        ],
        [
            'name' => 'Crear índice transacciones_fecha',
            'sql' => "CREATE INDEX IF NOT EXISTS idx_transacciones_fecha ON transacciones(fecha_transaccion)"
        ],
    ];
    
    foreach ($steps as $step) {
        try {
            $db->exec($step['sql']);
            echo "✅ {$step['name']}\n";
        } catch (PDOException $e) {
            if (strpos($e->getMessage(), 'already exists') !== false || 
                strpos($e->getMessage(), 'ya existe') !== false) {
                echo "⏭️  {$step['name']} (ya existe)\n";
            } else {
                echo "❌ {$step['name']}: " . $e->getMessage() . "\n";
            }
        }
    }
    
    // Actualizar datos existentes
    echo "\n=== Actualizando datos existentes ===\n";
    
    try {
        // Calcular monto_conductor para registros existentes
        $db->exec("UPDATE transacciones SET monto_conductor = COALESCE(monto_total, 0) * 0.90 WHERE monto_conductor IS NULL OR monto_conductor = 0");
        echo "✅ monto_conductor calculado (90% del total)\n";
        
        $db->exec("UPDATE transacciones SET comision_plataforma = COALESCE(monto_total, 0) * 0.10 WHERE comision_plataforma IS NULL OR comision_plataforma = 0");
        echo "✅ comision_plataforma calculada (10% del total)\n";
        
        $db->exec("UPDATE transacciones SET estado = 'completada' WHERE estado_pago IN ('completado', 'pagado')");
        echo "✅ Estados de transacciones actualizados\n";
    } catch (PDOException $e) {
        echo "⚠️  Error actualizando datos: " . $e->getMessage() . "\n";
    }
    
    // Verificación
    echo "\n=== Verificación Final ===\n";
    
    $cols = [
        'solicitudes_servicio' => ['precio_estimado', 'precio_final', 'metodo_pago', 'pago_confirmado'],
        'transacciones' => ['monto_conductor', 'estado', 'comision_plataforma']
    ];
    
    foreach ($cols as $table => $columns) {
        foreach ($columns as $col) {
            $stmt = $db->prepare("SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = ? AND column_name = ?)");
            $stmt->execute([$table, $col]);
            $exists = $stmt->fetchColumn();
            echo "$table.$col: " . ($exists ? '✅' : '❌') . "\n";
        }
    }
    
    $stmt = $db->query("SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'pagos_viaje')");
    echo "tabla pagos_viaje: " . ($stmt->fetchColumn() ? '✅' : '❌') . "\n";
    
    echo "\n✅ Migración completada!\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
}
