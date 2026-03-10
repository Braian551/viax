<?php
require __DIR__ . '/../backend/config/database.php';
require __DIR__ . '/../backend/admin/generate_invoice_pdf.php';

$invoiceNumber = $argv[1] ?? 'VIAX-EA-000001';

try {
    $db = (new Database())->getConnection();
    $stmt = $db->prepare('SELECT id, numero_factura FROM facturas WHERE numero_factura = :n LIMIT 1');
    $stmt->execute([':n' => $invoiceNumber]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        fwrite(STDERR, "NOT_FOUND {$invoiceNumber}\n");
        exit(1);
    }

    $id = (int)$row['id'];
    $result = generateInvoicePdf($db, $id);

    if (!$result || empty($result['pdf_path'])) {
        fwrite(STDERR, "FAILED {$invoiceNumber}\n");
        exit(1);
    }

    $update = $db->prepare('UPDATE facturas SET pdf_ruta = :ruta WHERE id = :id');
    $update->execute([
        ':ruta' => $result['pdf_path'],
        ':id' => $id,
    ]);

    echo "OK {$invoiceNumber} => {$result['pdf_path']}\n";
} catch (Throwable $e) {
    fwrite(STDERR, 'ERROR: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}
