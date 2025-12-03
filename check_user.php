<?php
require_once 'backend/config/database.php';
$db = (new Database())->getConnection();

echo "=== Conductor (braianoquen2@gmail.com) ===\n";
$stmt = $db->prepare('SELECT u.id, u.tipo_usuario, u.email, dc.estado_verificacion, dc.disponible, dc.latitud_actual, dc.longitud_actual FROM usuarios u LEFT JOIN detalles_conductor dc ON u.id = dc.usuario_id WHERE u.email = ?');
$stmt->execute(['braianoquen2@gmail.com']);
print_r($stmt->fetch(PDO::FETCH_ASSOC));

echo "\n=== Cliente (braianoquendurango@gmail.com) ===\n";
$stmt->execute(['braianoquendurango@gmail.com']);
print_r($stmt->fetch(PDO::FETCH_ASSOC));
