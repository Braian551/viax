<?php
/**
 * Obtiene las solicitudes más recientes para usar en los tests
 */

require_once __DIR__ . '/backend/config/database.php';

try {
    $database = new Database();
    $db = $database->getConnection();
    
    echo "🔍 Buscando solicitudes recientes completadas...\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";
    
    $query = "
        SELECT 
            s.id,
            s.cliente_id,
            a.conductor_id,
            s.estado,
            s.direccion_recogida as origen_direccion,
            s.direccion_destino as destino_direccion,
            uc.nombre as cliente_nombre,
            uc.telefono as cliente_telefono,
            ucon.nombre as conductor_nombre,
            ucon.telefono as conductor_telefono
        FROM solicitudes_servicio s
        LEFT JOIN asignaciones_conductor a ON s.id = a.solicitud_id
        LEFT JOIN usuarios uc ON s.cliente_id = uc.id
        LEFT JOIN usuarios ucon ON a.conductor_id = ucon.id
        WHERE s.estado = 'completado'
        AND a.conductor_id IS NOT NULL
        ORDER BY s.id DESC
        LIMIT 10
    ";
    
    $stmt = $db->prepare($query);
    $stmt->execute();
    $solicitudes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($solicitudes)) {
        echo "❌ No hay solicitudes completadas\n";
        echo "\n💡 Crea viajes de prueba primero\n";
        exit(1);
    }
    
    echo "📋 Solicitudes disponibles para testing:\n\n";
    
    foreach ($solicitudes as $i => $sol) {
        echo ($i + 1) . ". Solicitud ID: {$sol['id']}\n";
        echo "   ├─ Cliente: {$sol['cliente_nombre']} (ID: {$sol['cliente_id']}, Tel: {$sol['cliente_telefono']})\n";
        echo "   ├─ Conductor: {$sol['conductor_nombre']} (ID: {$sol['conductor_id']}, Tel: {$sol['conductor_telefono']})\n";
        echo "   ├─ Origen: {$sol['origen_direccion']}\n";
        echo "   └─ Destino: {$sol['destino_direccion']}\n\n";
    }
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    echo "📝 COMANDOS DE EJEMPLO:\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";
    
    $primera = $solicitudes[0];
    
    echo "# Cliente confirma que pagó:\n";
    echo "php test_cliente_confirma_pago.php {$primera['id']} {$primera['cliente_id']}\n\n";
    
    echo "# Conductor confirma que recibió:\n";
    echo "php test_conductor_recibio_pago.php {$primera['id']} {$primera['conductor_id']}\n\n";
    
    echo "# Crear una disputa (cliente pagó, conductor no recibió):\n";
    echo "php test_crear_disputa.php {$primera['id']} {$primera['cliente_id']} {$primera['conductor_id']}\n\n";
    
    echo "# Verificar disputa del cliente:\n";
    echo "php test_verificar_disputa.php {$primera['cliente_id']}\n\n";
    
    echo "# Resolver disputa:\n";
    echo "php test_resolver_disputa.php {$primera['id']} {$primera['conductor_id']}\n\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    exit(1);
}
