<?php
/**
 * Script para obtener ubicación del conductor y crear solicitudes CERCA de él
 */
require_once 'backend/config/database.php';

$emailConductor = 'braianoquen2@gmail.com';

echo "==========================================================\n";
echo "🧪 BUSCAR CONDUCTOR Y CREAR SOLICITUDES CERCA\n";
echo "==========================================================\n\n";

$db = (new Database())->getConnection();

// 1. Buscar conductor
$stmt = $db->prepare("
    SELECT u.id, u.email, u.nombre, dc.latitud_actual, dc.longitud_actual, dc.disponible, dc.estado_verificacion 
    FROM usuarios u 
    INNER JOIN detalles_conductor dc ON u.id = dc.usuario_id 
    WHERE u.email = ?
");
$stmt->execute([$emailConductor]);
$conductor = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$conductor) {
    echo "❌ Conductor no encontrado: $emailConductor\n";
    exit(1);
}

echo "✅ Conductor encontrado:\n";
echo "   ID: {$conductor['id']}\n";
echo "   Email: {$conductor['email']}\n";
echo "   Nombre: {$conductor['nombre']}\n";
echo "   Lat: {$conductor['latitud_actual']}\n";
echo "   Lng: {$conductor['longitud_actual']}\n";
echo "   Disponible: " . ($conductor['disponible'] ? 'Sí' : 'No') . "\n";
echo "   Estado: {$conductor['estado_verificacion']}\n\n";

// Guardar ubicación
$conductorLat = (float)$conductor['latitud_actual'];
$conductorLng = (float)$conductor['longitud_actual'];

// 2. Buscar un cliente existente
$stmt = $db->prepare("SELECT id, nombre FROM usuarios WHERE tipo_usuario = 'cliente' AND es_activo = 1 LIMIT 1");
$stmt->execute();
$cliente = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$cliente) {
    echo "❌ No hay clientes. Creando uno...\n";
    $uuid = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff));
    $stmt = $db->prepare("INSERT INTO usuarios (uuid, nombre, apellido, email, telefono, hash_contrasena, tipo_usuario, es_activo) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
    $stmt->execute([$uuid, 'Cliente', 'Test', 'cliente_test_'.time().'@test.local', '+573001234567', password_hash('pass', PASSWORD_BCRYPT), 'cliente', 1]);
    $clienteId = $db->lastInsertId();
    echo "   ✅ Cliente creado con ID: $clienteId\n";
} else {
    $clienteId = $cliente['id'];
    echo "✅ Cliente existente: {$cliente['nombre']} (ID: $clienteId)\n";
}

// 3. Limpiar solicitudes de prueba antiguas cerca del conductor
echo "\n🧹 Limpiando solicitudes de prueba anteriores...\n";
$stmt = $db->prepare("DELETE FROM solicitudes_servicio WHERE direccion_recogida LIKE '%Prueba - Cerca Conductor%'");
$stmt->execute();
$deleted = $stmt->rowCount();
echo "   Eliminadas: $deleted solicitudes\n";

// 4. Crear solicitudes CERCA del conductor (dentro de 3km)
echo "\n📍 Creando solicitudes cerca del conductor...\n";

$numSolicitudes = 10;
$radiusMeters = 2000; // 2km

function randomFloat($min, $max) {
    return $min + mt_rand() / mt_getrandmax() * ($max - $min);
}

function metersToLat($meters) {
    return $meters / 111000.0;
}

function metersToLng($meters, $lat) {
    return $meters / (111000.0 * cos(deg2rad($lat)));
}

function generateUUID() {
    return sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff),
        mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000,
        mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff));
}

$insertStmt = $db->prepare("INSERT INTO solicitudes_servicio (
    uuid_solicitud, cliente_id, tipo_servicio,
    latitud_recogida, longitud_recogida, direccion_recogida,
    latitud_destino, longitud_destino, direccion_destino,
    distancia_estimada, tiempo_estimado, estado, fecha_creacion, solicitado_en
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())");

for ($i = 0; $i < $numSolicitudes; $i++) {
    // Generar punto de origen CERCA del conductor
    $angle = randomFloat(0, 2 * M_PI);
    $dist = randomFloat(100, $radiusMeters); // 100m - 2km
    $latOffset = metersToLat($dist * sin($angle));
    $lngOffset = metersToLng($dist * cos($angle), $conductorLat);
    
    $latOrigen = $conductorLat + $latOffset;
    $lngOrigen = $conductorLng + $lngOffset;
    
    // Destino a 1-5km del origen
    $destAngle = randomFloat(0, 2 * M_PI);
    $destDist = randomFloat(1000, 5000);
    $latDestino = $latOrigen + metersToLat($destDist * sin($destAngle));
    $lngDestino = $lngOrigen + metersToLng($destDist * cos($destAngle), $latOrigen);
    
    $distKm = round(randomFloat(1, 6), 2);
    $timeMin = round($distKm * randomFloat(3, 5));
    
    $uuid = generateUUID();
    $dirOrigen = "Prueba - Cerca Conductor #$i";
    $dirDestino = "Destino Test #$i";
    
    $insertStmt->execute([
        $uuid, $clienteId, 'transporte',
        $latOrigen, $lngOrigen, $dirOrigen,
        $latDestino, $lngDestino, $dirDestino,
        $distKm, $timeMin, 'pendiente'
    ]);
    
    $distFromConductor = sqrt(pow(($latOrigen - $conductorLat) * 111000, 2) + pow(($lngOrigen - $conductorLng) * 111000 * cos(deg2rad($conductorLat)), 2));
    echo "   ✅ Solicitud #$i: " . round($distFromConductor) . "m del conductor (Lat: " . round($latOrigen, 5) . ", Lng: " . round($lngOrigen, 5) . ")\n";
}

echo "\n✅ Creadas $numSolicitudes solicitudes DENTRO del radio de búsqueda (5km)\n";

// 5. Verificar que el conductor las puede ver
echo "\n🔍 Verificando visibilidad desde el conductor...\n";

$radioKm = 5.0;
$stmt = $db->prepare("
    SELECT 
        id, direccion_recogida,
        (6371 * acos(
            cos(radians(?)) * cos(radians(latitud_recogida)) *
            cos(radians(longitud_recogida) - radians(?)) +
            sin(radians(?)) * sin(radians(latitud_recogida))
        )) AS distancia_km
    FROM solicitudes_servicio
    WHERE estado = 'pendiente'
    AND direccion_recogida LIKE '%Prueba - Cerca Conductor%'
    AND (6371 * acos(
        cos(radians(?)) * cos(radians(latitud_recogida)) *
        cos(radians(longitud_recogida) - radians(?)) +
        sin(radians(?)) * sin(radians(latitud_recogida))
    )) <= ?
    ORDER BY distancia_km ASC
");
$stmt->execute([
    $conductorLat, $conductorLng, $conductorLat,
    $conductorLat, $conductorLng, $conductorLat,
    $radioKm
]);
$visibles = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "   📊 Solicitudes visibles para el conductor: " . count($visibles) . "\n";
foreach ($visibles as $v) {
    echo "      - ID {$v['id']}: " . round($v['distancia_km'], 2) . " km - {$v['direccion_recogida']}\n";
}

echo "\n==========================================================\n";
echo "✅ LISTO! El conductor debería ver estas solicitudes en la app\n";
echo "==========================================================\n";
echo "💡 Si aún hay error de conexión, verifica:\n";
echo "   1. Que el backend esté corriendo (Laravel/PHP)\n";
echo "   2. La URL del backend en app_config.dart\n";
echo "   3. Que el dispositivo tenga conexión a internet\n";
