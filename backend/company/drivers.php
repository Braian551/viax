<?php
/**
 * Company Drivers API
 * Permite a las empresas ver sus conductores
 */

require_once '../config/config.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    $database = new Database();
    $db = $database->getConnection();
    $method = $_SERVER['REQUEST_METHOD'];
    
     if ($method === 'GET') {
        $input = $_GET;
    } else {
        $input = getJsonInput();
    }

    if (empty($input['empresa_id'])) {
        sendJsonResponse(false, 'ID de empresa requerido');
        exit();
    }
    
    $empresaId = $input['empresa_id'];
    
    // Obtener conductores vinculados a esta empresa
    // La relación según migración 018 es: usuarios.empresa_id
    
    $query = "SELECT 
                u.id, u.nombre, u.apellido, u.email, u.telefono, 
                u.foto_perfil, u.es_activo, u.es_verificado,
                u.fecha_registro,
                d.tipo_vehiculo, d.marca, d.modelo, d.placa
              FROM usuarios u
              LEFT JOIN detalles_conductor d ON u.id = d.usuario_id
              WHERE u.tipo_usuario = 'conductor' 
              AND u.empresa_id = ?
              ORDER BY u.fecha_registro DESC";
              
    $stmt = $db->prepare($query);
    $stmt->execute([$empresaId]);
    $conductores = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    sendJsonResponse(true, 'Conductores obtenidos', [
        'conductores' => $conductores,
        'total' => count($conductores)
    ]);
    
} catch (Exception $e) {
    error_log("Error company/drivers.php: " . $e->getMessage());
    sendJsonResponse(false, 'Error del servidor');
}
?>
