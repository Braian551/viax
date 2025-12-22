<?php
/**
 * Test: Crear una disputa completa
 * Simula el escenario: Cliente dice "pagué" pero Conductor dice "no recibí"
 * 
 * Uso: php test_crear_disputa.php [solicitud_id] [cliente_id] [conductor_id]
 */

$solicitudId = $argv[1] ?? null;
$clienteId = $argv[2] ?? null;
$conductorId = $argv[3] ?? null;

if (!$solicitudId || !$clienteId || !$conductorId) {
    echo "❌ Uso: php test_crear_disputa.php [solicitud_id] [cliente_id] [conductor_id]\n";
    echo "Ejemplo: php test_crear_disputa.php 123 456 789\n";
    exit(1);
}

$url = 'https://viax-backend-production.up.railway.app/payment/report_payment_status.php';

echo "🧪 Test: Crear Disputa (Desacuerdo en pago)\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "📍 Solicitud ID: $solicitudId\n";
echo "👤 Cliente ID: $clienteId\n";
echo "🚗 Conductor ID: $conductorId\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

// PASO 1: Cliente confirma que SÍ pagó
echo "1️⃣  CLIENTE confirma: 'SÍ PAGUÉ'\n";
echo "   ⏳ Enviando...\n";

$dataCliente = [
    'solicitud_id' => $solicitudId,
    'usuario_id' => $clienteId,
    'tipo_usuario' => 'cliente',
    'confirma_pago' => true
];

$ch = curl_init($url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($dataCliente));
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
$response1 = curl_exec($ch);
curl_close($ch);

$result1 = json_decode($response1, true);
echo "   ✓ Respuesta: " . ($result1['message'] ?? 'OK') . "\n\n";

sleep(1);

// PASO 2: Conductor confirma que NO recibió
echo "2️⃣  CONDUCTOR reporta: 'NO RECIBÍ EL PAGO'\n";
echo "   ⏳ Enviando...\n";

$dataConductor = [
    'solicitud_id' => $solicitudId,
    'usuario_id' => $conductorId,
    'tipo_usuario' => 'conductor',
    'confirma_pago' => false
];

$ch = curl_init($url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($dataConductor));
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
$response2 = curl_exec($ch);
curl_close($ch);

$result2 = json_decode($response2, true);

echo "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "📊 RESULTADO FINAL\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n";

echo json_encode($result2, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n\n";

if (isset($result2['disputa_creada']) && $result2['disputa_creada']) {
    echo "🔥 ¡DISPUTA CREADA!\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    echo "⚠️  CONFLICTO DETECTADO:\n";
    echo "   • Cliente dice: 'SÍ pagué el efectivo'\n";
    echo "   • Conductor dice: 'NO recibí el pago'\n\n";
    echo "🔒 CONSECUENCIAS:\n";
    echo "   • Ambas cuentas SUSPENDIDAS\n";
    echo "   • No pueden usar la app hasta resolver\n";
    echo "   • Conductor puede resolver confirmando pago\n\n";
    
    if (isset($result2['disputa_id'])) {
        echo "📋 Disputa ID: " . $result2['disputa_id'] . "\n";
    }
} else {
    echo "❌ No se creó disputa (algo salió mal)\n";
}

echo "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
