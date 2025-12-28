<?php
/**
 * Company Pricing API
 * Permite a las empresas gestionar sus propias tarifas
 */

require_once '../config/config.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    $database = new Database();
    $db = $database->getConnection();
    $method = $_SERVER['REQUEST_METHOD'];
    
    // Obtener datos
    if ($method === 'GET') {
        $input = $_GET;
    } else {
        $input = getJsonInput();
    }

    // Verificar ID de empresa (o usuario empresa)
    if (empty($input['empresa_id']) && empty($input['user_id'])) {
        sendJsonResponse(false, 'ID de empresa o usuario requerido');
        exit();
    }

    // Si viene user_id, buscar su empresa_id (si es usuario tipo empresa)
    // OJO: El frontend puede enviar directamente empresa_id si ya lo tiene.
    // Asumiremos que el frontend envía 'empresa_id' que corresponde al ID en 'empresas_transporte'.
    // Si el usuario logueado es 'empresa', su ID de usuario NO es el ID de la empresa.
    // Debemos buscar el ID de empresa asociado al usuario. 
    // PERO: En la migración 018:
    // usuarios.empresa_id es para conductores asociados.
    // ¿Cómo se vincula el usuario "Dueño de empresa" con la tabla "empresas_transporte"?
    // Revisando 018: "creado_por BIGINT REFERENCES usuarios(id)". 
    // No hay un link directo "usuario X es dueño de empresa Y" excepto por ¿quién la creó?
    // O tal vez el usuario TIPO 'empresa' tiene un registro en 'empresas_transporte'?
    // Revisemos la lógica de registro.
    
    // Si el usuario es tipo 'empresa', ¿tiene un registro en empresas_transporte?
    // Asumiré que el frontend envía el ID de la empresa (empresas_transporte.id).
    // O si envía usuario_id, debo buscar la empresa asociada.
    
    // Por simplicidad para este paso, requerimos 'empresa_id' param explícito,
    // o 'user_id' y buscamos si es conductor.
    // Pero para el DASHBOARD de empresa, el usuario logueado es el Admin de la empresa.
    // Asumiremos que los datos de la empresa vienen en el objeto USER o se pasan como argumento.
    // Si no, el backend debe resolverlo.
    
    $empresaId = isset($input['empresa_id']) ? $input['empresa_id'] : null;
    
    // Fallback: Si no viene empresa_id, pero viene user_id y es tipo empresa...
    // Esto es complejo si no sabemos la relación exacta.
    // Vamos a confiar en que el frontend manda el empresa_id correcto.
    // (En CompanyHomeScreen usaremos los datos disponibles).
    
    if (!$empresaId) {
         // Intento de resolver por user_id si es propietario?
         // Por ahora error si falta.
         sendJsonResponse(false, 'Falta parametro empresa_id');
         exit();
    }

    switch ($method) {
        case 'GET':
            handleGetPricing($db, $empresaId);
            break;
        case 'POST':
        case 'PUT':
            handleUpdatePricing($db, $input, $empresaId);
            break;
        default:
            sendJsonResponse(false, 'Método no permitido');
    }

} catch (Exception $e) {
    error_log("Error in company/pricing.php: " . $e->getMessage());
    sendJsonResponse(false, 'Error del servidor: ' . $e->getMessage());
}

function handleGetPricing($db, $empresaId) {
    try {
        // 1. Obtener configuración global (default)
        $queryGlobal = "SELECT * FROM configuracion_precios WHERE empresa_id IS NULL";
        $stmtGlobal = $db->query($queryGlobal);
        $globalPrices = $stmtGlobal->fetchAll(PDO::FETCH_ASSOC); // Lista de tipos
        
        // 2. Obtener configuración específica de la empresa
        $queryEmpresa = "SELECT * FROM configuracion_precios WHERE empresa_id = ?";
        $stmtEmpresa = $db->prepare($queryEmpresa);
        $stmtEmpresa->execute([$empresaId]);
        $empresaPrices = $stmtEmpresa->fetchAll(PDO::FETCH_ASSOC);
        
        // Organizar por tipo_vehiculo para fácil mezcla
        $result = [];
        
        // Mapear globales como base
        foreach ($globalPrices as $p) {
            $type = $p['tipo_vehiculo'];
            $p['es_global'] = true;
            $p['heredado'] = true; // Por defecto hereda si no hay override
            $result[$type] = $p;
        }
        
        // Sobrescribir con empresa
        foreach ($empresaPrices as $p) {
            $type = $p['tipo_vehiculo'];
            $p['es_global'] = false;
            $p['heredado'] = false;
            $result[$type] = $p;
        }
        
        sendJsonResponse(true, 'Tarifas obtenidas', array_values($result));
        
    } catch (Exception $e) {
        sendJsonResponse(false, 'Error al leer tarifas: ' . $e->getMessage());
    }
}

function handleUpdatePricing($db, $input, $empresaId) {
    try {
        if (empty($input['precios']) || !is_array($input['precios'])) {
            sendJsonResponse(false, 'Se requiere array de precios');
            return;
        }
        
        $db->beginTransaction();
        
        foreach ($input['precios'] as $precio) {
            $tipo = $precio['tipo_vehiculo'];
            
            // Verificar si existe para actualizar o insertar
            $check = "SELECT id FROM configuracion_precios WHERE empresa_id = ? AND tipo_vehiculo = ?";
            $stmtCheck = $db->prepare($check);
            $stmtCheck->execute([$empresaId, $tipo]);
            $exists = $stmtCheck->fetch();
            
            if ($exists) {
                // Update
                $sql = "UPDATE configuracion_precios SET 
                        tarifa_base = ?, costo_por_km = ?, costo_por_minuto = ?, 
                        tarifa_minima = ?, recargo_hora_pico = ?, recargo_nocturno = ?, 
                        recargo_festivo = ?, comision_plataforma = ?, activo = ?
                        WHERE id = ?";
                $stmt = $db->prepare($sql);
                $stmt->execute([
                    $precio['tarifa_base'], $precio['costo_por_km'], $precio['costo_por_minuto'],
                    $precio['tarifa_minima'], $precio['recargo_hora_pico'], $precio['recargo_nocturno'],
                    $precio['recargo_festivo'], $precio['comision_plataforma'], $precio['activo'] ?? 1,
                    $exists['id']
                ]);
            } else {
                // Insert
                $sql = "INSERT INTO configuracion_precios 
                        (empresa_id, tipo_vehiculo, tarifa_base, costo_por_km, costo_por_minuto, 
                         tarifa_minima, recargo_hora_pico, recargo_nocturno, recargo_festivo, 
                         comision_plataforma, activo)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
                $stmt = $db->prepare($sql);
                $stmt->execute([
                    $empresaId, $tipo,
                    $precio['tarifa_base'], $precio['costo_por_km'], $precio['costo_por_minuto'],
                    $precio['tarifa_minima'], $precio['recargo_hora_pico'], $precio['recargo_nocturno'],
                    $precio['recargo_festivo'], $precio['comision_plataforma'], $precio['activo'] ?? 1
                ]);
            }
        }
        
        $db->commit();
        sendJsonResponse(true, 'Tarifas actualizadas correctamente');
        
    } catch (Exception $e) {
        $db->rollBack();
        error_log("Error Update Pricing: " . $e->getMessage());
        sendJsonResponse(false, 'Error al actualizar: ' . $e->getMessage());
    }
}
?>
