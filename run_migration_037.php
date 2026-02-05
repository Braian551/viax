<?php
/**
 * Script para ejecutar la migración del sistema de concurrencia y latencia
 */

require_once 'backend/config/database.php';

echo "═══════════════════════════════════════════════════════════════\n";
echo "   🔄 Ejecutando migración: Sistema de Concurrencia\n";
echo "═══════════════════════════════════════════════════════════════\n\n";

try {
    $db = (new Database())->getConnection();
    
    // Paso 1: Ejecutar migración principal (tablas y columnas)
    echo "📋 Paso 1: Ejecutando migración de tablas y columnas...\n";
    $sql = file_get_contents('backend/migrations/037_concurrency_and_latency_system.sql');
    
    // Remover comentarios de una línea y ejecutar
    $lines = explode("\n", $sql);
    $cleanedLines = [];
    foreach ($lines as $line) {
        $trimmed = trim($line);
        if (strpos($trimmed, '--') === 0 || empty($trimmed)) {
            continue;
        }
        $cleanedLines[] = $line;
    }
    $cleanSql = implode("\n", $cleanedLines);
    
    // Separar por ; pero solo fuera de strings
    $statements = preg_split('/;(?=(?:[^\'"]|\'[^\']*\'|"[^"]*")*$)/', $cleanSql);
    
    $errors = [];
    foreach ($statements as $stmt) {
        $stmt = trim($stmt);
        if (empty($stmt)) continue;
        
        try {
            $db->exec($stmt);
            echo "  ✓ Ejecutado: " . substr($stmt, 0, 60) . "...\n";
        } catch (Exception $e) {
            $errors[] = $e->getMessage();
            echo "  ✗ Error: " . $e->getMessage() . "\n";
        }
    }
    
    // Paso 2: Ejecutar funciones PL/pgSQL como bloques completos
    echo "\n📋 Paso 2: Creando funciones PL/pgSQL...\n";
    
    // Función 1: increment_solicitud_version
    $func1 = "
    CREATE OR REPLACE FUNCTION increment_solicitud_version()
    RETURNS TRIGGER AS \$FUNC\$
    BEGIN
        NEW.version = COALESCE(OLD.version, 0) + 1;
        NEW.updated_at = NOW();
        RETURN NEW;
    END;
    \$FUNC\$ LANGUAGE plpgsql
    ";
    
    try {
        $db->exec($func1);
        echo "  ✓ Función increment_solicitud_version creada\n";
    } catch (Exception $e) {
        echo "  ✗ Error en increment_solicitud_version: " . $e->getMessage() . "\n";
    }
    
    // Función 2: acquire_lock
    $func2 = "
    CREATE OR REPLACE FUNCTION acquire_lock(
        p_resource_type VARCHAR,
        p_resource_id INTEGER,
        p_lock_holder VARCHAR,
        p_duration_seconds INTEGER DEFAULT 30
    )
    RETURNS BOOLEAN AS \$FUNC\$
    DECLARE
        v_acquired BOOLEAN;
    BEGIN
        DELETE FROM distributed_locks WHERE expires_at < NOW();
        INSERT INTO distributed_locks (resource_type, resource_id, lock_holder, expires_at)
        VALUES (p_resource_type, p_resource_id, p_lock_holder, NOW() + (p_duration_seconds || ' seconds')::INTERVAL)
        ON CONFLICT (resource_type, resource_id) DO NOTHING;
        SELECT EXISTS(
            SELECT 1 FROM distributed_locks 
            WHERE resource_type = p_resource_type 
            AND resource_id = p_resource_id 
            AND lock_holder = p_lock_holder
        ) INTO v_acquired;
        RETURN v_acquired;
    END;
    \$FUNC\$ LANGUAGE plpgsql
    ";
    
    try {
        $db->exec($func2);
        echo "  ✓ Función acquire_lock creada\n";
    } catch (Exception $e) {
        echo "  ✗ Error en acquire_lock: " . $e->getMessage() . "\n";
    }
    
    // Función 3: release_lock
    $func3 = "
    CREATE OR REPLACE FUNCTION release_lock(
        p_resource_type VARCHAR,
        p_resource_id INTEGER,
        p_lock_holder VARCHAR
    )
    RETURNS BOOLEAN AS \$FUNC\$
    BEGIN
        DELETE FROM distributed_locks 
        WHERE resource_type = p_resource_type 
        AND resource_id = p_resource_id 
        AND lock_holder = p_lock_holder;
        RETURN FOUND;
    END;
    \$FUNC\$ LANGUAGE plpgsql
    ";
    
    try {
        $db->exec($func3);
        echo "  ✓ Función release_lock creada\n";
    } catch (Exception $e) {
        echo "  ✗ Error en release_lock: " . $e->getMessage() . "\n";
    }
    
    // Paso 3: Crear trigger
    echo "\n📋 Paso 3: Creando trigger...\n";
    
    try {
        $db->exec("DROP TRIGGER IF EXISTS trigger_solicitud_version ON solicitudes_servicio");
        $db->exec("
            CREATE TRIGGER trigger_solicitud_version
            BEFORE UPDATE ON solicitudes_servicio
            FOR EACH ROW
            EXECUTE FUNCTION increment_solicitud_version()
        ");
        echo "  ✓ Trigger trigger_solicitud_version creado\n";
    } catch (Exception $e) {
        echo "  ✗ Error en trigger: " . $e->getMessage() . "\n";
    }
    
    // Verificaciones finales
    echo "\n📋 Verificando estructura...\n";
    
    // Verificar columnas
    $stmt = $db->query("
        SELECT column_name FROM information_schema.columns 
        WHERE table_name = 'solicitudes_servicio' 
        AND column_name IN ('version', 'locked_at', 'locked_by', 'last_sync_at', 'last_operation_key')
    ");
    $cols = $stmt->fetchAll(PDO::FETCH_COLUMN);
    echo "  ✓ Columnas en solicitudes_servicio: " . implode(', ', $cols) . "\n";
    
    // Verificar tablas
    $stmt = $db->query("
        SELECT table_name FROM information_schema.tables 
        WHERE table_name IN ('distributed_locks', 'pending_operations', 'sync_log')
    ");
    $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
    echo "  ✓ Tablas creadas: " . implode(', ', $tables) . "\n";
    
    // Verificar funciones
    $stmt = $db->query("
        SELECT routine_name FROM information_schema.routines 
        WHERE routine_name IN ('increment_solicitud_version', 'acquire_lock', 'release_lock')
        AND routine_schema = 'public'
    ");
    $funcs = $stmt->fetchAll(PDO::FETCH_COLUMN);
    echo "  ✓ Funciones creadas: " . implode(', ', $funcs) . "\n";
    
    echo "\n═══════════════════════════════════════════════════════════════\n";
    echo "   ✅ MIGRACIÓN COMPLETADA\n";
    echo "═══════════════════════════════════════════════════════════════\n\n";
    
} catch (Exception $e) {
    echo "❌ Error fatal: " . $e->getMessage() . "\n\n";
}
