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
    
    // Procesar tipos_vehiculo de array PostgreSQL a array PHP
    foreach ($empresas as &$empresa) {
        if ($empresa['tipos_vehiculo']) {
            $empresa['tipos_vehiculo'] = pgArrayToPhp($empresa['tipos_vehiculo']);
        } else {
            $empresa['tipos_vehiculo'] = [];
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
    
    // Obtener conductores de la empresa
    $conductoresQuery = "SELECT id, nombre, telefono, email, calificacion_conductor 
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
function createEmpresa($db, $input) {
    // Validar campos requeridos
    if (empty($input['nombre'])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'El nombre de la empresa es requerido']);
        return;
    }
    
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
    
    // Verificar NIT único si se proporciona
    if (!empty($input['nit'])) {
        $checkNit = $db->prepare("SELECT id FROM empresas_transporte WHERE nit = ?");
        $checkNit->execute([$input['nit']]);
        if ($checkNit->fetch()) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Ya existe una empresa con este NIT']);
            return;
        }
    }
    
    // Preparar tipos_vehiculo como array PostgreSQL
    $tiposVehiculo = null;
    if (!empty($input['tipos_vehiculo'])) {
        // En multipart puede venir como string JSON o array directo
        $vehiculos = $input['tipos_vehiculo'];
        if (is_string($vehiculos)) {
            // Intentar decodificar si es string JSON
            $decoded = json_decode($vehiculos, true);
            if (json_last_error() === JSON_ERROR_NONE) {
                $vehiculos = $decoded;
            } else {
                // Si no es JSON, asumir CSV o un solo valor
                $vehiculos = explode(',', $vehiculos);
            }
        }
        
        if (is_array($vehiculos)) {
            $tiposVehiculo = phpArrayToPg($vehiculos);
        }
    }
    
    // Manejar subida de logo
    $logoUrl = $input['logo_url'] ?? null;
    $uploadedLogo = handleLogoUpload();
    if ($uploadedLogo) {
        $logoUrl = $uploadedLogo;
    }
    
    $query = "INSERT INTO empresas_transporte (
                nombre, nit, razon_social, email, telefono, telefono_secundario,
                direccion, municipio, departamento, representante_nombre,
                representante_telefono, representante_email, tipos_vehiculo,
                logo_url, descripcion, estado, creado_por, notas_admin
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              RETURNING id, creado_en";
    
    $stmt = $db->prepare($query);
    $stmt->execute([
        trim($input['nombre']),
        $input['nit'] ?? null,
        $input['razon_social'] ?? null,
        $input['email'] ?? null,
        $input['telefono'] ?? null,
        $input['telefono_secundario'] ?? null,
        $input['direccion'] ?? null,
        $input['ciudad'] ?? null,
        $input['departamento'] ?? null,
        $input['representante_nombre'] ?? null,
        $input['representante_telefono'] ?? null,
        $input['representante_email'] ?? null,
        $tiposVehiculo,
        $logoUrl,
        $input['descripcion'] ?? null,
        $input['estado'] ?? 'activo',
        $adminId,
        $input['notas_admin'] ?? null
    ]);
    
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    // Log de auditoría
    logAuditAction($db, $adminId, 'empresa_creada', 'empresas_transporte', $result['id'], [
        'nombre' => $input['nombre'],
        'nit' => $input['nit'] ?? null
    ]);
    
    echo json_encode([
        'success' => true,
        'message' => 'Empresa creada exitosamente',
        'empresa_id' => $result['id'],
        'creado_en' => $result['creado_en']
    ]);
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

    // Estructura: uploads/empresas/YYYY/MM/
    $year = date('Y');
    $month = date('m');
    $uploadDir = __DIR__ . "/../uploads/empresas/$year/$month/";
    
    if (!file_exists($uploadDir)) {
        if (!mkdir($uploadDir, 0755, true)) {
            throw new Exception('No se pudo crear el directorio de subida');
        }
    }

    // Nombre único
    $extension = pathinfo($file['name'], PATHINFO_EXTENSION);
    $filename = 'logo_' . time() . '_' . bin2hex(random_bytes(8)) . '.' . $extension;
    $targetPath = $uploadDir . $filename;
    
    if (move_uploaded_file($file['tmp_name'], $targetPath)) {
        return "uploads/empresas/$year/$month/$filename";
    }

    throw new Exception('Error al mover el archivo subido');
}

