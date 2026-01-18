<?php
require_once 'backend/config/database.php';

$db = (new Database())->getConnection();

$solicitud_id = 745;

// Verificar el estado actual de la asignación
$stmt = $db->prepare("SELECT * FROM asignaciones_conductor WHERE solicitud_id = ?");
$stmt->execute([$solicitud_id]);
$asig = $stmt->fetch(PDO::FETCH_ASSOC);

echo "Asignación para solicitud $solicitud_id:\n";
print_r($asig);

// Verificar el estado de la solicitud
$stmt = $db->prepare("SELECT id, estado, conductor_id FROM solicitudes_servicio WHERE id = ?");
$stmt->execute([$solicitud_id]);
$sol = $stmt->fetch(PDO::FETCH_ASSOC);

echo "\nSolicitud:\n";
print_r($sol);
