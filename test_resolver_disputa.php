<?php
/**
 * Test: Resolver una disputa (conductor confirma que sí recibió el pago)
 * 
 * Uso: php test_resolver_disputa.php [solicitud_id] [conductor_id]
 */

$solicitudId = $argv[1] ?? null;
$conductorId = $argv[2] ?? null;

if (!$solicitudId || !$conductorId) {
    echo "❌ Uso: php test_resolver_disputa.php [solicitud_id] [conductor_id]\n";
    echo "Ejemplo: php test_resolver_disputa.php 123 789\n";
    exit(1);
}

$url = 'https://viax-backend-production.up.railway.app/payment/resolve_dispute.php';

$data = [
    'solicitud_id' => $solicitudId,
    'conductor_id' => $conductorId
];

echo "🧪 Test: Resolver Disputa\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "📍 Solicitud ID: $solicitudId\n";
echo "🚗 Conductor ID: $conductorId\n";
echo "✅ Conductor confirma: 'YA RECIBÍ EL PAGO'\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

$ch = curl_init($url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json'
]);

$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

echo "📡 Respuesta del servidor:\n";
echo "HTTP Code: $httpCode\n\n";

$result = json_decode($response, true);
echo json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n\n";

if (isset($result['success']) && $result['success']) {
    echo "✅ DISPUTA RESUELTA\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    echo "🔓 Ambas cuentas desbloqueadas\n";
    echo "✓ Conductor confirmó que recibió el pago\n";
    echo "✓ Cliente y conductor pueden usar la app\n";
} else {
    echo "❌ Error al resolver disputa\n";
    echo "Mensaje: " . ($result['message'] ?? 'Desconocido') . "\n";
}
