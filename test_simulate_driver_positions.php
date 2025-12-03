<?php
/**
 * Script de prueba para poner conductores en hotspots simulados
 * - Selecciona conductores existentes y los posiciona cerca de los hotspots
 * - Actualiza su latitud/longitud y marca como disponibles
 */

require_once 'backend/config/database.php';

echo "==========================================================\n";
echo "🧪 TEST: SIMULAR POSICIÓN DE CONDUCTORES EN HOTSPOTS\n";
echo "==========================================================\n\n";

$database = new Database();
$db = $database->getConnection();

try {
    $hotspots = [
        [4.6097, -74.0817, 500],
        [4.678, -74.061, 400],
        [4.645, -74.073, 600],
    ];

    $driversPerHotspot = 50; // # de conductores por hotspot a posicionar
    $verbose = true;

    // Obtener todos los conductores aprobados
    $stmt = $db->prepare("SELECT u.id FROM usuarios u INNER JOIN detalles_conductor dc ON u.id = dc.usuario_id WHERE u.tipo_usuario = 'conductor' AND dc.estado_verificacion = 'aprobado'");
    $stmt->execute();
    $drivers = $stmt->fetchAll(PDO::FETCH_COLUMN);

    if (count($drivers) == 0) {
        echo "❌ No hay conductores registrados en la base de datos\n";
        exit(1);
    }

    echo "Conductores disponibles: " . count($drivers) . "\n";

    function randomFloat($min, $max) {
        return $min + mt_rand() / mt_getrandmax() * ($max - $min);
    }

    function metersToLat($meters) {
        return $meters / 111000.0; // aproximación
    }

    function metersToLng($meters, $lat) {
        return $meters / (111000.0 * cos(deg2rad($lat)));
    }

    $updateStmt = $db->prepare("UPDATE detalles_conductor SET latitud_actual = ?, longitud_actual = ?, disponible = 1, ultima_actualizacion = NOW() WHERE usuario_id = ?");

    $totalUpdated = 0;

    foreach ($hotspots as $hIndex => $hotspot) {
        [$centerLat, $centerLng, $radiusMeters] = $hotspot;
        echo "\n📍 Hotspot " . ($hIndex+1) . ": lat=$centerLat, lng=$centerLng\n";

        for ($i = 0; $i < $driversPerHotspot; $i++) {
            $driverId = $drivers[array_rand($drivers)];

            $angle = randomFloat(0, 2 * M_PI);
            $distMeters = randomFloat(0, $radiusMeters);
            $latOffset = metersToLat($distMeters * sin($angle));
            $lngOffset = metersToLng($distMeters * cos($angle), $centerLat);

            $lat = $centerLat + $latOffset;
            $lng = $centerLng + $lngOffset;

            $updateStmt->execute([$lat, $lng, $driverId]);
            $totalUpdated++;

            if ($verbose && ($i % 50 == 0)) {
                echo "   ➕ Posicionado $i conductores...\n";
            }
        }

        echo "   ✅ Hotspot " . ($hIndex + 1) . ": Positioned $driversPerHotspot drivers\n";
    }

    echo "\n✅ Posicionado en total: $totalUpdated conductores\n";
    echo "\n💡 Nota: Revisar el estado de los conductores en la tabla detalles_conductor\n";

} catch (Exception $e) {
    echo "\n❌ ERROR: " . $e->getMessage() . "\n";
    echo "📍 En: " . $e->getFile() . " línea " . $e->getLine() . "\n";
    echo "\n🔍 Stack trace:\n";
    echo $e->getTraceAsString() . "\n";
}
