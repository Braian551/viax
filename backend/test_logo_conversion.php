<?php
require_once 'config/database.php';

$db = new Database();
$conn = $db->getConnection();

// Simular la función convertLogoUrl
function convertLogoUrl($logoUrl) {
    if (empty($logoUrl)) return null;
    
    if (strpos($logoUrl, 'r2_proxy.php') !== false) {
        return $logoUrl;
    }
    
    if (strpos($logoUrl, 'r2.dev/') !== false) {
        $parts = explode('r2.dev/', $logoUrl);
        $logoUrl = end($parts);
    }
    
    if (strpos($logoUrl, 'http://') === 0 || strpos($logoUrl, 'https://') === 0) {
        return $logoUrl;
    }
    
    // Usar IP del servidor
    return 'http://192.168.18.68/viax/backend/r2_proxy.php?key=' . urlencode($logoUrl);
}

$stmt = $conn->query('SELECT id, nombre, logo_url FROM empresas_transporte ORDER BY id');
$empresas = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "=== Logos en DB vs URL Convertida ===\n\n";
foreach ($empresas as $e) {
    $original = $e['logo_url'] ?? '(null)';
    $converted = convertLogoUrl($e['logo_url']);
    echo $e['nombre'] . ":\n";
    echo "  Original:  " . $original . "\n";
    echo "  Convertida: " . ($converted ?? '(null)') . "\n\n";
}
