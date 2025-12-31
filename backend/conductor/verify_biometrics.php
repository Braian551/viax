<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");

require_once '../config/database.php';

$database = new Database();
$db = $database->getConnection();

$response = array();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $conductor_id = $_POST['conductor_id'] ?? null;
    
    if (!$conductor_id || !isset($_FILES['selfie'])) {
        echo json_encode(["success" => false, "message" => "Missing conductor_id or selfie file"]);
        exit;
    }

    // 1. Save Selfie
    $target_dir = "../uploads/conductores/" . $conductor_id . "/biometria/";
    if (!file_exists($target_dir)) {
        mkdir($target_dir, 0777, true);
    }
    
    $file_extension = pathinfo($_FILES['selfie']['name'], PATHINFO_EXTENSION);
    $selfie_filename = "selfie_" . time() . "." . $file_extension;
    $selfie_path = $target_dir . $selfie_filename;
    
    if (!move_uploaded_file($_FILES['selfie']['tmp_name'], $selfie_path)) {
        echo json_encode(["success" => false, "message" => "Failed to save selfie"]);
        exit;
    }

    // 2. Get ID Document Path from DB
    // Assuming 'documento_identidad' or 'cedula' is the type
    $query = "SELECT ruta_archivo FROM documentos_verificacion WHERE conductor_id = :id AND tipo_documento = 'documento_identidad' AND estado = 'aprobado' ORDER BY id DESC LIMIT 1";
    $stmt = $db->prepare($query);
    $stmt->bindParam(":id", $conductor_id);
    $stmt->execute();
    
    if ($stmt->rowCount() == 0) {
        // Fallback: Check for 'licencia_conduccion' if no ID is uploaded yet, or return error
         $query = "SELECT ruta_archivo FROM documentos_verificacion WHERE conductor_id = :id AND tipo_documento = 'licencia_conduccion' ORDER BY id DESC LIMIT 1";
         $stmt = $db->prepare($query);
         $stmt->bindParam(":id", $conductor_id);
         $stmt->execute();
         
         if ($stmt->rowCount() == 0) {
             echo json_encode(["success" => false, "message" => "No approved ID document found to compare against."]);
             exit;
         }
    }
    
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    $id_doc_rel_path = $row['ruta_archivo']; // This is like "uploads/..."
    $id_doc_full_path = "../" . $id_doc_rel_path;

    // 3. Get Blocked Users Faces
    // Fetch paths of bio-verified photos of users who are now blocked
    // This is a complex query. For MVP, let's assume we query 'detalles_conductor' for state='bloqueado' 
    // and join with 'documentos_verificacion' for verify pics.
    
    // NOTE: This might be slow if there are many blocked users. 
    // Optimization: Store face encodings in DB instead of raw images processing every time.
    // For this implementation, we will mock the blocked list or limit it to latest 5 to avoid timeouts in MVP.
    // 3. Get Blocked Users Faces
    // Fetch paths of selfies from users who are blocked due to biometric issues
    // We look for 'bloqueado' status in details and get their latest selfie (assuming stored in biometria folder or profile pic)
    // For this implementation, we scan the uploads/conductores/*/biometria/ folders for blocked users.
    
    $blocked_paths = []; 
    $queryBlocked = "SELECT id, usuario_id FROM detalles_conductor WHERE estado_biometrico = 'bloqueado' LIMIT 20";
    $stmtBlocked = $db->prepare($queryBlocked);
    $stmtBlocked->execute();
    
    while ($blockedRow = $stmtBlocked->fetch(PDO::FETCH_ASSOC)) {
        $bUserId = $blockedRow['usuario_id'];
        // Construct path to their biometry folder
        $bUserDir = "../uploads/conductores/" . $bUserId . "/biometria/";
        if (is_dir($bUserDir)) {
            // Get latest file in that dir
            $files = scandir($bUserDir, SCANDIR_SORT_DESCENDING);
            foreach ($files as $f) {
                if ($f != '.' && $f != '..' && preg_match('/\.(jpg|jpeg|png)$/i', $f)) {
                    $blocked_paths[] = $bUserDir . $f;
                    break; // Just take the latest one
                }
            }
        }
    }
    
    // 4. Call Python Script
    $python_script = "../python_services/verify_face.py";
    $blocked_json = json_encode($blocked_paths);
    
    // Validate paths verify they exist
    if (!file_exists($id_doc_full_path)) {
         echo json_encode(["success" => false, "message" => "ID document file missing on server."]);
         exit;
    }

    // Escape arguments
    // On Windows, python is usually 'python', not 'python3'
    $cmd = "python " . escapeshellarg($python_script) . " " . escapeshellarg($selfie_path) . " " . escapeshellarg($id_doc_full_path) . " " . escapeshellarg($blocked_json);
    
    $output = shell_exec($cmd);
    $result = json_decode($output, true);

    if ($result && isset($result['status'])) {
        $status = $result['status'];
        
        // Update DB
        $db_status = ($status == 'verified') ? 'verificado' : (($status == 'blocked') ? 'bloqueado' : 'fallido');
        
        $update = "UPDATE detalles_conductor SET estado_biometrico = :status WHERE id = (SELECT id FROM detalles_conductor WHERE conductor_id = :cid)";
        // Note: detalles_conductor might imply conductor_id is the primary key or unique foreign key.
        // Assuming conductor_id in POST is valid user ID. 
        // Need to be careful with schema. user_id vs conductor_id.
        // Let's assume conductor_id passed here IS the id in conductores table.
        
        // Simpler update if relation is 1:1
        $update = "UPDATE detalles_conductor SET estado_biometrico = :status WHERE id = :cid"; 
        // Wait, detalles_conductor usually has 'conductor_id' FK context.
        $update = "UPDATE detalles_conductor SET estado_biometrico = :status WHERE conductor_id = :cid";

        $stmtUp = $db->prepare($update);
        $stmtUp->bindParam(":status", $db_status);
        $stmtUp->bindParam(":cid", $conductor_id);
        $stmtUp->execute();

        echo json_encode([
            "success" => ($status == 'verified'),
            "message" => $result['message'],
            "biometric_status" => $status
        ]);
    } else {
        echo json_encode(["success" => false, "message" => "Biometric service failed", "raw_output" => $output]);
    }

} else {
    echo json_encode(["success" => false, "message" => "Method not allowed"]);
}
?>
