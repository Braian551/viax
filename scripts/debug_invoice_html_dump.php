<?php
require __DIR__ . '/../backend/config/database.php';
require __DIR__ . '/../backend/admin/generate_invoice_pdf.php';

$invoiceNumber = $argv[1] ?? 'VIAX-EA-000001';
$db = (new Database())->getConnection();
$stmt = $db->prepare('SELECT * FROM facturas WHERE numero_factura = :n LIMIT 1');
$stmt->execute([':n' => $invoiceNumber]);
$factura = $stmt->fetch(PDO::FETCH_ASSOC);
if (!$factura) {
    fwrite(STDERR, "No factura\n");
    exit(1);
}
if (($factura['receptor_tipo'] ?? '') === 'empresa' && !empty($factura['receptor_id'])) {
    $stmtLogo = $db->prepare("SELECT logo_url FROM empresas_transporte WHERE id = :id LIMIT 1");
    $stmtLogo->execute([':id' => intval($factura['receptor_id'])]);
    $logo = $stmtLogo->fetchColumn();
    if (!empty($logo)) {
        $factura['receptor_logo_url'] = $logo;
    }
}
$html = buildInvoiceHtml($factura);
file_put_contents(__DIR__ . '/invoice_debug_output.html', $html);
$pos = stripos($html, '<h3>Receptor</h3>');
if ($pos !== false) {
    echo substr($html, $pos, 900) . PHP_EOL;
}
