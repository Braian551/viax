<?php
/**
 * Activar disponibilidad de Oscar (ID 277) para pruebas
 */

require_once __DIR__ . '/backend/config/database.php';

try {
    $database = new Database();
    $db = $database->getConnection();
    
    // Activar disponibilidad
    $stmt = $db->prepare("UPDATE detalles_conductor SET disponible = 1 WHERE usuario_id = 277");
    $stmt->execute();
    
    echo "✅ Oscar (ID 277) ahora está DISPONIBLE\n";
    echo "   Filas actualizadas: " . $stmt->rowCount() . "\n";
    
    // Verificar
    $stmt = $db->prepare("SELECT disponible, latitud_actual, longitud_actual FROM detalles_conductor WHERE usuario_id = 277");
    $stmt->execute();
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo "\n📍 Estado actual:\n";
    echo "   Disponible: " . ($result['disponible'] ? 'Sí ✅' : 'No ❌') . "\n";
    echo "   Ubicación: {$result['latitud_actual']}, {$result['longitud_actual']}\n";
    
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
}
