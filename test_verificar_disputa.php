<?php
/**
 * Test: Verificar si un usuario tiene disputa activa
 * 
 * Uso: php test_verificar_disputa.php [usuario_id]
 */

$usuarioId = $argv[1] ?? null;

if (!$usuarioId) {
    echo "❌ Uso: php test_verificar_disputa.php [usuario_id]\n";
    echo "Ejemplo: php test_verificar_disputa.php 456\n";
    exit(1);
}

$url = "https://viax-backend-production.up.railway.app/payment/check_dispute_status.php?usuario_id=$usuarioId";

echo "🧪 Test: Verificar disputa activa\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "👤 Usuario ID: $usuarioId\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$ch = curl_init($url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "📡 Respuesta del servidor:\n";
echo "HTTP Code: $httpCode\n\n";

$result = json_decode($response, true);
echo json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n\n";

if (isset($result['tiene_disputa']) && $result['tiene_disputa']) {
    echo "🔒 CUENTA BLOQUEADA - Disputa activa\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    
    $disputa = $result['disputa'] ?? [];
    
    if (isset($disputa['tipo_usuario'])) {
        echo "📋 Tipo de usuario: " . $disputa['tipo_usuario'] . "\n";
    }
    
    if (isset($disputa['viaje'])) {
        $viaje = $disputa['viaje'];
        echo "🚗 Viaje en disputa:\n";
        echo "   • Solicitud ID: " . ($viaje['solicitud_id'] ?? 'N/A') . "\n";
        echo "   • Origen: " . ($viaje['origen'] ?? 'N/A') . "\n";
        echo "   • Destino: " . ($viaje['destino'] ?? 'N/A') . "\n";
        echo "   • Precio: $" . ($viaje['precio'] ?? '0') . "\n";
    }
    
    if (isset($disputa['otra_parte'])) {
        $otra = $disputa['otra_parte'];
        echo "👥 La otra parte:\n";
        echo "   • Nombre: " . ($otra['nombre'] ?? 'N/A') . "\n";
        echo "   • Teléfono: " . ($otra['telefono'] ?? 'N/A') . "\n";
    }
    
    if (isset($disputa['cliente_confirma_pago'])) {
        echo "\n💰 Estados de confirmación:\n";
        echo "   • Cliente dice pagó: " . ($disputa['cliente_confirma_pago'] ? '✅ SÍ' : '❌ NO') . "\n";
        echo "   • Conductor dice recibió: " . ($disputa['conductor_confirma_recibo'] ? '✅ SÍ' : '❌ NO') . "\n";
    }
    
} else {
    echo "✅ NO HAY DISPUTA ACTIVA\n";
    echo "Usuario puede usar la app normalmente\n";
}
