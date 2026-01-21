<?php
/**
 * API: Registrar pago de comisión
 * Endpoint: admin/registrar_pago_comision.php
 * 
 * Permite al administrador registrar un pago de deuda de comisión
 * de un conductor.
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once '../config/database.php';

try {
    $input = json_decode(file_get_contents('php://input'), true);
    
    $conductor_id = $input['conductor_id'] ?? null;
    $monto = $input['monto'] ?? null;
    $admin_id = $input['admin_id'] ?? null; // Opcional
    $notas = $input['notas'] ?? null;
    $metodo_pago = $input['metodo_pago'] ?? 'efectivo';
    
    if (!$conductor_id || !$monto || $monto <= 0) {
        throw new Exception('ID de conductor y monto positivo son requeridos');
    }

    $database = new Database();
    $db = $database->getConnection();
    
    // Verificar que el conductor existe
    $stmtVerify = $db->prepare("SELECT id FROM usuarios WHERE id = ?");
    $stmtVerify->execute([$conductor_id]);
    if (!$stmtVerify->fetch()) {
        throw new Exception('Conductor no encontrado');
    }

    // Insertar el pago
    $query = "INSERT INTO pagos_comision 
              (conductor_id, monto, metodo_pago, admin_id, notas, fecha_pago) 
              VALUES (:conductor_id, :monto, :metodo_pago, :admin_id, :notas, NOW())";
    
    $stmt = $db->prepare($query);
    $stmt->bindParam(':conductor_id', $conductor_id);
    $stmt->bindParam(':monto', $monto);
    $stmt->bindParam(':metodo_pago', $metodo_pago);
    $stmt->bindParam(':admin_id', $admin_id);
    $stmt->bindParam(':notas', $notas);
    
    if ($stmt->execute()) {
        echo json_encode([
            'success' => true,
            'message' => 'Pago registrado correctamente',
            'id_pago' => $db->lastInsertId(),
            'monto' => $monto
        ]);
    } else {
        throw new Exception('Error al registrar el pago en la base de datos');
    }

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
