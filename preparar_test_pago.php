<?php
/**
 * Obtiene solicitudes en cualquier estado y las completa para testing
 */

require_once __DIR__ . '/backend/config/database.php';

try {
    $database = new Database();
    $db = $database->getConnection();
    
    echo "🔍 Buscando solicitudes recientes...\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";
    
    // Buscar cualquier solicitud con conductor asignado
    $query = "
        SELECT 
            s.id,
            s.cliente_id,
            a.conductor_id,
            s.estado,
            s.direccion_recogida as origen,
            s.direccion_destino as destino,
            uc.nombre as cliente_nombre,
            ucon.nombre as conductor_nombre
        FROM solicitudes_servicio s
        LEFT JOIN asignaciones_conductor a ON s.id = a.solicitud_id
        LEFT JOIN usuarios uc ON s.cliente_id = uc.id
        LEFT JOIN usuarios ucon ON a.conductor_id = ucon.id
        WHERE a.conductor_id IS NOT NULL
        ORDER BY s.id DESC
        LIMIT 5
    ";
    
    $stmt = $db->prepare($query);
    $stmt->execute();
    $solicitudes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($solicitudes)) {
        echo "❌ No hay solicitudes con conductor asignado\n";
        exit(1);
    }
    
    echo "📋 Solicitudes encontradas:\n\n";
    
    foreach ($solicitudes as $i => $sol) {
        echo ($i + 1) . ". [ID: {$sol['id']}] Estado: {$sol['estado']}\n";
        echo "   Cliente: {$sol['cliente_nombre']} (ID: {$sol['cliente_id']})\n";
        echo "   Conductor: {$sol['conductor_nombre']} (ID: {$sol['conductor_id']})\n\n";
    }
    
    // Seleccionar la primera solicitud
    $selected = $solicitudes[0];
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    echo "🎯 Usando solicitud ID: {$selected['id']}\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";
    
    // Completar la solicitud si no está completada
    if ($selected['estado'] !== 'completado') {
        echo "📝 Completando solicitud...\n";
        
        $updateQuery = "UPDATE solicitudes_servicio 
                       SET estado = 'completado', 
                           completado_en = NOW()
                       WHERE id = :id";
        $updateStmt = $db->prepare($updateQuery);
        $updateStmt->bindParam(':id', $selected['id']);
        $updateStmt->execute();
        
        echo "✅ Solicitud marcada como completada\n\n";
    } else {
        echo "✅ Solicitud ya está completada\n\n";
    }
    
    // Mostrar comandos de prueba
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    echo "📝 COMANDOS PARA TESTING:\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";
    
    $solId = $selected['id'];
    $clienteId = $selected['cliente_id'];
    $conductorId = $selected['conductor_id'];
    
    echo "# 1. Cliente confirma que pagó:\n";
    echo "php test_cliente_confirma_pago.php $solId $clienteId\n\n";
    
    echo "# 2. Conductor confirma que recibió:\n";
    echo "php test_conductor_recibio_pago.php $solId $conductorId\n\n";
    
    echo "# 3. Crear una DISPUTA (cliente pagó, conductor no recibió):\n";
    echo "php test_crear_disputa.php $solId $clienteId $conductorId\n\n";
    
    echo "# 4. Verificar si cliente tiene disputa:\n";
    echo "php test_verificar_disputa.php $clienteId\n\n";
    
    echo "# 5. Verificar si conductor tiene disputa:\n";
    echo "php test_verificar_disputa.php $conductorId\n\n";
    
    echo "# 6. Resolver disputa:\n";
    echo "php test_resolver_disputa.php $solId $conductorId\n\n";
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    exit(1);
}
