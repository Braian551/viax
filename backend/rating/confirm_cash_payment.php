<?php
/**
 * Endpoint para confirmar pago en efectivo.
 * 
 * POST /rating/confirm_cash_payment.php
 * 
 * Body:
 * - solicitud_id: int
 * - conductor_id: int
 * - monto: float
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
    $data = json_decode(file_get_contents('php://input'), true);
    
    $solicitudId = $data['solicitud_id'] ?? null;
    $conductorId = $data['conductor_id'] ?? null;
    $monto = $data['monto'] ?? null;
    
    if (!$solicitudId || !$conductorId) {
        throw new Exception('Se requiere solicitud_id y conductor_id');
    }
    
    $database = new Database();
    $db = $database->getConnection();
    
    // Verificar que la solicitud existe y pertenece al conductor
    $stmt = $db->prepare("
        SELECT s.id, s.estado, s.precio_final, ac.conductor_id
        FROM solicitudes_servicio s
        INNER JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id
        WHERE s.id = ? AND ac.conductor_id = ?
    ");
    $stmt->execute([$solicitudId, $conductorId]);
    $solicitud = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$solicitud) {
        throw new Exception('Solicitud no encontrada o no autorizada');
    }
    
    // Actualizar estado de pago
    $stmt = $db->prepare("
        UPDATE solicitudes_servicio 
        SET pago_confirmado = TRUE,
            pago_confirmado_en = NOW(),
            metodo_pago_usado = 'efectivo'
        WHERE id = ?
    ");
    $stmt->execute([$solicitudId]);
    
    // Registrar en historial de pagos si existe la tabla
    try {
        $stmt = $db->prepare("
            INSERT INTO pagos_viaje (
                solicitud_id,
                conductor_id,
                monto,
                metodo_pago,
                estado,
                confirmado_en
            ) VALUES (?, ?, ?, 'efectivo', 'confirmado', NOW())
            ON CONFLICT (solicitud_id) DO UPDATE SET
                estado = 'confirmado',
                confirmado_en = NOW()
        ");
        $stmt->execute([$solicitudId, $conductorId, $monto ?? $solicitud['precio_final']]);
    } catch (PDOException $e) {
        // Tabla puede no existir, continuar
        error_log('Tabla pagos_viaje no existe o error: ' . $e->getMessage());
    }
    
    // Actualizar ganancias del conductor
    $stmt = $db->prepare("
        UPDATE detalles_conductor 
        SET ganancias_totales = COALESCE(ganancias_totales, 0) + ?
        WHERE usuario_id = ?
    ");
    $stmt->execute([$monto ?? $solicitud['precio_final'], $conductorId]);
    
    echo json_encode([
        'success' => true,
        'message' => 'Pago confirmado correctamente',
        'monto_registrado' => $monto ?? $solicitud['precio_final']
    ]);
    
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
