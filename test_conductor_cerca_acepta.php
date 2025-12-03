<?php
/**
 * Test: Crear solicitud cerca de un conductor y que éste la acepte inmediatamente
 * - Conductor usado: braianoquen2@gmail.com
 * - Cliente usado: braianoquendurango@gmail.com
 * - Crea 1 solicitud dentro de 2000m y hace que el conductor la acepte
 */
require_once 'backend/config/database.php';

$emailConductor = 'braianoquen2@gmail.com';
$emailCliente = 'braianoquendurango@gmail.com';

echo "==========================================================\n";
echo "🧪 TEST: CONDUCTOR CERCA Y ACEPTA SOLICITUD\n";
echo "==========================================================\n\n";

$db = (new Database())->getConnection();

// 1) Buscar conductor
$stmt = $db->prepare("SELECT u.id, u.email, u.nombre, dc.latitud_actual, dc.longitud_actual, dc.disponible, dc.estado_verificacion FROM usuarios u INNER JOIN detalles_conductor dc ON u.id = dc.usuario_id WHERE u.email = ?");
$stmt->execute([$emailConductor]);
$conductor = $stmt->fetch(PDO::FETCH_ASSOC);

if (!$conductor) {
    echo "⚠️ Conductor no encontrado: $emailConductor - creando conductor de prueba...\n";
    try {
        // Check if there is a user with that email
        $stmtUser = $db->prepare("SELECT id, nombre, email FROM usuarios WHERE email = ? LIMIT 1");
        $stmtUser->execute([$emailConductor]);
        $existing = $stmtUser->fetch(PDO::FETCH_ASSOC);
        if ($existing) {
            // Only add detalles_conductor for this user
            $db->beginTransaction();
            $userId = $existing['id'];
            $lat = 4.7000; $lng = -74.0700;
            
            // Update user type to 'conductor' if not already
            $stmtUpdate = $db->prepare("UPDATE usuarios SET tipo_usuario = 'conductor' WHERE id = ? AND tipo_usuario != 'conductor'");
            $stmtUpdate->execute([$userId]);
            
            // Check if detalles_conductor already exists
            $stmtCheck = $db->prepare("SELECT id FROM detalles_conductor WHERE usuario_id = ?");
            $stmtCheck->execute([$userId]);
            if (!$stmtCheck->fetch()) {
                $stmtDet = $db->prepare("INSERT INTO detalles_conductor (usuario_id, latitud_actual, longitud_actual, disponible, estado_verificacion, vehiculo_tipo, licencia_conduccion, licencia_vencimiento, vehiculo_placa) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
                $stmtDet->execute([$userId, $lat, $lng, 1, 'aprobado', 'carro', 'TEST123456', '2026-12-31', 'ABC123']);
            } else {
                // Update existing detalles
                $stmtUpd = $db->prepare("UPDATE detalles_conductor SET latitud_actual = ?, longitud_actual = ?, disponible = 1, estado_verificacion = 'aprobado' WHERE usuario_id = ?");
                $stmtUpd->execute([$lat, $lng, $userId]);
            }
            $db->commit();
            echo "   ✅ Detalles de conductor creados/actualizados para el usuario existente (ID: $userId).\n";
        } else {
            // No user exists - create full user and details
            $db->beginTransaction();
            $uuid = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x', mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000, mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff));
            $pwdHash = password_hash('pass', PASSWORD_BCRYPT);
            $stmtInsert = $db->prepare("INSERT INTO usuarios (uuid, nombre, apellido, email, telefono, hash_contrasena, tipo_usuario, es_activo) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
            $stmtInsert->execute([$uuid, 'Braiano', 'Test', $emailConductor, '+573001234567', $pwdHash, 'conductor', 1]);
            $newId = $db->lastInsertId();
            $lat = 4.7000; $lng = -74.0700;
            $stmt = $db->prepare("INSERT INTO detalles_conductor (usuario_id, latitud_actual, longitud_actual, disponible, estado_verificacion, vehiculo_tipo, licencia_conduccion, licencia_vencimiento, vehiculo_placa) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
            $stmt->execute([$newId, $lat, $lng, 1, 'aprobado', 'carro', 'TEST123456', '2026-12-31', 'ABC123']);
            $db->commit();
            echo "   ✅ Conductor de prueba creado con ID: $newId (Lat: $lat, Lng: $lng)\n";
        }
        // Recargar conductor
        $stmt = $db->prepare("SELECT u.id, u.email, u.nombre, dc.latitud_actual, dc.longitud_actual, dc.disponible, dc.estado_verificacion FROM usuarios u INNER JOIN detalles_conductor dc ON u.id = dc.usuario_id WHERE u.email = ?");
        $stmt->execute([$emailConductor]);
        $conductor = $stmt->fetch(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        if ($db->inTransaction()) $db->rollBack();
        echo "❌ ERROR creando conductor de prueba: " . $e->getMessage() . "\n";
        exit(1);
    }
}

echo "✅ Conductor encontrado: {$conductor['nombre']} (ID: {$conductor['id']}, Email: {$conductor['email']})\n";
echo "   Lat: {$conductor['latitud_actual']}, Lng: {$conductor['longitud_actual']}\n";

$conductorId = $conductor['id'];
$conductorLat = (float)$conductor['latitud_actual'];
$conductorLng = (float)$conductor['longitud_actual'];

// Forzar conductor disponible para el test
$stmt = $db->prepare("UPDATE detalles_conductor SET disponible = 1 WHERE usuario_id = ?");
$stmt->execute([$conductorId]);
echo "   ⚙️ Conductor marcado como disponible para el test.\n";

// 2) Buscar cliente específico (braianoquendurango@gmail.com)
$stmt = $db->prepare("SELECT id, nombre FROM usuarios WHERE email = ? AND es_activo = 1 LIMIT 1");
$stmt->execute([$emailCliente]);
$cliente = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$cliente) {
    echo "❌ No hay clientes. Creando uno...\n";
    $uuid = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x', mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000, mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff));
    $stmt = $db->prepare("INSERT INTO usuarios (uuid, nombre, apellido, email, telefono, hash_contrasena, tipo_usuario, es_activo) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
    $stmt->execute([$uuid, 'Cliente', 'Test', 'cliente_test_'.time().'@test.local', '+573001234567', password_hash('pass', PASSWORD_BCRYPT), 'cliente', 1]);
    $clienteId = $db->lastInsertId();
    echo "   ✅ Cliente creado con ID: $clienteId\n";
} else {
    $clienteId = $cliente['id'];
    echo "✅ Cliente existente: {$cliente['nombre']} (ID: $clienteId)\n";
}

// 3) Crear una solicitud CERCA del conductor (1 solicitud)
function metersToLat($meters) { return $meters / 111000.0; }
function metersToLng($meters, $lat) { return $meters / (111000.0 * cos(deg2rad($lat))); }
function generateUUID() { return sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x', mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000, mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)); }

$distMeters = 1000; // 1km
$angle = rand(0, 360) * M_PI / 180.0;
$latOffset = metersToLat($distMeters * sin($angle));
$lngOffset = metersToLng($distMeters * cos($angle), $conductorLat);
$latOrigen = $conductorLat + $latOffset;
$lngOrigen = $conductorLng + $lngOffset;
$latDestino = $latOrigen + metersToLat(3000); // +3km
$lngDestino = $lngOrigen + metersToLng(3000, $latOrigen);

$uuid = generateUUID();
$dirOrigen = "Prueba - Cerca y aceptar - origen";
$dirDestino = "Prueba - Cerca y aceptar - destino";

$insertStmt = $db->prepare("INSERT INTO solicitudes_servicio (
    uuid_solicitud, cliente_id, tipo_servicio,
    latitud_recogida, longitud_recogida, direccion_recogida,
    latitud_destino, longitud_destino, direccion_destino,
    distancia_estimada, tiempo_estimado, estado, fecha_creacion, solicitado_en
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())");

$distKm = 3.2; $timeMin = 12;
$insertStmt->execute([$uuid, $clienteId, 'transporte', $latOrigen, $lngOrigen, $dirOrigen, $latDestino, $lngDestino, $dirDestino, $distKm, $timeMin, 'pendiente']);
$solicitudId = $db->lastInsertId();

echo "\n✅ Solicitud creada (ID: $solicitudId) a ~1km del conductor.\n";
echo "   Origen: $latOrigen, $lngOrigen\n";
echo "   Destino: $latDestino, $lngDestino\n";

// 4) Aceptar la solicitud (usar la misma lógica del endpoint conductor/accept_trip_request.php)
try {
    $db->beginTransaction();

    // Verificar que la solicitud está pendiente
    $stmt = $db->prepare("SELECT id, estado, cliente_id, tipo_servicio FROM solicitudes_servicio WHERE id = ? FOR UPDATE");
    $stmt->execute([$solicitudId]);
    $sol = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$sol) throw new Exception("Solicitud no encontrada");
    if ($sol['estado'] !== 'pendiente') throw new Exception("Solicitud no está en estado 'pendiente' (estado: {$sol['estado']})");

    // Verificar conductor disponible y aprobado
    $stmt = $db->prepare("SELECT u.id, dc.disponible, dc.vehiculo_tipo FROM usuarios u INNER JOIN detalles_conductor dc ON u.id = dc.usuario_id WHERE u.id = ? AND u.tipo_usuario = 'conductor' AND dc.estado_verificacion = 'aprobado'");
    $stmt->execute([$conductorId]);
    $cd = $stmt->fetch(PDO::FETCH_ASSOC);
    if (!$cd) throw new Exception("Conductor no encontrado o no verificado");
    if (!$cd['disponible']) throw new Exception("Conductor no disponible para aceptar");

    // Actualizar solicitud
    $stmt = $db->prepare("UPDATE solicitudes_servicio SET estado = 'aceptada', aceptado_en = NOW() WHERE id = ?");
    $stmt->execute([$solicitudId]);

    // Insertar asignación
    $stmt = $db->prepare("INSERT INTO asignaciones_conductor (solicitud_id, conductor_id, asignado_en, estado) VALUES (?, ?, NOW(), 'asignado')");
    $stmt->execute([$solicitudId, $conductorId]);

    // Marcar conductor no disponible
    $stmt = $db->prepare("UPDATE detalles_conductor SET disponible = 0 WHERE usuario_id = ?");
    $stmt->execute([$conductorId]);

    $db->commit();
    echo "\n🚗 Solicitud aceptada por conductor (ID: $conductorId) ✅\n";
    echo "   Asignación creada y conductor marcado como no disponible.\n";

} catch (Exception $e) {
    if ($db->inTransaction()) $db->rollBack();
    echo "\n❌ ERROR al aceptar solicitud: " . $e->getMessage() . "\n";
    exit(1);
}

// 5) Validar cambios
$stmt = $db->prepare("SELECT estado, aceptado_en FROM solicitudes_servicio WHERE id = ?");
$stmt->execute([$solicitudId]);
$rows = $stmt->fetch(PDO::FETCH_ASSOC);
echo "\n📋 Estado de la solicitud: {$rows['estado']} (aceptado_en: {$rows['aceptado_en']})\n";

$stmt = $db->prepare("SELECT disponible FROM detalles_conductor WHERE usuario_id = ?");
$stmt->execute([$conductorId]);
$dis = $stmt->fetch(PDO::FETCH_ASSOC);
echo "📋 Disponibilidad del conductor: " . ($dis['disponible'] ? 'Sí' : 'No') . "\n";

echo "\n==========================================================\n";
echo "✅ TEST COMPLETADO: Conductor aceptó la solicitud correctamente.\n";
echo "==========================================================\n";

?>
