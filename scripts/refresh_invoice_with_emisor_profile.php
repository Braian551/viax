<?php
require __DIR__ . '/../backend/config/database.php';
require __DIR__ . '/../backend/admin/generate_invoice_pdf.php';

$invoiceNumber = $argv[1] ?? 'VIAX-EA-000001';

try {
    $db = (new Database())->getConnection();

    $adminStmt = $db->query("SELECT
        u.id,
        COALESCE(aef.nombre_legal, TRIM(COALESCE(u.nombre,'') || ' ' || COALESCE(u.apellido,'')), 'Administrador Principal') AS emisor_nombre,
        COALESCE(aef.numero_documento, '') AS emisor_documento,
        COALESCE(aef.email_emisor, u.email, 'braianoquen@gmail.com') AS emisor_email
    FROM usuarios u
    LEFT JOIN admin_emisor_fiscal aef ON aef.admin_id = u.id
    WHERE u.tipo_usuario IN ('admin','administrador')
    ORDER BY
      (LOWER(COALESCE(aef.email_emisor, u.email)) = LOWER('braianoquen@gmail.com')) DESC,
      (LOWER(u.email) = LOWER('braianoquen@gmail.com')) DESC,
      u.id ASC
    LIMIT 1");
    $admin = $adminStmt->fetch(PDO::FETCH_ASSOC);

    if (!$admin) {
        throw new RuntimeException('No se encontro un administrador para emisor');
    }

    $invoiceStmt = $db->prepare('SELECT id FROM facturas WHERE numero_factura = :n LIMIT 1');
    $invoiceStmt->execute([':n' => $invoiceNumber]);
    $invoice = $invoiceStmt->fetch(PDO::FETCH_ASSOC);

    if (!$invoice) {
        throw new RuntimeException('Factura no encontrada: ' . $invoiceNumber);
    }

    $invoiceId = (int)$invoice['id'];

    $upd = $db->prepare("UPDATE facturas
        SET emisor_id = :emisor_id,
            emisor_nombre = :emisor_nombre,
            emisor_documento = :emisor_documento,
            emisor_email = :emisor_email,
            pago_referencia_tipo = 'pago_empresa_plataforma'
        WHERE id = :id");
    $upd->execute([
        ':emisor_id' => (int)$admin['id'],
        ':emisor_nombre' => $admin['emisor_nombre'],
        ':emisor_documento' => $admin['emisor_documento'],
        ':emisor_email' => $admin['emisor_email'],
        ':id' => $invoiceId,
    ]);

    $result = generateInvoicePdf($db, $invoiceId);
    if (!$result || empty($result['pdf_path'])) {
        throw new RuntimeException('No fue posible regenerar PDF para ' . $invoiceNumber);
    }

    $updPdf = $db->prepare('UPDATE facturas SET pdf_ruta = :ruta WHERE id = :id');
    $updPdf->execute([
        ':ruta' => $result['pdf_path'],
        ':id' => $invoiceId,
    ]);

    echo 'OK ' . $invoiceNumber . ' => ' . $result['pdf_path'] . PHP_EOL;
} catch (Throwable $e) {
    fwrite(STDERR, 'ERROR: ' . $e->getMessage() . PHP_EOL);
    exit(1);
}
