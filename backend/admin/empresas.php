<?php
/**
 * Empresas de Transporte - API Endpoints
 * 
 * Este archivo gestiona todas las operaciones CRUD para empresas de transporte.
 * 
 * Endpoints:
 * - GET    ?action=list         - Listar todas las empresas
 * - GET    ?action=get&id=X     - Obtener una empresa por ID
 * - POST   action=create        - Crear nueva empresa
 * - POST   action=update        - Actualizar empresa existente
 * - POST   action=delete        - Eliminar empresa (soft delete)
 * - POST   action=toggle_status - Cambiar estado de empresa
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('log_errors', 1);

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once '../config/config.php';

try {
    $database = new Database();
    $db = $database->getConnection();
    
    // Determinar la acción
    $action = $_GET['action'] ?? $_POST['action'] ?? null;
    
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $contentType = $_SERVER["CONTENT_TYPE"] ?? '';
        if (strpos($contentType, 'application/json') !== false) {
            $input = getJsonInput();
        } else {
            $input = $_POST;
        }
        $action = $action ?? $input['action'] ?? null;
    }
    
    switch ($action) {
        case 'list':
            listEmpresas($db);
            break;
        case 'get':
            getEmpresa($db);
            break;
        case 'create':
            createEmpresa($db, $input);
            break;
        case 'update':
            updateEmpresa($db, $input);
            break;
        case 'delete':
            deleteEmpresa($db, $input);
            break;
        case 'toggle_status':
            toggleEmpresaStatus($db, $input);
            break;
        case 'approve':
            approveEmpresa($db, $input);
            break;
        case 'reject':
            rejectEmpresa($db, $input);
            break;
        case 'get_stats':
            getEmpresaStats($db);
            break;
        default:
            // Si no se especifica acción, listar empresas
            listEmpresas($db);
    }
    
} catch (Exception $e) {
    error_log("Error en empresas.php: " . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error interno del servidor',
        'error' => $e->getMessage()
    ]);
}

/**
 * Listar todas las empresas con filtros opcionales
 */
function listEmpresas($db) {
    $estado = $_GET['estado'] ?? null;
    $municipio = $_GET['municipio'] ?? null;
    $search = $_GET['search'] ?? null;
    $page = intval($_GET['page'] ?? 1);
    $limit = intval($_GET['limit'] ?? 50);
    $offset = ($page - 1) * $limit;
    
    $whereConditions = [];
    $params = [];
    
    if ($estado) {
        $whereConditions[] = "estado = ?";
        $params[] = $estado;
    }
    
    if ($municipio) {
        $whereConditions[] = "municipio ILIKE ?";
        $params[] = "%$municipio%";
    }
    
    if ($search) {
        $whereConditions[] = "(nombre ILIKE ? OR nit ILIKE ? OR razon_social ILIKE ?)";
        $params[] = "%$search%";
        $params[] = "%$search%";
        $params[] = "%$search%";
    }
    
    $whereClause = '';
    if (!empty($whereConditions)) {
        $whereClause = 'WHERE ' . implode(' AND ', $whereConditions);
    }
    
    // Contar total
    $countQuery = "SELECT COUNT(*) as total FROM empresas_transporte $whereClause";
    $countStmt = $db->prepare($countQuery);
    $countStmt->execute($params);
    $total = $countStmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // Obtener empresas
    $query = "SELECT 
                e.*,
                u.nombre as creador_nombre
              FROM empresas_transporte e
              LEFT JOIN usuarios u ON e.creado_por = u.id
              $whereClause
              ORDER BY e.creado_en DESC
              LIMIT ? OFFSET ?";
    
    $params[] = $limit;
    $params[] = $offset;
    
    $stmt = $db->prepare($query);
    $stmt->execute($params);
    $empresas = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Procesar datos de respuesta
    foreach ($empresas as &$empresa) {
        // Tipos de vehículo
        if ($empresa['tipos_vehiculo']) {
            $empresa['tipos_vehiculo'] = pgArrayToPhp($empresa['tipos_vehiculo']);
        } else {
            $empresa['tipos_vehiculo'] = [];
        }
        
        // Convertir logo_url relativo a absoluto usando r2_proxy.php
        if (!empty($empresa['logo_url']) && strpos($empresa['logo_url'], 'http') !== 0) {
            $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
            $host = $_SERVER['HTTP_HOST'];
            // Asumiendo que r2_proxy.php está en la raíz de backend/
            $baseDir = dirname($_SERVER['PHP_SELF'], 2); // /backend
            $empresa['logo_url'] = "$protocol://$host$baseDir/r2_proxy.php?key=" . urlencode($empresa['logo_url']);
        }
    }
    
    echo json_encode([
        'success' => true,
        'empresas' => $empresas,
        'pagination' => [
            'page' => $page,
            'limit' => $limit,
            'total' => intval($total),
            'total_pages' => ceil($total / $limit)
        ]
    ]);
}

/**
 * Obtener una empresa por ID
 */
function getEmpresa($db) {
    $id = intval($_GET['id'] ?? 0);
    
    if (!$id) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'ID de empresa requerido']);
        return;
    }
    
    $query = "SELECT 
                e.*,
                u.nombre as creador_nombre,
                v.nombre as verificador_nombre
              FROM empresas_transporte e
              LEFT JOIN usuarios u ON e.creado_por = u.id
              LEFT JOIN usuarios v ON e.verificado_por = v.id
              WHERE e.id = ?";
    
    $stmt = $db->prepare($query);
    $stmt->execute([$id]);
    $empresa = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$empresa) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Empresa no encontrada']);
        return;
    }
    
    // Procesar tipos_vehiculo
    if ($empresa['tipos_vehiculo']) {
        $empresa['tipos_vehiculo'] = pgArrayToPhp($empresa['tipos_vehiculo']);
    } else {
        $empresa['tipos_vehiculo'] = [];
    }
    
    // Convertir logo_url relativo a absoluto usando r2_proxy.php
    if (!empty($empresa['logo_url']) && strpos($empresa['logo_url'], 'http') !== 0) {
        $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
        $host = $_SERVER['HTTP_HOST'];
        $baseDir = dirname($_SERVER['PHP_SELF'], 2); // /backend
        $empresa['logo_url'] = "$protocol://$host$baseDir/r2_proxy.php?key=" . urlencode($empresa['logo_url']);
    }
    
    // Obtener conductores de la empresa
    $conductoresQuery = "SELECT id, nombre, telefono, email, calificacion_promedio 
                         FROM usuarios 
                         WHERE empresa_id = ? AND tipo_usuario = 'conductor'
                         ORDER BY nombre";
    $conductoresStmt = $db->prepare($conductoresQuery);
    $conductoresStmt->execute([$id]);
    $empresa['conductores'] = $conductoresStmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true,
        'empresa' => $empresa
    ]);
}

/**
 * Crear nueva empresa
 */
/**
 * Crear nueva empresa usando EmpresaService para consistencia
 */
function createEmpresa($db, $input) {
    // Verificar admin
    $adminId = $input['admin_id'] ?? null;
    if ($adminId) {
        $checkAdmin = $db->prepare("SELECT id FROM usuarios WHERE id = ? AND tipo_usuario = 'administrador'");
        $checkAdmin->execute([$adminId]);
        if (!$checkAdmin->fetch()) {
            http_response_code(403);
            echo json_encode(['success' => false, 'message' => 'Solo administradores pueden crear empresas']);
            return;
        }
    }
    
    try {
        require_once __DIR__ . '/../empresa/services/EmpresaService.php';
        $service = new EmpresaService($db);
        
        // Mapear campos del formulario de Admin a lo que espera el Servicio
        $serviceInput = $input;
        $serviceInput['nombre_empresa'] = $input['nombre']; // Servicio espera nombre_empresa
        
        // Generar contraseña si no se proporcionó (aunque el formulario debería obligarla)
        if (empty($serviceInput['password'])) {
            $serviceInput['password'] = bin2hex(random_bytes(8));
        }
        
        // Ejecutar registro
        $result = $service->processRegistration($serviceInput);
        
        // Enviar notificaciones (PDF, Email)
        if (isset($result['notification_context'])) {
            // Nota: Esto puede tomar tiempo. En un entorno ideal, usar colas.
            $service->sendNotifications($result['notification_context']);
        }
        
        // Log de auditoría adicional para Admin
        logAuditAction($db, $adminId, 'empresa_creada_admin', 'empresas_transporte', $result['data']['empresa_id'], [
            'nombre' => $input['nombre'],
            'nit' => $input['nit'] ?? null
        ]);
        
        echo json_encode([
            'success' => true,
            'message' => 'Empresa creada exitosamente con credenciales y notificaciones enviadas.',
            'empresa_id' => $result['data']['empresa_id']
        ]);
        
    } catch (Exception $e) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => $e->getMessage()]);
    }
}

/**
 * Actualizar empresa existente
 */
function updateEmpresa($db, $input) {
    $empresaId = intval($input['id'] ?? 0);
    
    if (!$empresaId) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'ID de empresa requerido']);
        return;
    }
    
    // Verificar que la empresa existe
    $checkEmpresa = $db->prepare("SELECT id FROM empresas_transporte WHERE id = ?");
    $checkEmpresa->execute([$empresaId]);
    if (!$checkEmpresa->fetch()) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Empresa no encontrada']);
        return;
    }
    
    // Verificar NIT único si se cambia
    if (!empty($input['nit'])) {
        $checkNit = $db->prepare("SELECT id FROM empresas_transporte WHERE nit = ? AND id != ?");
        $checkNit->execute([$input['nit'], $empresaId]);
        if ($checkNit->fetch()) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Ya existe otra empresa con este NIT']);
            return;
        }
    }
    
    // Preparar tipos_vehiculo
    $tiposVehiculo = null;
    if (isset($input['tipos_vehiculo'])) {
        $vehiculos = $input['tipos_vehiculo'];
        if (is_string($vehiculos)) {
            $decoded = json_decode($vehiculos, true);
            if (json_last_error() === JSON_ERROR_NONE) {
                $vehiculos = $decoded;
            } else {
                $vehiculos = explode(',', $vehiculos);
            }
        }
        
        if (is_array($vehiculos)) {
            $tiposVehiculo = phpArrayToPg($vehiculos);
        }
    }
    
    // Manejar subida de logo
    $uploadedLogo = handleLogoUpload();
    if ($uploadedLogo) {
        $input['logo_url'] = $uploadedLogo;
    }
    
    // Construir query dinámico solo con campos proporcionados
    $updates = [];
    $params = [];
    
    $campos = [
        'nombre', 'nit', 'razon_social', 'email', 'telefono', 'telefono_secundario',
        'direccion', 'municipio', 'departamento', 'representante_nombre',
        'representante_telefono', 'representante_email', 'logo_url', 
        'descripcion', 'estado', 'notas_admin'
    ];
    
    foreach ($campos as $campo) {
        if (isset($input[$campo])) {
            $updates[] = "$campo = ?";
            $params[] = $input[$campo];
        }
    }
    
    // Manejar tipos_vehiculo por separado
    if ($tiposVehiculo !== null) {
        $updates[] = "tipos_vehiculo = ?";
        $params[] = $tiposVehiculo;
    }
    
    if (empty($updates)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'No hay campos para actualizar']);
        return;
    }
    
    $params[] = $empresaId;
    
    $query = "UPDATE empresas_transporte SET " . implode(', ', $updates) . " WHERE id = ?";
    $stmt = $db->prepare($query);
    $stmt->execute($params);
    
    // Log de auditoría
    $adminId = $input['admin_id'] ?? null;
    logAuditAction($db, $adminId, 'empresa_actualizada', 'empresas_transporte', $empresaId, $input);
    
    echo json_encode([
        'success' => true,
        'message' => 'Empresa actualizada exitosamente'
    ]);
}

/**
 * Eliminar empresa (soft delete - cambiar estado a 'eliminado')
 */
function deleteEmpresa($db, $input) {
    $empresaId = intval($input['id'] ?? 0);
    
    if (!$empresaId) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'ID de empresa requerido']);
        return;
    }
    
    // Verificar si hay conductores asociados
    $checkConductores = $db->prepare("SELECT COUNT(*) as total FROM usuarios WHERE empresa_id = ?");
    $checkConductores->execute([$empresaId]);
    $conductoresCount = $checkConductores->fetch(PDO::FETCH_ASSOC)['total'];
    
    if ($conductoresCount > 0) {
        http_response_code(400);
        echo json_encode([
            'success' => false, 
            'message' => "No se puede eliminar la empresa porque tiene $conductoresCount conductor(es) asociado(s). Reasigne los conductores primero."
        ]);
        return;
    }
    
    // Soft delete
    $query = "UPDATE empresas_transporte SET estado = 'eliminado' WHERE id = ?";
    $stmt = $db->prepare($query);
    $stmt->execute([$empresaId]);
    
    // Log de auditoría
    $adminId = $input['admin_id'] ?? null;
    logAuditAction($db, $adminId, 'empresa_eliminada', 'empresas_transporte', $empresaId, null);
    
    echo json_encode([
        'success' => true,
        'message' => 'Empresa eliminada exitosamente'
    ]);
}

/**
 * Cambiar estado de empresa (activar/desactivar)
 */
function toggleEmpresaStatus($db, $input) {
    $empresaId = intval($input['id'] ?? 0);
    $nuevoEstado = $input['estado'] ?? null;
    
    if (!$empresaId || !$nuevoEstado) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'ID y estado son requeridos']);
        return;
    }
    
    $estadosValidos = ['activo', 'inactivo', 'suspendido', 'pendiente'];
    if (!in_array($nuevoEstado, $estadosValidos)) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Estado no válido']);
        return;
    }
    
    $query = "UPDATE empresas_transporte SET estado = ? WHERE id = ?";
    $stmt = $db->prepare($query);
    $stmt->execute([$nuevoEstado, $empresaId]);
    
    // Log de auditoría
    $adminId = $input['admin_id'] ?? null;
    logAuditAction($db, $adminId, 'empresa_estado_cambiado', 'empresas_transporte', $empresaId, [
        'nuevo_estado' => $nuevoEstado
    ]);
    
    echo json_encode([
        'success' => true,
        'message' => "Estado de la empresa cambiado a '$nuevoEstado'"
    ]);
}

/**
 * Aprobar solicitud de empresa pendiente
 */
function approveEmpresa($db, $input) {
    $empresaId = intval($input['id'] ?? 0);
    $adminId = intval($input['admin_id'] ?? 0);
    
    if (!$empresaId) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'ID de empresa requerido']);
        return;
    }
    
    // Obtener información de la empresa
    $query = "SELECT e.*, u.email as usuario_email, u.nombre as usuario_nombre 
              FROM empresas_transporte e
              LEFT JOIN usuarios u ON u.empresa_id = e.id AND u.tipo_usuario = 'empresa'
              WHERE e.id = ?";
    $stmt = $db->prepare($query);
    $stmt->execute([$empresaId]);
    $empresa = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$empresa) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Empresa no encontrada']);
        return;
    }
    
    if ($empresa['estado'] !== 'pendiente') {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'La empresa no está en estado pendiente']);
        return;
    }
    
    // Actualizar estado a activo y marcar como verificada
    $updateQuery = "UPDATE empresas_transporte 
                    SET estado = 'activo', verificada = true, fecha_verificacion = NOW(), verificado_por = ?
                    WHERE id = ?";
    $updateStmt = $db->prepare($updateQuery);
    $updateStmt->execute([$adminId, $empresaId]);
    
    // Log de auditoría
    logAuditAction($db, $adminId, 'empresa_aprobada', 'empresas_transporte', $empresaId, [
        'nombre' => $empresa['nombre'],
        'email' => $empresa['email']
    ]);
    
    // Enviar notificaciones de aprobación usando Servicio (Email con diseño + copia al personal)
    try {
        require_once __DIR__ . '/../empresa/services/EmpresaService.php';
        $service = new EmpresaService($db);
        
        // Preparar datos para el servicio
        $empresaData = $empresa;
        // Fallbacks para email y representante si faltan en la tabla empresas pero están en usuarios
        if (empty($empresaData['email']) && !empty($empresaData['usuario_email'])) {
            $empresaData['email'] = $empresaData['usuario_email'];
        }
        if (empty($empresaData['representante_nombre']) && !empty($empresaData['usuario_nombre'])) {
            $empresaData['representante_nombre'] = $empresaData['usuario_nombre'];
        }
        // Usuario email como personal email si es diferente
        if (!empty($empresaData['usuario_email']) && $empresaData['usuario_email'] !== $empresaData['email']) {
            $empresaData['representante_email'] = $empresaData['usuario_email'];
        }

        $service->sendApprovalNotifications($empresaData);
        
    } catch (Exception $e) {
        // No fallar la aprobación si falla el email, solo loguear
        error_log("Error enviando notificaciones de aprobación: " . $e->getMessage());
    }
    
    echo json_encode([
        'success' => true,
        'message' => 'Empresa aprobada exitosamente. Se ha notificado al representante.'
    ]);
}

/**
 * Rechazar solicitud de empresa pendiente
 */
function rejectEmpresa($db, $input) {
    $empresaId = intval($input['id'] ?? 0);
    $adminId = intval($input['admin_id'] ?? 0);
    $motivo = trim($input['motivo'] ?? 'No se especificó motivo');
    
    if (!$empresaId) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'ID de empresa requerido']);
        return;
    }
    
    // Obtener información de la empresa
    $query = "SELECT e.*, u.email as usuario_email, u.nombre as usuario_nombre, u.id as usuario_id
              FROM empresas_transporte e
              LEFT JOIN usuarios u ON u.empresa_id = e.id AND u.tipo_usuario = 'empresa'
              WHERE e.id = ?";
    $stmt = $db->prepare($query);
    $stmt->execute([$empresaId]);
    $empresa = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$empresa) {
        http_response_code(404);
        echo json_encode(['success' => false, 'message' => 'Empresa no encontrada']);
        return;
    }
    
    if ($empresa['estado'] !== 'pendiente') {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'La empresa no está en estado pendiente']);
        return;
    }
    
    // Actualizar estado a rechazado y guardar motivo
    $updateQuery = "UPDATE empresas_transporte 
                    SET estado = 'rechazado', notas_admin = COALESCE(notas_admin, '') || '\n[RECHAZADO] ' || ?
                    WHERE id = ?";
    $updateStmt = $db->prepare($updateQuery);
    $updateStmt->execute([$motivo, $empresaId]);
    
    // Desactivar usuario asociado
    if ($empresa['usuario_id']) {
        $deactivateUser = $db->prepare("UPDATE usuarios SET activo = false WHERE id = ?");
        $deactivateUser->execute([$empresa['usuario_id']]);
    }
    
    // Log de auditoría
    logAuditAction($db, $adminId, 'empresa_rechazada', 'empresas_transporte', $empresaId, [
        'nombre' => $empresa['nombre'],
        'email' => $empresa['email'],
        'motivo' => $motivo
    ]);
    
    // Enviar email de rechazo
    sendRejectionEmail($empresa['email'] ?? $empresa['usuario_email'], $empresa['nombre'], $empresa['representante_nombre'] ?? $empresa['usuario_nombre'], $motivo);
    
    echo json_encode([
        'success' => true,
        'message' => 'Empresa rechazada. Se ha notificado al representante.'
    ]);
}

/**
 * Enviar email de aprobación de empresa
 */
function sendApprovalEmail($email, $nombreEmpresa, $representante) {
    try {
        $vendorPath = __DIR__ . '/../vendor/autoload.php';
        if (!file_exists($vendorPath)) {
            error_log("Vendor autoload no encontrado para enviar email de aprobación");
            return;
        }
        require_once $vendorPath;
        
        if (!class_exists('PHPMailer\PHPMailer\PHPMailer')) {
            error_log("PHPMailer no disponible");
            return;
        }
        
        $mail = new \PHPMailer\PHPMailer\PHPMailer(true);
        
        $mail->isSMTP();
        $mail->Host = 'smtp.gmail.com';
        $mail->SMTPAuth = true;
        $mail->Username = 'viaxoficialcol@gmail.com';
        $mail->Password = 'filz vqel gadn kugb';
        $mail->SMTPSecure = \PHPMailer\PHPMailer\PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port = 587;
        $mail->CharSet = 'UTF-8';
        
        $mail->setFrom('viaxoficialcol@gmail.com', 'Viax');
        $mail->addAddress($email, $representante);
        
        $mail->isHTML(true);
        $mail->Subject = "✅ ¡Tu empresa ha sido aprobada! - {$nombreEmpresa}";
        
        $mail->Body = "
        <div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;'>
            <div style='background: linear-gradient(135deg, #4CAF50 0%, #388E3C 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;'>
                <h1 style='color: white; margin: 0;'>✅ ¡Felicidades!</h1>
                <p style='color: white; margin: 10px 0 0 0;'>Tu empresa ha sido aprobada</p>
            </div>
            <div style='padding: 30px; background: #f9f9f9; border-radius: 0 0 10px 10px;'>
                <p style='font-size: 16px;'>Hola <strong>{$representante}</strong>,</p>
                <p>Nos complace informarte que <strong>{$nombreEmpresa}</strong> ha sido aprobada y verificada en Viax.</p>
                <div style='background: #e8f5e9; border: 1px solid #4CAF50; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;'>
                    <p style='margin: 0; color: #2e7d32; font-size: 18px;'><strong>¡Tu cuenta ya está activa!</strong></p>
                </div>
                <p>Ahora puedes:</p>
                <ul style='line-height: 1.8;'>
                    <li>✅ Iniciar sesión en la aplicación</li>
                    <li>✅ Agregar y gestionar tus conductores</li>
                    <li>✅ Ver estadísticas y reportes</li>
                    <li>✅ Administrar tu flota de vehículos</li>
                </ul>
                <hr style='border: none; border-top: 1px solid #ddd; margin: 20px 0;'>
                <p style='color: #666; font-size: 12px; text-align: center;'>
                    ¿Tienes preguntas? Contáctanos a viaxoficialcol@gmail.com<br>
                    © 2026 Viax - Todos los derechos reservados
                </p>
            </div>
        </div>";
        
        $mail->AltBody = "Hola {$representante},\n\n¡Felicidades! Tu empresa {$nombreEmpresa} ha sido aprobada en Viax.\n\nYa puedes iniciar sesión y comenzar a gestionar tu flota.\n\nSaludos,\nEquipo Viax";
        
        $mail->send();
        error_log("Email de aprobación enviado a: {$email}");
        
    } catch (\Exception $e) {
        error_log("Error enviando email de aprobación: " . $e->getMessage());
    }
}

/**
 * Enviar email de rechazo de empresa
 */
function sendRejectionEmail($email, $nombreEmpresa, $representante, $motivo) {
    try {
        $vendorPath = __DIR__ . '/../vendor/autoload.php';
        if (!file_exists($vendorPath)) {
            return;
        }
        require_once $vendorPath;
        
        if (!class_exists('PHPMailer\PHPMailer\PHPMailer')) {
            return;
        }
        
        $mail = new \PHPMailer\PHPMailer\PHPMailer(true);
        
        $mail->isSMTP();
        $mail->Host = 'smtp.gmail.com';
        $mail->SMTPAuth = true;
        $mail->Username = 'viaxoficialcol@gmail.com';
        $mail->Password = 'filz vqel gadn kugb';
        $mail->SMTPSecure = \PHPMailer\PHPMailer\PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port = 587;
        $mail->CharSet = 'UTF-8';
        
        $mail->setFrom('viaxoficialcol@gmail.com', 'Viax');
        $mail->addAddress($email, $representante);
        
        $mail->isHTML(true);
        $mail->Subject = "Información sobre tu solicitud - {$nombreEmpresa}";
        
        $mail->Body = "
        <div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;'>
            <div style='background: linear-gradient(135deg, #757575 0%, #616161 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;'>
                <h1 style='color: white; margin: 0;'>Actualización de tu Solicitud</h1>
            </div>
            <div style='padding: 30px; background: #f9f9f9; border-radius: 0 0 10px 10px;'>
                <p style='font-size: 16px;'>Hola <strong>{$representante}</strong>,</p>
                <p>Lamentamos informarte que después de revisar tu solicitud para <strong>{$nombreEmpresa}</strong>, no hemos podido aprobarla en este momento.</p>
                <div style='background: #fff3e0; border: 1px solid #ff9800; padding: 15px; border-radius: 8px; margin: 20px 0;'>
                    <p style='margin: 0; color: #e65100;'><strong>Motivo:</strong></p>
                    <p style='margin: 10px 0 0 0; color: #333;'>{$motivo}</p>
                </div>
                <p>Si crees que esto es un error o deseas proporcionar información adicional, no dudes en contactarnos.</p>
                <p>También puedes intentar registrarte nuevamente corrigiendo los aspectos mencionados.</p>
                <hr style='border: none; border-top: 1px solid #ddd; margin: 20px 0;'>
                <p style='color: #666; font-size: 12px; text-align: center;'>
                    Contáctanos a viaxoficialcol@gmail.com<br>
                    © 2026 Viax - Todos los derechos reservados
                </p>
            </div>
        </div>";
        
        $mail->AltBody = "Hola {$representante},\n\nLamentamos informarte que tu solicitud para {$nombreEmpresa} no ha sido aprobada.\n\nMotivo: {$motivo}\n\nPuedes contactarnos para más información.\n\nSaludos,\nEquipo Viax";
        
        $mail->send();
        error_log("Email de rechazo enviado a: {$email}");
        
    } catch (\Exception $e) {
        error_log("Error enviando email de rechazo: " . $e->getMessage());
    }
}

/**
 * Obtener estadísticas de empresas
 */
function getEmpresaStats($db) {
    $query = "SELECT 
                COUNT(*) as total_empresas,
                SUM(CASE WHEN estado = 'activo' THEN 1 ELSE 0 END) as activas,
                SUM(CASE WHEN estado = 'inactivo' THEN 1 ELSE 0 END) as inactivas,
                SUM(CASE WHEN estado = 'pendiente' THEN 1 ELSE 0 END) as pendientes,
                SUM(CASE WHEN verificada = true THEN 1 ELSE 0 END) as verificadas,
                SUM(total_conductores) as total_conductores,
                SUM(total_viajes_completados) as total_viajes
              FROM empresas_transporte
              WHERE estado != 'eliminado'";
    
    $stmt = $db->query($query);
    $stats = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo json_encode([
        'success' => true,
        'stats' => $stats
    ]);
}

/**
 * Convertir array PostgreSQL a array PHP
 */
function pgArrayToPhp($pgArray) {
    if (empty($pgArray) || $pgArray === '{}') {
        return [];
    }
    
    // Remover llaves y dividir por coma
    $pgArray = trim($pgArray, '{}');
    if (empty($pgArray)) {
        return [];
    }
    
    // Manejar comillas en elementos
    $result = [];
    $items = str_getcsv($pgArray);
    foreach ($items as $item) {
        $result[] = trim($item, '"');
    }
    
    return $result;
}

/**
 * Convertir array PHP a array PostgreSQL
 */
function phpArrayToPg($phpArray) {
    if (empty($phpArray)) {
        return '{}';
    }
    
    $escaped = array_map(function($item) {
        return '"' . str_replace('"', '\\"', $item) . '"';
    }, $phpArray);
    
    return '{' . implode(',', $escaped) . '}';
}

/**
 * Registrar acción en log de auditoría
 */
function logAuditAction($db, $adminId, $action, $tabla, $registroId, $detalles) {
    try {
        // Verificar si la tabla de auditoría existe
        $checkTable = $db->query("SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_name = 'audit_logs'
        )");
        $exists = $checkTable->fetchColumn();
        
        if (!$exists) {
            error_log("Tabla audit_logs no existe, saltando log de auditoría");
            return;
        }
        
        $query = "INSERT INTO audit_logs (admin_id, action, tabla_afectada, registro_id, detalles, ip_address) 
                  VALUES (?, ?, ?, ?, ?, ?)";
        $stmt = $db->prepare($query);
        $stmt->execute([
            $adminId,
            $action,
            $tabla,
            $registroId,
            json_encode($detalles),
            $_SERVER['REMOTE_ADDR'] ?? 'unknown'
        ]);
    } catch (Exception $e) {
        error_log("Error al registrar auditoría: " . $e->getMessage());
    }
}

/**
 * Validar y guardar logo de empresa
 */
function handleLogoUpload() {
    if (!isset($_FILES['logo']) || $_FILES['logo']['error'] === UPLOAD_ERR_NO_FILE) {
        return null;
    }

    $file = $_FILES['logo'];
    
    // Validar errores
    if ($file['error'] !== UPLOAD_ERR_OK) {
        throw new Exception('Error en la subida del archivo: ' . $file['error']);
    }

    // Validar tamaño (5MB)
    if ($file['size'] > 5 * 1024 * 1024) {
        throw new Exception('El archivo excede el tamaño máximo permitido (5MB)');
    }

    // Validar tipo
    $allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];
    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $mimeType = finfo_file($finfo, $file['tmp_name']);
    finfo_close($finfo);

    if (!in_array($mimeType, $allowedTypes)) {
        throw new Exception('Tipo de archivo no permitido. Solo se permiten JPG, PNG y WEBP.');
    }

    // Estructura R2: empresas/YYYY/MM/
    $year = date('Y');
    $month = date('m');
    
    // Nombre único
    $extension = pathinfo($file['name'], PATHINFO_EXTENSION);
    $filename = "empresas/$year/$month/logo_" . time() . '_' . bin2hex(random_bytes(8)) . '.' . $extension;
    
    try {
        require_once __DIR__ . '/../config/R2Service.php';
        $r2 = new R2Service();
        $url = $r2->uploadFile($file['tmp_name'], $filename, $mimeType);
        return $url;
    } catch (Exception $e) {
        throw new Exception('Error subiendo a R2: ' . $e->getMessage());
    }
}
