<?php
require_once 'backend/config/database.php';

$id = 733; // One of the trips from previous debug
$db = (new Database())->getConnection();
$stmt = $db->prepare("SELECT id, estado, pago_confirmado, pago_confirmado_en FROM solicitudes_servicio WHERE id = ?");
$stmt->execute([$id]);
print_r($stmt->fetch(PDO::FETCH_ASSOC));
?>
