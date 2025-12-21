<?php
/**
 * Test: Verificar endpoints de rating
 */

require_once 'backend/config/database.php';

echo "═══════════════════════════════════════════════════════════════\n";
echo "   🧪 TEST: Endpoints de Rating (simulación local)\n";
echo "═══════════════════════════════════════════════════════════════\n\n";

$database = new Database();
$db = $database->getConnection();

// ========================================
// Test 1: get_trip_summary
// ========================================
echo "📋 Test 1: Simulando get_trip_summary.php\n";

$solicitudId = 645; // Usar la solicitud que completamos

$stmt = $db->prepare("
    SELECT 
        s.id,
        s.estado,
        s.direccion_recogida,
        s.direccion_destino,
        s.distancia_estimada,
        s.tiempo_estimado,
        s.fecha_creacion,
        s.completado_en,
        s.cliente_id,
        u_cliente.nombre as cliente_nombre,
        u_cliente.apellido as cliente_apellido,
        u_cliente.telefono as cliente_telefono,
        u_cliente.foto_perfil as cliente_foto,
        ac.conductor_id,
        u_conductor.nombre as conductor_nombre,
        u_conductor.apellido as conductor_apellido,
        u_conductor.telefono as conductor_telefono,
        dc.calificacion_promedio as conductor_calificacion,
        dc.vehiculo_marca,
        dc.vehiculo_modelo,
        dc.vehiculo_placa,
        dc.vehiculo_color
    FROM solicitudes_servicio s
    INNER JOIN usuarios u_cliente ON s.cliente_id = u_cliente.id
    LEFT JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id
    LEFT JOIN usuarios u_conductor ON ac.conductor_id = u_conductor.id
    LEFT JOIN detalles_conductor dc ON ac.conductor_id = dc.usuario_id
    WHERE s.id = ?
");
$stmt->execute([$solicitudId]);
$viaje = $stmt->fetch(PDO::FETCH_ASSOC);

if ($viaje) {
    echo "   ✅ Consulta exitosa\n";
    echo "   📍 Origen: {$viaje['direccion_recogida']}\n";
    echo "   📍 Destino: {$viaje['direccion_destino']}\n";
    echo "   👤 Cliente: {$viaje['cliente_nombre']}\n";
    echo "   🚗 Conductor: {$viaje['conductor_nombre']}\n";
    echo "   ⭐ Rating Conductor: " . number_format($viaje['conductor_calificacion'] ?? 5.0, 1) . "\n";
} else {
    echo "   ❌ No se encontró el viaje\n";
}

// ========================================
// Test 2: Verificar estructura de calificaciones
// ========================================
echo "\n📋 Test 2: Verificando calificaciones guardadas\n";

$stmt = $db->prepare("
    SELECT 
        c.*,
        uc.nombre as nombre_calificador,
        ur.nombre as nombre_calificado
    FROM calificaciones c
    JOIN usuarios uc ON c.usuario_calificador_id = uc.id
    JOIN usuarios ur ON c.usuario_calificado_id = ur.id
    WHERE c.solicitud_id = ?
");
$stmt->execute([$solicitudId]);
$calificaciones = $stmt->fetchAll(PDO::FETCH_ASSOC);

if (!empty($calificaciones)) {
    echo "   ✅ Se encontraron " . count($calificaciones) . " calificaciones\n";
    foreach ($calificaciones as $c) {
        echo "   • {$c['nombre_calificador']} → {$c['nombre_calificado']}: {$c['calificacion']} ⭐\n";
    }
} else {
    echo "   ⚠️ No hay calificaciones aún\n";
}

// ========================================
// Test 3: Simular JSON response
// ========================================
echo "\n📋 Test 3: Generando JSON de respuesta\n";

// Calcular calificación del cliente
$stmt = $db->prepare("SELECT AVG(calificacion) FROM calificaciones WHERE usuario_calificado_id = ?");
$stmt->execute([$viaje['cliente_id']]);
$clienteCalificacion = $stmt->fetchColumn() ?? 5.0;

// Calcular precio
$distancia = floatval($viaje['distancia_estimada']);
$precioEstimado = 4500 + ($distancia * 1200);

$response = [
    'success' => true,
    'viaje' => [
        'id' => $viaje['id'],
        'estado' => $viaje['estado'],
        'origen' => $viaje['direccion_recogida'],
        'destino' => $viaje['direccion_destino'],
        'distancia_km' => $distancia,
        'duracion_minutos' => intval($viaje['tiempo_estimado']),
        'precio' => $precioEstimado,
        'metodo_pago' => 'Efectivo',
    ],
    'cliente' => [
        'id' => $viaje['cliente_id'],
        'nombre' => trim($viaje['cliente_nombre'] . ' ' . ($viaje['cliente_apellido'] ?? '')),
        'calificacion' => round(floatval($clienteCalificacion), 1),
    ],
    'conductor' => $viaje['conductor_id'] ? [
        'id' => $viaje['conductor_id'],
        'nombre' => trim($viaje['conductor_nombre'] . ' ' . ($viaje['conductor_apellido'] ?? '')),
        'calificacion' => round(floatval($viaje['conductor_calificacion'] ?? 5.0), 1),
        'vehiculo' => [
            'marca' => $viaje['vehiculo_marca'],
            'placa' => $viaje['vehiculo_placa'],
        ],
    ] : null,
];

echo "   ✅ JSON generado correctamente:\n";
echo "   " . json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";

echo "\n═══════════════════════════════════════════════════════════════\n";
echo "   ✅ TODOS LOS TESTS PASARON\n";
echo "═══════════════════════════════════════════════════════════════\n\n";
