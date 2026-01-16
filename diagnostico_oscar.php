<?php
/**
 * Diagnóstico: Por qué Oscar no ve la solicitud 725
 */

require_once __DIR__ . '/backend/config/database.php';

echo "=== DIAGNÓSTICO: Solicitud 725 y Conductor Oscar (Bird) ===\n\n";

try {
    $database = new Database();
    $db = $database->getConnection();
    
    // 1. Buscar información de la solicitud 725
    echo "1. INFORMACIÓN DE LA SOLICITUD 725:\n";
    $stmt = $db->query("
        SELECT 
            s.*,
            u.nombre as cliente_nombre,
            u.email as cliente_email
        FROM solicitudes_servicio s
        JOIN usuarios u ON s.cliente_id = u.id
        WHERE s.id = 725
    ");
    $solicitud = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($solicitud) {
        echo "   Estado: {$solicitud['estado']}\n";
        echo "   Cliente: {$solicitud['cliente_nombre']} ({$solicitud['cliente_email']})\n";
        echo "   Fecha creación: {$solicitud['fecha_creacion']}\n";
        echo "   Solicitado en: {$solicitud['solicitado_en']}\n";
        echo "   Ubicación origen: {$solicitud['latitud_recogida']}, {$solicitud['longitud_recogida']}\n";
        echo "   Dirección origen: {$solicitud['direccion_recogida']}\n";
        echo "   Tipo servicio: {$solicitud['tipo_servicio']}\n";
        
        // Verificar si existen columnas tipo_vehiculo y empresa_id
        $columns = array_keys($solicitud);
        echo "   ¿Tiene tipo_vehiculo?: " . (in_array('tipo_vehiculo', $columns) ? $solicitud['tipo_vehiculo'] ?? 'NULL' : 'COLUMNA NO EXISTE') . "\n";
        echo "   ¿Tiene empresa_id?: " . (in_array('empresa_id', $columns) ? $solicitud['empresa_id'] ?? 'NULL' : 'COLUMNA NO EXISTE') . "\n";
        
        $solLatitud = $solicitud['latitud_recogida'];
        $solLongitud = $solicitud['longitud_recogida'];
    } else {
        echo "   ❌ Solicitud 725 no encontrada\n";
        exit;
    }
    
    // 2. Buscar conductor Oscar de Bird
    echo "\n2. INFORMACIÓN DEL CONDUCTOR OSCAR (Bird):\n";
    $stmt = $db->query("
        SELECT 
            u.id,
            u.nombre,
            u.apellido,
            u.email,
            u.empresa_id,
            u.es_activo,
            dc.disponible,
            dc.vehiculo_tipo,
            dc.estado_verificacion,
            dc.latitud_actual,
            dc.longitud_actual,
            dc.ultima_actualizacion,
            e.nombre as empresa_nombre
        FROM usuarios u
        JOIN detalles_conductor dc ON u.id = dc.usuario_id
        LEFT JOIN empresas_transporte e ON u.empresa_id = e.id
        WHERE u.nombre ILIKE '%oscar%'
        OR u.email ILIKE '%oscar%'
        ORDER BY u.id DESC
        LIMIT 5
    ");
    $conductores = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($conductores as $conductor) {
        echo "   ---\n";
        echo "   ID: {$conductor['id']}\n";
        echo "   Nombre: {$conductor['nombre']} {$conductor['apellido']}\n";
        echo "   Email: {$conductor['email']}\n";
        echo "   Empresa ID: " . ($conductor['empresa_id'] ?? 'NULL') . "\n";
        echo "   Empresa: " . ($conductor['empresa_nombre'] ?? 'Sin empresa') . "\n";
        echo "   Es activo: " . ($conductor['es_activo'] ? 'Sí' : 'No') . "\n";
        echo "   Disponible: " . ($conductor['disponible'] ? 'Sí' : 'No') . "\n";
        echo "   Tipo vehículo: {$conductor['vehiculo_tipo']}\n";
        echo "   Estado verificación: {$conductor['estado_verificacion']}\n";
        echo "   Ubicación actual: {$conductor['latitud_actual']}, {$conductor['longitud_actual']}\n";
        echo "   Última actualización: {$conductor['ultima_actualizacion']}\n";
        
        // Calcular distancia si hay ubicación
        if ($conductor['latitud_actual'] && $conductor['longitud_actual'] && $solLatitud && $solLongitud) {
            $distancia = calcularDistancia(
                $solLatitud, $solLongitud,
                $conductor['latitud_actual'], $conductor['longitud_actual']
            );
            echo "   📍 DISTANCIA A SOLICITUD: " . round($distancia, 2) . " km\n";
            echo "   📍 ¿Dentro de 5km?: " . ($distancia <= 5 ? 'SÍ ✅' : 'NO ❌') . "\n";
            echo "   📍 ¿Dentro de 10km?: " . ($distancia <= 10 ? 'SÍ ✅' : 'NO ❌') . "\n";
        }
    }
    
    // 3. Buscar todos los conductores de Bird
    echo "\n3. TODOS LOS CONDUCTORES DE BIRD (empresa_id):\n";
    $stmt = $db->query("
        SELECT 
            u.id,
            u.nombre,
            u.empresa_id,
            dc.disponible,
            dc.vehiculo_tipo,
            dc.estado_verificacion,
            dc.latitud_actual,
            dc.longitud_actual,
            e.nombre as empresa_nombre
        FROM usuarios u
        JOIN detalles_conductor dc ON u.id = dc.usuario_id
        LEFT JOIN empresas_transporte e ON u.empresa_id = e.id
        WHERE e.nombre ILIKE '%bird%'
        OR u.empresa_id IN (SELECT id FROM empresas_transporte WHERE nombre ILIKE '%bird%')
    ");
    $conductoresBird = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($conductoresBird)) {
        echo "   ❌ No se encontraron conductores de Bird\n";
        
        // Buscar empresa Bird
        $stmt = $db->query("SELECT id, nombre FROM empresas_transporte WHERE nombre ILIKE '%bird%'");
        $empresas = $stmt->fetchAll(PDO::FETCH_ASSOC);
        echo "   Empresas con 'bird': \n";
        foreach ($empresas as $emp) {
            echo "     - ID: {$emp['id']}, Nombre: {$emp['nombre']}\n";
        }
    } else {
        foreach ($conductoresBird as $c) {
            echo "   - ID {$c['id']}: {$c['nombre']} | Empresa: {$c['empresa_nombre']} | ";
            echo "Disponible: " . ($c['disponible'] ? 'Sí' : 'No') . " | ";
            echo "Vehículo: {$c['vehiculo_tipo']} | ";
            echo "Verificación: {$c['estado_verificacion']}\n";
        }
    }
    
    // 4. Verificar solicitudes_vinculacion_conductor
    echo "\n4. VINCULACIONES DE CONDUCTORES CON EMPRESAS:\n";
    $stmt = $db->query("
        SELECT 
            svc.id,
            svc.conductor_id,
            svc.empresa_id,
            svc.estado,
            u.nombre as conductor_nombre,
            e.nombre as empresa_nombre
        FROM solicitudes_vinculacion_conductor svc
        JOIN usuarios u ON svc.conductor_id = u.id
        JOIN empresas_transporte e ON svc.empresa_id = e.id
        WHERE e.nombre ILIKE '%bird%'
        OR u.nombre ILIKE '%oscar%'
        ORDER BY svc.id DESC
        LIMIT 10
    ");
    $vinculaciones = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($vinculaciones as $v) {
        echo "   - Conductor: {$v['conductor_nombre']} (ID: {$v['conductor_id']}) ";
        echo "→ Empresa: {$v['empresa_nombre']} (ID: {$v['empresa_id']}) ";
        echo "| Estado: {$v['estado']}\n";
    }
    
    // 5. Verificar estructura de la tabla solicitudes_servicio
    echo "\n5. ESTRUCTURA DE solicitudes_servicio:\n";
    $stmt = $db->query("
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_name = 'solicitudes_servicio'
        ORDER BY ordinal_position
    ");
    $columnas = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $tieneEmpresaId = false;
    $tieneTipoVehiculo = false;
    $tieneConductorId = false;
    
    foreach ($columnas as $col) {
        if ($col['column_name'] == 'empresa_id') $tieneEmpresaId = true;
        if ($col['column_name'] == 'tipo_vehiculo') $tieneTipoVehiculo = true;
        if ($col['column_name'] == 'conductor_id') $tieneConductorId = true;
    }
    
    echo "   ¿Tiene empresa_id?: " . ($tieneEmpresaId ? 'SÍ ✅' : 'NO ❌ - NECESITA MIGRACIÓN') . "\n";
    echo "   ¿Tiene tipo_vehiculo?: " . ($tieneTipoVehiculo ? 'SÍ ✅' : 'NO ❌ - NECESITA MIGRACIÓN') . "\n";
    echo "   ¿Tiene conductor_id?: " . ($tieneConductorId ? 'SÍ ✅' : 'NO ❌ - Usa tabla asignaciones_conductor') . "\n";
    
    // 6. Verificar solicitudes pendientes cercanas al conductor Oscar
    echo "\n6. SOLICITUDES PENDIENTES (últimos 15 min):\n";
    $stmt = $db->query("
        SELECT id, estado, tipo_servicio, direccion_recogida, 
               fecha_creacion, solicitado_en,
               latitud_recogida, longitud_recogida
        FROM solicitudes_servicio
        WHERE estado = 'pendiente'
        AND solicitado_en >= NOW() - INTERVAL '15 minutes'
        ORDER BY id DESC
        LIMIT 5
    ");
    $pendientes = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($pendientes)) {
        echo "   No hay solicitudes pendientes en los últimos 15 minutos\n";
    } else {
        foreach ($pendientes as $p) {
            echo "   - ID {$p['id']}: {$p['direccion_recogida']} | Estado: {$p['estado']} | Solicitado: {$p['solicitado_en']}\n";
        }
    }
    
    echo "\n=== FIN DEL DIAGNÓSTICO ===\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
    echo "Trace: " . $e->getTraceAsString() . "\n";
}

function calcularDistancia($lat1, $lon1, $lat2, $lon2) {
    $R = 6371; // Radio de la Tierra en km
    $dLat = deg2rad($lat2 - $lat1);
    $dLon = deg2rad($lon2 - $lon1);
    $a = sin($dLat/2) * sin($dLat/2) +
         cos(deg2rad($lat1)) * cos(deg2rad($lat2)) *
         sin($dLon/2) * sin($dLon/2);
    $c = 2 * atan2(sqrt($a), sqrt(1-$a));
    return $R * $c;
}
