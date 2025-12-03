<?php
// Probar solicitud 586
$_GET['solicitud_id'] = 586;
$_SERVER['REQUEST_METHOD'] = 'GET';
chdir('backend/user');
ob_start();
include 'get_trip_status.php';
echo ob_get_clean();
