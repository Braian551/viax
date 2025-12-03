<?php
// Simular llamada al endpoint
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Cambiar al directorio del backend
chdir('backend/user');

$_GET['solicitud_id'] = 584;
$_SERVER['REQUEST_METHOD'] = 'GET';

ob_start();
include 'get_trip_status.php';
$output = ob_get_clean();

echo $output;
