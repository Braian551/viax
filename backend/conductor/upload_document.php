<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/R2Service.php';

$response = array();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_FILES['file']) && isset($_POST['conductor_id']) && isset($_POST['tipo_documento'])) {
        $conductor_id = $_POST['conductor_id'];
        $tipo_documento = $_POST['tipo_documento'];
        $file = $_FILES['file'];

        try {
            $extension = pathinfo($file["name"], PATHINFO_EXTENSION);
            $filename = 'documents/' . $conductor_id . '/' . $tipo_documento . '_' . time() . '.' . $extension;
            
            $r2 = new R2Service();
            $relativeUrl = $r2->uploadFile($file['tmp_name'], $filename, $file['type']);

            $database = new Database();
            $db = $database->getConnection();

            $query = "INSERT INTO documentos_verificacion (conductor_id, tipo_documento, ruta_archivo, estado) VALUES (:conductor_id, :tipo_documento, :ruta_archivo, 'pendiente')";
            $stmt = $db->prepare($query);
            $stmt->bindParam(":conductor_id", $conductor_id);
            $stmt->bindParam(":tipo_documento", $tipo_documento);
            $stmt->bindParam(":ruta_archivo", $relativeUrl);
            
            if ($stmt->execute()) {
                $response['success'] = true;
                $response['message'] = "Documento subido correctamente.";
                $response['path'] = $relativeUrl;
            } else {
                $response['success'] = false;
                $response['message'] = "Error al guardar en base de datos.";
            }

        } catch (Exception $e) {
            $response['success'] = false;
            $response['message'] = "Error R2/DB: " . $e->getMessage();
        }
    } else {
        $response['success'] = false;
        $response['message'] = "Datos incompletos.";
    }
} else {
    $response['success'] = false;
    $response['message'] = "Método no permitido.";
}

echo json_encode($response);
?>
