<?php
require_once 'backend/config/database.php';

$database = new Database();
$db = $database->getConnection();

try {
    // Eliminar restricción antigua
    $db->exec('ALTER TABLE asignaciones_conductor DROP CONSTRAINT asignaciones_conductor_estado_check');
    echo "Restriccion antigua eliminada\n";
    
    // Crear nueva restricción con todos los estados
    $db->exec("ALTER TABLE asignaciones_conductor ADD CONSTRAINT asignaciones_conductor_estado_check CHECK (estado IN ('asignado', 'llegado', 'en_curso', 'completado', 'cancelado'))");
    echo "Nueva restriccion creada con estados: asignado, llegado, en_curso, completado, cancelado\n";
    
    echo "\nListo!\n";
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
