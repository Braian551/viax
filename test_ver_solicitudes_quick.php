<?php
require_once 'backend/config/database.php';

try {
    $db = (new Database())->getConnection();
    $stmt = $db->prepare('SELECT id, uuid_solicitud, estado, fecha_creacion, latitud_recogida, longitud_recogida, direccion_recogida FROM solicitudes_servicio WHERE direccion_recogida LIKE ? ORDER BY fecha_creacion DESC LIMIT 10');
    $stmt->execute(['%Prueba%']);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo "Últimas solicitudes con 'Prueba' en la dirección:\n";
    foreach ($rows as $r) {
        echo sprintf("ID: %s | Estado: %s | Fecha: %s | Direc: %s | Lat: %s | Lng: %s\n",
            $r['id'], $r['estado'], $r['fecha_creacion'], $r['direccion_recogida'], $r['latitud_recogida'], $r['longitud_recogida']);
    }

} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
}
