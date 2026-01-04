<?php
/**
 * Company Vehicles API
 * Permite a las empresas gestionar sus tipos de vehículo habilitados
 */

require_once '../config/config.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
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

    $empresaId = isset($input['empresa_id']) ? intval($input['empresa_id']) : null;
    
    if (!$empresaId) {
        sendJsonResponse(false, 'Falta parametro empresa_id');
        exit();
    }

    switch ($method) {
        case 'GET':
            handleGetVehicles($db, $empresaId);
            break;
        case 'POST':
            handleToggleVehicle($db, $input, $empresaId);
            break;
        default:
            sendJsonResponse(false, 'Método no permitido');
    }

} catch (Exception $e) {
    error_log("Error in company/vehicles.php: " . $e->getMessage());
    sendJsonResponse(false, 'Error del servidor: ' . $e->getMessage());
}

function handleGetVehicles($db, $empresaId) {
    try {
        // Obtener tipos de vehículo habilitados para esta empresa
        $query = "SELECT DISTINCT tipo_vehiculo FROM configuracion_precios 
                  WHERE empresa_id = ? AND activo = 1";
        $stmt = $db->prepare($query);
        $stmt->execute([$empresaId]);
        $vehicles = $stmt->fetchAll(PDO::FETCH_COLUMN);
        
        sendJsonResponse(true, 'Vehículos obtenidos', [
            'vehiculos' => $vehicles
        ]);
        
    } catch (Exception $e) {
        sendJsonResponse(false, 'Error al leer vehículos: ' . $e->getMessage());
    }
}

function handleToggleVehicle($db, $input, $empresaId) {
    try {
        $tipoVehiculo = $input['tipo_vehiculo'] ?? null;
        $activo = isset($input['activo']) ? intval($input['activo']) : 1;
        
        if (!$tipoVehiculo) {
            sendJsonResponse(false, 'Se requiere tipo_vehiculo');
            return;
        }
        
        // Validar tipo de vehículo
        $tiposValidos = ['moto', 'auto', 'motocarro'];
        if (!in_array($tipoVehiculo, $tiposValidos)) {
            sendJsonResponse(false, 'Tipo de vehículo inválido');
            return;
        }
        
        $db->beginTransaction();
        
        // Verificar si existe configuración para este tipo
        $check = "SELECT id FROM configuracion_precios WHERE empresa_id = ? AND tipo_vehiculo = ?";
        $stmtCheck = $db->prepare($check);
        $stmtCheck->execute([$empresaId, $tipoVehiculo]);
        $exists = $stmtCheck->fetch();
        
        if ($activo) {
            // Habilitar: crear configuración si no existe, o activar si existe
            if ($exists) {
                $sql = "UPDATE configuracion_precios SET activo = 1, fecha_actualizacion = NOW() WHERE id = ?";
                $stmt = $db->prepare($sql);
                $stmt->execute([$exists['id']]);
            } else {
                // Crear nueva configuración con valores por defecto (copiar de global)
                $globalQuery = "SELECT * FROM configuracion_precios WHERE empresa_id IS NULL AND tipo_vehiculo = ? AND activo = 1 LIMIT 1";
                $globalStmt = $db->prepare($globalQuery);
                $globalStmt->execute([$tipoVehiculo]);
                $global = $globalStmt->fetch(PDO::FETCH_ASSOC);
                
                if ($global) {
                    // Copiar de global
                    $sql = "INSERT INTO configuracion_precios (
                            empresa_id, tipo_vehiculo, tarifa_base, costo_por_km, costo_por_minuto,
                            tarifa_minima, tarifa_maxima, recargo_hora_pico, recargo_nocturno, 
                            recargo_festivo, descuento_distancia_larga, umbral_km_descuento,
                            comision_plataforma, comision_metodo_pago, distancia_minima, 
                            distancia_maxima, tiempo_espera_gratis, costo_tiempo_espera, activo
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)";
                    $stmt = $db->prepare($sql);
                    $stmt->execute([
                        $empresaId, $tipoVehiculo,
                        $global['tarifa_base'],
                        $global['costo_por_km'],
                        $global['costo_por_minuto'],
                        $global['tarifa_minima'],
                        $global['tarifa_maxima'],
                        $global['recargo_hora_pico'],
                        $global['recargo_nocturno'],
                        $global['recargo_festivo'],
                        $global['descuento_distancia_larga'],
                        $global['umbral_km_descuento'],
                        $global['comision_plataforma'],
                        $global['comision_metodo_pago'],
                        $global['distancia_minima'],
                        $global['distancia_maxima'],
                        $global['tiempo_espera_gratis'],
                        $global['costo_tiempo_espera']
                    ]);
                } else {
                    // Crear con valores por defecto
                    $sql = "INSERT INTO configuracion_precios (
                            empresa_id, tipo_vehiculo, tarifa_base, costo_por_km, costo_por_minuto,
                            tarifa_minima, activo
                        ) VALUES (?, ?, 5000, 2000, 200, 5000, 1)";
                    $stmt = $db->prepare($sql);
                    $stmt->execute([$empresaId, $tipoVehiculo]);
                }
            }
        } else {
            // Deshabilitar: marcar como inactivo
            if ($exists) {
                $sql = "UPDATE configuracion_precios SET activo = 0, fecha_actualizacion = NOW() WHERE id = ?";
                $stmt = $db->prepare($sql);
                $stmt->execute([$exists['id']]);
            }
            // Si no existe, no hay nada que deshabilitar
        }
        
        $db->commit();
        sendJsonResponse(true, $activo ? 'Vehículo habilitado' : 'Vehículo deshabilitado');
        
    } catch (Exception $e) {
        $db->rollBack();
        error_log("Error Toggle Vehicle: " . $e->getMessage());
        sendJsonResponse(false, 'Error: ' . $e->getMessage());
    }
}
?>
