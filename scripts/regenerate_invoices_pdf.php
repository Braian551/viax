<?php
require __DIR__ . '/../backend/config/database.php';
require __DIR__ . '/../backend/admin/generate_invoice_pdf.php';

try {
    $db = (new Database())->getConnection();
    $stmt = $db->query("SELECT id, numero_factura, pdf_ruta FROM facturas WHERE pdf_ruta IS NULL OR pdf_ruta LIKE '%.html' ORDER BY id DESC LIMIT 200");
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    if (!$rows) {
        echo "NO_HTML_INVOICES\n";
        exit(0);
    }

    foreach ($rows as $row) {
        $facturaId = (int) ($row['id'] ?? 0);
        $numero = (string) ($row['numero_factura'] ?? ('FACTURA_' . $facturaId));

        $result = generateInvoicePdf($db, $facturaId);
        if (!$result || empty($result['pdf_path'])) {
            echo "FAIL {$facturaId} {$numero}\n";
            continue;
        }

        $update = $db->prepare('UPDATE facturas SET pdf_ruta = :ruta WHERE id = :id');
        $update->execute([
            ':ruta' => $result['pdf_path'],
            ':id' => $facturaId,
        ]);

        echo "OK {$facturaId} {$numero} -> {$result['pdf_path']}\n";
    }
} catch (Throwable $e) {
    fwrite(STDERR, 'ERROR: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}
