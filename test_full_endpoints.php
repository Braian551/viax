<?php
// Mock $_GET parameters
$_GET['usuario_id'] = 276;
$_GET['page'] = 1;
$_GET['limit'] = 20;

// Capture output of trip history
echo "--- TRIP HISTORY TEST ---\n";
ob_start();
try {
    include 'backend/user/get_trip_history.php';
} catch (Throwable $e) {
    echo "FATAL ERROR: " . $e->getMessage();
}
$history_output = ob_get_clean();
echo $history_output;
echo "\n";

// Decode to check validity
$json = json_decode($history_output, true);
if ($json === null) {
    echo "INVALID JSON IN HISTORY!\n";
} else {
    echo "Permissions/Success: " . ($json['success'] ? 'TRUE' : 'FALSE') . "\n";
    echo "Viajes count: " . count($json['viajes'] ?? []) . "\n";
}

echo "\n--- PAYMENT SUMMARY TEST ---\n";
// Reset/Set Params
$_GET['usuario_id'] = 276;
unset($_GET['page']);
unset($_GET['limit']);

ob_start();
try {
    include 'backend/user/get_payment_summary.php';
} catch (Throwable $e) {
    echo "FATAL ERROR: " . $e->getMessage();
}
$summary_output = ob_get_clean();
echo $summary_output;
echo "\n";

$json_summary = json_decode($summary_output, true);
if ($json_summary === null) {
    echo "INVALID JSON IN SUMMARY!\n";
} else {
    echo "Success: " . ($json_summary['success'] ? 'TRUE' : 'FALSE') . "\n";
    echo "Total Viajes: " . ($json_summary['total_viajes'] ?? 'N/A') . "\n";
}
?>
