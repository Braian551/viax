<?php
require_once 'backend/config/database.php';

$db = (new Database())->getConnection();
$stmt = $db->query("SELECT latitud, longitud, distancia_acumulada_km, tiempo_transcurrido_seg, precio_parcial, timestamp_gps FROM viaje_tracking_realtime WHERE solicitud_id = 745 ORDER BY timestamp_gps LIMIT 10");
$points = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Puntos de tracking para solicitud 745:\n\n";
foreach ($points as $i => $point) {
    echo "Punto #" . ($i + 1) . ":\n";
    echo "  Lat/Lng: {$point['latitud']}, {$point['longitud']}\n";
    echo "  Distancia acumulada: {$point['distancia_acumulada_km']} km\n";
    echo "  Tiempo transcurrido: {$point['tiempo_transcurrido_seg']} seg\n";
    echo "  Precio parcial: {$point['precio_parcial']}\n";
    echo "  Timestamp: {$point['timestamp_gps']}\n\n";
}
