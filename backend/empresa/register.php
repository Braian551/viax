<?php
/**
 * Registro de Empresas de Transporte - API Endpoint
 * 
 * Este archivo gestiona el registro público de empresas de transporte.
 * Crea tanto la empresa como el usuario administrador de la empresa.
 * 
 * POST action=register - Registrar nueva empresa con usuario administrador
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

// Cargar PHPMailer
$vendorPath = __DIR__ . '/../vendor/autoload.php';
if (file_exists($vendorPath)) {
    require_once $vendorPath;
}

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception as PHPMailerException;

try {
    $database = new Database();
    $db = $database->getConnection();
    
    // Solo aceptar POST
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        echo json_encode(['success' => false, 'message' => 'Método no permitido']);
        exit();
    }
    
    // Determinar tipo de contenido
    $contentType = $_SERVER["CONTENT_TYPE"] ?? '';
    if (strpos($contentType, 'application/json') !== false) {
        $input = getJsonInput();
    } else {
        $input = $_POST;
    }
    
    $action = $input['action'] ?? 'register';
    
    if ($action === 'register') {
        registerEmpresa($db, $input);
    } else {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Acción no válida']);
    }
    
} catch (Exception $e) {
    error_log("Error en empresa/register.php: " . $e->getMessage());
    error_log("Stack trace: " . $e->getTraceAsString());
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error interno del servidor',
        'debug_error' => $e->getMessage(), // DEBUG: mostrar error real
        'debug_line' => $e->getLine(),
        'debug_file' => basename($e->getFile())
    ]);
}


/**
 * Registrar nueva empresa con usuario administrador
 */
function registerEmpresa($db, $input) {
    // DEBUG: Log al inicio
    error_log("=== EMPRESA REGISTER START ===");
    error_log("Input keys: " . implode(', ', array_keys($input)));
    
    // Validar campos requeridos
    $requiredFields = [
        'nombre_empresa' => 'El nombre de la empresa es requerido',
        'email' => 'El email es requerido',
        'password' => 'La contraseña es requerida',
        'telefono' => 'El teléfono es requerido',
        'representante_nombre' => 'El nombre del representante es requerido',
    ];

    
    foreach ($requiredFields as $field => $message) {
        if (empty($input[$field])) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => $message, 'field' => $field]);
            return;
        }
    }
    
    // Validar email
    $email = filter_var(trim($input['email']), FILTER_VALIDATE_EMAIL);
    if (!$email) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Email inválido', 'field' => 'email']);
        return;
    }
    
    // Verificar email único en usuarios
    $checkEmail = $db->prepare("SELECT id FROM usuarios WHERE email = ?");
    $checkEmail->execute([$email]);
    if ($checkEmail->fetch()) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'Este email ya está registrado', 'field' => 'email']);
        return;
    }
    
    // Verificar NIT único si se proporciona
    if (!empty($input['nit'])) {
        $checkNit = $db->prepare("SELECT id FROM empresas_transporte WHERE nit = ?");
        $checkNit->execute([$input['nit']]);
        if ($checkNit->fetch()) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Ya existe una empresa con este NIT', 'field' => 'nit']);
            return;
        }
    }
    
    // Validar contraseña
    $password = $input['password'];
    if (strlen($password) < 6) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'La contraseña debe tener al menos 6 caracteres', 'field' => 'password']);
        return;
    }
    
    // Preparar tipos_vehiculo como array PostgreSQL
    $tiposVehiculo = '{}';
    if (!empty($input['tipos_vehiculo'])) {
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
    
    // Manejar subida de logo a Cloudflare R2
    $logoUrl = null;
    if (isset($_FILES['logo']) && $_FILES['logo']['error'] === UPLOAD_ERR_OK) {
        $logoUrl = handleLogoUpload();
    }
    
    // Iniciar transacción
    $db->beginTransaction();
    
    try {
        // Procesar nombre y apellido del representante ANTES del INSERT
        $nombreCompleto = trim($input['representante_nombre']);
        $nombre = trim($input['representante_nombre']);
        $apellido = '';
        
        // Si se envió el apellido por separado (recomendado), usarlo
        if (isset($input['representante_apellido']) && !empty($input['representante_apellido'])) {
            $nombre = trim($input['representante_nombre']);
            $apellido = trim($input['representante_apellido']);
            $nombreCompleto = $nombre . ' ' . $apellido;
        } else {
            // Fallback: tratar de dividir el nombre completo
            $nombreParts = explode(' ', $nombreCompleto, 2);
            $nombre = $nombreParts[0];
            $apellido = $nombreParts[1] ?? '';
        }

        // 1. Crear la empresa con estado 'pendiente' (requiere aprobación)
        $empresaQuery = "INSERT INTO empresas_transporte (
            nombre, nit, razon_social, email, telefono, telefono_secundario,
            direccion, municipio, departamento, representante_nombre,
            representante_telefono, representante_email, tipos_vehiculo,
            logo_url, descripcion, estado, verificada, notas_admin
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pendiente', false, ?)
        RETURNING id, creado_en";
        
        $empresaStmt = $db->prepare($empresaQuery);
        $empresaStmt->execute([
            trim($input['nombre_empresa']),
            $input['nit'] ?? null,
            $input['razon_social'] ?? null,
            $email,
            trim($input['telefono']),
            $input['telefono_secundario'] ?? null,
            $input['direccion'] ?? null,
            $input['municipio'] ?? null,
            $input['departamento'] ?? null,
            $nombreCompleto, // Usar el nombre completo procesado
            $input['representante_telefono'] ?? $input['telefono'],
            $input['representante_email'] ?? $email,
            $tiposVehiculo,
            $logoUrl,
            $input['descripcion'] ?? null,
            'Registro desde app móvil - pendiente de verificación'
        ]);
        
        $empresaResult = $empresaStmt->fetch(PDO::FETCH_ASSOC);
        $empresaId = $empresaResult['id'];
        
        // 2. Crear el usuario administrador de la empresa
        $uuid = uniqid('empresa_', true);
        $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
        

        $usuarioQuery = "INSERT INTO usuarios (
            uuid, nombre, apellido, email, telefono, hash_contrasena, 
            tipo_usuario, empresa_id, es_activo
        ) VALUES (?, ?, ?, ?, ?, ?, 'empresa', ?, 1)
        RETURNING id";
        
        $usuarioStmt = $db->prepare($usuarioQuery);
        $usuarioStmt->execute([
            $uuid,
            $nombre,
            $apellido,
            $email,
            trim($input['telefono']),
            $hashedPassword,
            $empresaId
        ]);
        
        $usuarioResult = $usuarioStmt->fetch(PDO::FETCH_ASSOC);
        $userId = $usuarioResult['id'];
        
        // 3. Actualizar la empresa con el creador
        $updateCreador = $db->prepare("UPDATE empresas_transporte SET creado_por = ? WHERE id = ?");
        $updateCreador->execute([$userId, $empresaId]);
        
        // 4. Registrar dispositivo si se proporciona
        if (!empty($input['device_uuid'])) {
            $deviceUuid = trim($input['device_uuid']);
            $deviceStmt = $db->prepare('INSERT INTO user_devices (user_id, device_uuid, trusted) VALUES (?, ?, 1) ON CONFLICT (user_id, device_uuid) DO NOTHING');
            $deviceStmt->execute([$userId, $deviceUuid]);
        }
        
        // 5. Log de auditoría
        logAuditAction($db, null, 'empresa_registrada_publico', 'empresas_transporte', $empresaId, [
            'nombre' => $input['nombre_empresa'],
            'email' => $email,
            'nit' => $input['nit'] ?? null
        ]);
        
        // Confirmar transacción
        $db->commit();
        
        // 6. Enviar email de confirmación al representante
        sendWelcomeEmail($email, $input['nombre_empresa'], $input['representante_nombre']);
        
        // 7. Notificar a los administradores sobre la nueva solicitud
        notifyAdminsNewEmpresa($db, $empresaId, $input['nombre_empresa'], $email, $input['representante_nombre']);
        
        // Respuesta exitosa
        echo json_encode([
            'success' => true,
            'message' => 'Empresa registrada exitosamente. Tu solicitud está pendiente de aprobación.',
            'data' => [
                'empresa_id' => $empresaId,
                'user' => [
                    'id' => $userId,
                    'uuid' => $uuid,
                    'nombre' => $nombre,
                    'apellido' => $apellido,
                    'email' => $email,
                    'telefono' => trim($input['telefono']),
                    'tipo_usuario' => 'empresa',
                    'empresa_id' => $empresaId
                ],
                'estado' => 'pendiente',
                'device_registered' => !empty($input['device_uuid'])
            ]
        ]);
        
    } catch (Exception $e) {
        error_log("=== EMPRESA REGISTER ERROR ===");
        error_log("Error: " . $e->getMessage());
        error_log("Line: " . $e->getLine());
        error_log("File: " . $e->getFile());
        $db->rollBack();
        
        // Devolver error con detalles
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Error interno del servidor',
            'debug_error' => $e->getMessage(),
            'debug_line' => $e->getLine(),
            'debug_file' => basename($e->getFile())
        ]);
        return;
    }

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
        $checkTable = $db->query("SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_name = 'audit_logs'
        )");
        $exists = $checkTable->fetchColumn();
        
        if (!$exists) {
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
 * Validar y guardar logo de empresa en Cloudflare R2
 */
function handleLogoUpload() {
    if (!isset($_FILES['logo']) || $_FILES['logo']['error'] === UPLOAD_ERR_NO_FILE) {
        return null;
    }

    $file = $_FILES['logo'];
    
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

    // Estructura R2: empresas/registros/YYYY/MM/
    $year = date('Y');
    $month = date('m');
    
    $extension = pathinfo($file['name'], PATHINFO_EXTENSION);
    $filename = "empresas/registros/$year/$month/logo_" . time() . '_' . bin2hex(random_bytes(8)) . '.' . $extension;
    
    try {
        require_once __DIR__ . '/../config/R2Service.php';
        $r2 = new R2Service();
        $url = $r2->uploadFile($file['tmp_name'], $filename, $mimeType);
        return $url;
    } catch (Exception $e) {
        error_log('Error subiendo logo a R2: ' . $e->getMessage());
        // No fallar el registro si no se puede subir el logo
        return null;
    }
}

/**
 * Enviar email de bienvenida a la empresa usando PHPMailer
 */
function sendWelcomeEmail($email, $nombreEmpresa, $representante) {
    try {
        if (!class_exists('PHPMailer\PHPMailer\PHPMailer')) {
            error_log("PHPMailer no disponible para enviar email de bienvenida");
            return false;
        }
        
        $mail = new PHPMailer(true);
        
        // Configuración SMTP
        $mail->isSMTP();
        $mail->Host = 'smtp.gmail.com';
        $mail->SMTPAuth = true;
        $mail->Username = 'viaxoficialcol@gmail.com';
        $mail->Password = 'filz vqel gadn kugb';
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port = 587;
        $mail->CharSet = 'UTF-8';
        
        // Remitente y destinatario
        $mail->setFrom('viaxoficialcol@gmail.com', 'Viax');
        $mail->addAddress($email, $representante);
        
        // Contenido del email
        $mail->isHTML(true);
        $mail->Subject = "Bienvenido a Viax - Registro de {$nombreEmpresa}";
        
        $mail->Body = "
        <div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;'>
            <div style='background: linear-gradient(135deg, #2196F3 0%, #1976D2 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;'>
                <h1 style='color: white; margin: 0;'>¡Bienvenido a Viax!</h1>
            </div>
            <div style='padding: 30px; background: #f9f9f9; border-radius: 0 0 10px 10px;'>
                <p style='font-size: 16px;'>Hola <strong>{$representante}</strong>,</p>
                <p>¡Gracias por registrar <strong>{$nombreEmpresa}</strong> en Viax!</p>
                <div style='background: #fff3cd; border: 1px solid #ffc107; padding: 15px; border-radius: 8px; margin: 20px 0;'>
                    <p style='margin: 0; color: #856404;'>
                        <strong>⏳ Estado: Pendiente de Aprobación</strong><br>
                        Tu solicitud será revisada por nuestro equipo en las próximas 24-48 horas.
                    </p>
                </div>
                <p>Una vez aprobada tu empresa, podrás:</p>
                <ul style='line-height: 1.8;'>
                    <li>✅ Gestionar tus conductores</li>
                    <li>✅ Ver estadísticas de viajes</li>
                    <li>✅ Administrar tu flota de vehículos</li>
                    <li>✅ Acceder al panel de empresa</li>
                </ul>
                <p><strong>Te notificaremos por email cuando tu cuenta esté activa.</strong></p>
                <hr style='border: none; border-top: 1px solid #ddd; margin: 20px 0;'>
                <p style='color: #666; font-size: 12px; text-align: center;'>
                    Si tienes alguna pregunta, contáctanos a viaxoficialcol@gmail.com<br>
                    © 2026 Viax - Todos los derechos reservados
                </p>
            </div>
        </div>";
        
        $mail->AltBody = "Hola {$representante},\n\nGracias por registrar {$nombreEmpresa} en Viax.\n\nTu solicitud está pendiente de aprobación. Te notificaremos cuando esté activa.\n\nSaludos,\nEquipo Viax";
        
        $mail->send();
        error_log("Email de bienvenida enviado a: {$email}");
        return true;
        
    } catch (PHPMailerException $e) {
        error_log("Error PHPMailer enviando email de bienvenida: " . $e->getMessage());
        return false;
    } catch (Exception $e) {
        error_log("Error enviando email de bienvenida: " . $e->getMessage());
        return false;
    }
}

/**
 * Enviar notificación a los administradores sobre nueva solicitud de empresa
 */
function notifyAdminsNewEmpresa($db, $empresaId, $nombreEmpresa, $email, $representante) {
    try {
        // Obtener emails de administradores activos
        $query = "SELECT email, nombre FROM usuarios WHERE tipo_usuario = 'administrador' AND activo = true LIMIT 5";
        $stmt = $db->query($query);
        $admins = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        if (empty($admins)) {
            error_log("No hay administradores activos para notificar");
            return;
        }
        
        if (!class_exists('PHPMailer\PHPMailer\PHPMailer')) {
            error_log("PHPMailer no disponible para notificar admins");
            return;
        }
        
        $mail = new PHPMailer(true);
        
        // Configuración SMTP
        $mail->isSMTP();
        $mail->Host = 'smtp.gmail.com';
        $mail->SMTPAuth = true;
        $mail->Username = 'viaxoficialcol@gmail.com';
        $mail->Password = 'filz vqel gadn kugb';
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port = 587;
        $mail->CharSet = 'UTF-8';
        
        $mail->setFrom('viaxoficialcol@gmail.com', 'Viax Sistema');
        
        // Agregar todos los admins como destinatarios
        foreach ($admins as $admin) {
            $mail->addAddress($admin['email'], $admin['nombre']);
        }
        
        $mail->isHTML(true);
        $mail->Subject = "🏢 Nueva Solicitud de Empresa: {$nombreEmpresa}";
        
        $mail->Body = "
        <div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;'>
            <div style='background: linear-gradient(135deg, #FF9800 0%, #F57C00 100%); padding: 20px; text-align: center; border-radius: 10px 10px 0 0;'>
                <h2 style='color: white; margin: 0;'>🏢 Nueva Solicitud de Empresa</h2>
            </div>
            <div style='padding: 25px; background: #fff; border: 1px solid #eee; border-radius: 0 0 10px 10px;'>
                <p>Se ha registrado una nueva empresa que requiere aprobación:</p>
                <table style='width: 100%; border-collapse: collapse; margin: 15px 0;'>
                    <tr>
                        <td style='padding: 10px; border-bottom: 1px solid #eee; font-weight: bold; width: 40%;'>Empresa:</td>
                        <td style='padding: 10px; border-bottom: 1px solid #eee;'>{$nombreEmpresa}</td>
                    </tr>
                    <tr>
                        <td style='padding: 10px; border-bottom: 1px solid #eee; font-weight: bold;'>Representante:</td>
                        <td style='padding: 10px; border-bottom: 1px solid #eee;'>{$representante}</td>
                    </tr>
                    <tr>
                        <td style='padding: 10px; border-bottom: 1px solid #eee; font-weight: bold;'>Email:</td>
                        <td style='padding: 10px; border-bottom: 1px solid #eee;'>{$email}</td>
                    </tr>
                    <tr>
                        <td style='padding: 10px; font-weight: bold;'>ID Empresa:</td>
                        <td style='padding: 10px;'>#{$empresaId}</td>
                    </tr>
                </table>
                <div style='background: #e3f2fd; padding: 15px; border-radius: 8px; text-align: center;'>
                    <p style='margin: 0;'><strong>Acción requerida:</strong> Revisar y aprobar/rechazar desde el panel de administración.</p>
                </div>
            </div>
        </div>";
        
        $mail->AltBody = "Nueva solicitud de empresa: {$nombreEmpresa}\nRepresentante: {$representante}\nEmail: {$email}\nID: #{$empresaId}\n\nRevisar en el panel de administración.";
        
        $mail->send();
        error_log("Notificación enviada a administradores sobre empresa: {$nombreEmpresa}");
        
    } catch (Exception $e) {
        error_log("Error notificando a administradores: " . $e->getMessage());
    }
}
