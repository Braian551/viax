<?php
/**
 * Upload de Documentos del Conductor
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/R2Service.php';

$response = [
    'success' => false,
    'message' => '',
    'data' => null
];

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Método no permitido');
    }

    if (!isset($_FILES['documento']) || $_FILES['documento']['error'] === UPLOAD_ERR_NO_FILE) {
        throw new Exception('No se recibió ningún archivo');
    }

    if (!isset($_POST['conductor_id']) || !isset($_POST['tipo_documento'])) {
        throw new Exception('Faltan parámetros requeridos');
    }

    $conductorId = filter_var($_POST['conductor_id'], FILTER_VALIDATE_INT);
    $tipoDocumento = $_POST['tipo_documento'];

    if (!$conductorId) {
        throw new Exception('ID de conductor inválido');
    }

    $tiposPermitidos = ['licencia', 'soat', 'tecnomecanica', 'tarjeta_propiedad', 'seguro'];
    if (!in_array($tipoDocumento, $tiposPermitidos)) {
        throw new Exception('Tipo de documento inválido');
    }

    $file = $_FILES['documento'];
    $extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    
    // R2 Upload
    $filename = 'documents/' . $conductorId . '/' . $tipoDocumento . '_' . time() . '.' . $extension;
    $r2 = new R2Service();
    $relativeUrl = $r2->uploadFile($file['tmp_name'], $filename, $file['type']);

    $db = new Database();
    $db = $db->getConnection();
    
    $db->beginTransaction();

    try {
        $columnMap = [
            'licencia' => 'licencia_foto_url',
            'soat' => 'soat_foto_url',
            'tecnomecanica' => 'tecnomecanica_foto_url',
            'tarjeta_propiedad' => 'tarjeta_propiedad_foto_url',
            'seguro' => 'seguro_foto_url'
        ];
        $column = $columnMap[$tipoDocumento];

        // Update details
        $stmt = $db->prepare("UPDATE detalles_conductor SET $column = ?, actualizado_en = NOW() WHERE usuario_id = ?");
        $stmt->execute([$relativeUrl, $conductorId]);

        // History
        $stmt = $db->prepare("INSERT INTO documentos_conductor_historial 
            (conductor_id, tipo_documento, url_documento, activo, verificado_por_admin) 
            VALUES (?, ?, ?, 1, 1)");
        $stmt->execute([$conductorId, $tipoDocumento, $relativeUrl]);

        $db->commit();

        $response['success'] = true;
        $response['message'] = 'Documento subido exitosamente';
        $response['data'] = ['url' => $relativeUrl];

    } catch (Exception $e) {
        $db->rollBack();
        throw $e;
    }

} catch (Exception $e) {
    http_response_code(400);
    $response['message'] = $e->getMessage();
}

echo json_encode($response, JSON_UNESCAPED_UNICODE);
?>
