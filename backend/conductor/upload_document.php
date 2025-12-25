<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$response = array();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_FILES['file']) && isset($_POST['conductor_id']) && isset($_POST['tipo_documento'])) {
        $conductor_id = $_POST['conductor_id'];
        $tipo_documento = $_POST['tipo_documento'];
        $file = $_FILES['file'];

        // Estructura de carpetas: uploads/conductores/[id]/[tipo]/
        $target_dir = "../uploads/conductores/" . $conductor_id . "/" . $tipo_documento . "/";
        
        if (!file_exists($target_dir)) {
            mkdir($target_dir, 0777, true);
        }

        $file_extension = pathinfo($file["name"], PATHINFO_EXTENSION);
        // Nombre de archivo seguro: timestamp_random.ext
        $new_filename = time() . "_" . rand(1000, 9999) . "." . $file_extension;
        $target_file = $target_dir . $new_filename;

        // Validar tipo de archivo (solo imágenes o PDF)
        $allowed_extensions = array('jpg', 'jpeg', 'png', 'pdf');
        if (!in_array(strtolower($file_extension), $allowed_extensions)) {
            echo json_encode(array("success" => false, "message" => "Tipo de archivo no permitido. Solo JPG, PNG y PDF."));
            exit;
        }

        if (move_uploaded_file($file["tmp_name"], $target_file)) {
            // Guardar o actualizar registro en BD
            // Usamos ruta relativa "uploads/..." para almacenar en BD
            $relative_path = "uploads/conductores/" . $conductor_id . "/" . $tipo_documento . "/" . $new_filename;

            try {
                // Verificar si ya existe un documento de este tipo pendiente o aprobado (para reemplazar o historico)
                // En este caso simple, insertamos nuevo registro. 
                // Si quisieramos "reemplazar", podríamos actualizar el estado del anterior a 'obsoleto'.
                
                $query = "INSERT INTO documentos_verificacion (conductor_id, tipo_documento, ruta_archivo, estado) VALUES (:conductor_id, :tipo_documento, :ruta_archivo, 'pendiente')";
                $stmt = $db->prepare($query);
                $stmt->bindParam(":conductor_id", $conductor_id);
                $stmt->bindParam(":tipo_documento", $tipo_documento);
                $stmt->bindParam(":ruta_archivo", $relative_path);
                
                if ($stmt->execute()) {
                    $response['success'] = true;
                    $response['message'] = "Documento subido correctamente.";
                    $response['path'] = $relative_path;
                } else {
                    $response['success'] = false;
                    $response['message'] = "Error al guardar en base de datos.";
                }
            } catch (PDOException $e) {
                $response['success'] = false;
                $response['message'] = "Error DB: " . $e->getMessage();
            }

        } else {
            $response['success'] = false;
            $response['message'] = "Error al mover el archivo subido.";
        }
    } else {
        $response['success'] = false;
        $response['message'] = "Datos incompletos. Se requiere archivo, conductor_id y tipo_documento.";
    }
} else {
    $response['success'] = false;
    $response['message'] = "Método no permitido.";
}

echo json_encode($response);
?>
