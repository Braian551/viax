<?php
require __DIR__ . '/../backend/config/database.php';

$invoiceNumber = $argv[1] ?? 'VIAX-EA-000001';
$db = (new Database())->getConnection();
$stmt = $db->prepare("SELECT numero_factura, emisor_nombre, emisor_documento, emisor_email, pago_referencia_tipo, pdf_ruta FROM facturas WHERE numero_factura = :n LIMIT 1");
$stmt->execute([':n' => $invoiceNumber]);
$row = $stmt->fetch(PDO::FETCH_ASSOC);
echo json_encode($row, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT) . PHP_EOL;
