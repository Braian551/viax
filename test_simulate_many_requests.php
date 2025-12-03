<?php
/**
 * Script de prueba para simular muchas solicitudes en múltiples hotspots
 * - Usa usuarios existentes (clientes), y crea nuevos si no hay suficientes
 * - Inserta múltiples solicitudes por hotspot con coordenadas aleatorias alrededor del centro
 * - Marca las solicitudes con 'Prueba - Hotspot' en la direccion para limpieza fácil
 *
 * Uso: php test_simulate_many_requests.php
 */

require_once 'backend/config/database.php';

echo "==========================================================\n";
echo "🧪 TEST: SIMULAR MUCHAS SOLICITUDES EN HOTSPOTS\n";
echo "==========================================================\n\n";

$database = new Database();
$db = $database->getConnection();

try {
    // ===============================
    // CONFIGURACIÓN
    // ===============================
    // Hotspots a simular (lat, lng, radius_meters)
    $hotspots = [
        [4.6097, -74.0817, 800], // Bogotá centro (ejemplo)
        [4.678, -74.061, 600], // Zona 2
        [4.645, -74.073, 700], // Zona 3
    ];

    $requestsPerHotspot = 150; // Cantidad total de solicitudes por hotspot
    $clientsPerHotspot = 80;   // Usuarios (clientes) por hotspot - si no hay suficientes, se crean
    $createClientsIfNotEnough = true; // Crear nuevos clientes si no hay suficientes
    $verbose = true; // Mostrar progreso
    
    echo "Configuración: " . count($hotspots) . " hotspots, $requestsPerHotspot requests/hotspot, $clientsPerHotspot clients/hotspot\n\n";

    // ===============================
    // Obtener clientes existentes
    // ===============================
    $stmt = $db->prepare("SELECT id FROM usuarios WHERE tipo_usuario = 'cliente' AND es_activo = 1");
    $stmt->execute();
    $clientes = $stmt->fetchAll(PDO::FETCH_COLUMN);

    echo "Clientes existentes: " . count($clientes) . "\n";

    // Funciones auxiliares
    function randomFloat($min, $max) {
        return $min + mt_rand() / mt_getrandmax() * ($max - $min);
    }

    function metersToLat($meters) {
        return $meters / 111000.0; // aproximación
    }

    function metersToLng($meters, $lat) {
        return $meters / (111000.0 * cos(deg2rad($lat)));
    }

    function generateUUID() {
        return sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            mt_rand(0, 0xffff), mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0x0fff) | 0x4000,
            mt_rand(0, 0x3fff) | 0x8000,
            mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
        );
    }

    // Inserción preparada
    $insertStmt = $db->prepare("INSERT INTO solicitudes_servicio (
        uuid_solicitud,
        cliente_id,
        tipo_servicio,
        latitud_recogida,
        longitud_recogida,
        direccion_recogida,
        latitud_destino,
        longitud_destino,
        direccion_destino,
        distancia_estimada,
        tiempo_estimado,
        estado,
        fecha_creacion,
        solicitado_en
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())");

    // =======================================
    // Loop para crear solicitudes por hotspot
    // =======================================
    $totalCreated = 0;

    foreach ($hotspots as $hIndex => $hotspot) {
        list($centerLat, $centerLng, $radiusMeters) = $hotspot;

        echo "\n🏙️  Hotspot #" . ($hIndex + 1) . ": lat=$centerLat, lng=$centerLng, radius={$radiusMeters}m\n";

        // Reusar clientes del segmento actual (si existen), o crear clientes nuevos
        $clientsForHotspot = [];

        // take slice of existing clients
        $startIndex = ($hIndex * $clientsPerHotspot) % max(1, count($clientes));
        $takeCount = min($clientsPerHotspot, count($clientes));
        if ($takeCount > 0 && count($clientes) > 0) {
            for ($i=0; $i < $takeCount; $i++) {
                $clientsForHotspot[] = $clientes[($startIndex + $i) % count($clientes)];
            }
        }

        // Crear clientes si faltan
        if ($createClientsIfNotEnough && count($clientsForHotspot) < $clientsPerHotspot) {
            $toCreate = $clientsPerHotspot - count($clientsForHotspot);
            echo "   ➕ Creando $toCreate clientes nuevos para este hotspot...\n";

            for ($c = 0; $c < $toCreate; $c++) {
                $uuidUsr = generateUUID();
                $nombre = 'ClienteHot';
                $apellido = 'Test' . ($hIndex+1);
                $email = 'cliente_hot_' . ($hIndex+1) . '_' . time() . '_' . $c . '@test.local';
                $telefono = '+500' . mt_rand(1000000,9999999);

                $stmt = $db->prepare("INSERT INTO usuarios (uuid, nombre, apellido, email, telefono, hash_contrasena, tipo_usuario, es_activo) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
                $stmt->execute([$uuidUsr, $nombre, $apellido, $email, $telefono, password_hash('password', PASSWORD_BCRYPT), 'cliente', 1]);
                $newId = $db->lastInsertId();
                $clientsForHotspot[] = $newId;
            }

            echo "   ✅ Clientes creados: " . ($toCreate) . "\n";
        }

        // Si aún no hay clientes (muy raro), abortar
        if (count($clientsForHotspot) == 0) {
            echo "   ⚠️ No hay clientes disponibles para este hotspot, saltando...\n";
            continue;
        }

        // Crear solicitudes
        for ($r = 0; $r < $requestsPerHotspot; $r++) {
            // Elegir cliente aleatorio
            $clienteId = $clientsForHotspot[array_rand($clientsForHotspot)];

            // Generar un punto de origen aleatorio dentro del radio
            $angle = randomFloat(0, 2 * M_PI);
            $distMeters = randomFloat(20, $radiusMeters); // 20m - radius
            $offsetLat = metersToLat($distMeters * sin($angle));
            $offsetLng = metersToLng($distMeters * cos($angle), $centerLat);
            $latOrigen = $centerLat + $offsetLat;
            $lngOrigen = $centerLng + $offsetLng;

            // Destino dentro de 1-6 km del origen (no siempre dentro del hotspot)
            $destAngle = randomFloat(0, 2 * M_PI);
            $destDist = randomFloat(800, 6000); // m
            $offsetLatDest = metersToLat($destDist * sin($destAngle));
            $offsetLngDest = metersToLng($destDist * cos($destAngle), $latOrigen);
            $latDestino = $latOrigen + $offsetLatDest;
            $lngDestino = $lngOrigen + $offsetLngDest;

            // Variables: distancia y tiempo estimado aproximado
            $distanceKm = round(randomFloat(0.5, 7.0), 2);
            $timeMinutes = round(max(1, $distanceKm * randomFloat(3, 6)));

            $uuid = generateUUID();

            $direccionOrigen = "Prueba - Hotspot {$hIndex} - Origen $r";
            $direccionDestino = "Prueba - Hotspot {$hIndex} - Destino $r";

            $insertStmt->execute([
                $uuid,
                $clienteId,
                'transporte',
                $latOrigen,
                $lngOrigen,
                $direccionOrigen,
                $latDestino,
                $lngDestino,
                $direccionDestino,
                $distanceKm,
                $timeMinutes,
                'pendiente',
            ]);

            $totalCreated++;

            if ($verbose && ($r % 50 == 0)) {
                echo "   ➕ Insertadas " . ($r + 1) . " solicitudes para hotspot " . ($hIndex+1) . "...\n";
            }
        }

        echo "   ✅ Hotspot " . ($hIndex+1) . ": se insertaron $requestsPerHotspot solicitudes.\n";
    }

    echo "\n✅ Inserción completada. Total de solicitudes creadas: $totalCreated\n";
    echo "\n💡 Nota: Puedes limpiar estas solicitudes con el script test_limpiar_solicitudes.php (opción 8 busca 'Prueba' en direcciones).\n";

} catch (Exception $e) {
    echo "\n❌ ERROR: " . $e->getMessage() . "\n";
    echo "📍 En: " . $e->getFile() . " línea " . $e->getLine() . "\n";
    echo "\n🔍 Stack trace:\n";
    echo $e->getTraceAsString() . "\n";
}
