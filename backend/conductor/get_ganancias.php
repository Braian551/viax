<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');
header('Access-Control-Allow-Headers: Content-Type, Accept');

require_once '../config/database.php';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Método no permitido']);
    exit();
}

try {
    $database = new Database();
    $db = $database->getConnection();

    $conductor_id = isset($_GET['conductor_id']) ? intval($_GET['conductor_id']) : 0;
    $fecha_inicio = isset($_GET['fecha_inicio']) ? $_GET['fecha_inicio'] : date('Y-m-d');
    $fecha_fin = isset($_GET['fecha_fin']) ? $_GET['fecha_fin'] : date('Y-m-d');

    if ($conductor_id <= 0) {
        throw new Exception('ID de conductor inválido');
    }

    // Calcular ganancias desde solicitudes_servicio
    // Prioridad de precio: tracking > precio_final > precio_estimado
    $query_total = "SELECT 
                     COALESCE(SUM(
                       COALESCE(
                         NULLIF(vrt.precio_final_aplicado, 0),
                         NULLIF(s.precio_final, 0),
                         s.precio_estimado
                       ) * 0.90
                     ), 0) as total_ganancias,
                     COALESCE(SUM(
                       COALESCE(
                         NULLIF(vrt.precio_final_aplicado, 0),
                         NULLIF(s.precio_final, 0),
                         s.precio_estimado
                       ) * 0.10
                     ), 0) as total_comision,
                     COALESCE(SUM(
                       COALESCE(
                         NULLIF(vrt.precio_final_aplicado, 0),
                         NULLIF(s.precio_final, 0),
                         s.precio_estimado
                       )
                     ), 0) as total_cobrado,
                     COUNT(s.id) as total_viajes
                    FROM solicitudes_servicio s
                    INNER JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id
                    LEFT JOIN viaje_resumen_tracking vrt ON s.id = vrt.solicitud_id
                    WHERE ac.conductor_id = :conductor_id
                    AND s.estado IN ('completada', 'entregado')
                    AND DATE(COALESCE(s.completado_en, s.solicitado_en)) BETWEEN :fecha_inicio AND :fecha_fin";
    
    $stmt_total = $db->prepare($query_total);
    $stmt_total->bindParam(':conductor_id', $conductor_id, PDO::PARAM_INT);
    $stmt_total->bindParam(':fecha_inicio', $fecha_inicio, PDO::PARAM_STR);
    $stmt_total->bindParam(':fecha_fin', $fecha_fin, PDO::PARAM_STR);
    $stmt_total->execute();
    $totales = $stmt_total->fetch(PDO::FETCH_ASSOC);

    // Calcular comisión total adeudada (de TODOS los viajes, no solo del período)
    // Usar precio REAL del tracking cuando esté disponible
    $query_comision_total = "SELECT 
                              COALESCE(SUM(
                                COALESCE(
                                  NULLIF(vrt.precio_final_aplicado, 0),
                                  NULLIF(s.precio_final, 0),
                                  s.precio_estimado
                                ) * 0.10
                              ), 0) as comision_adeudada
                             FROM solicitudes_servicio s
                             INNER JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id
                             LEFT JOIN viaje_resumen_tracking vrt ON s.id = vrt.solicitud_id
                             WHERE ac.conductor_id = :conductor_id
                             AND s.estado IN ('completada', 'entregado')";
    
    $stmt_comision = $db->prepare($query_comision_total);
    $stmt_comision->bindParam(':conductor_id', $conductor_id, PDO::PARAM_INT);
    $stmt_comision->execute();
    $comision_data = $stmt_comision->fetch(PDO::FETCH_ASSOC);

    // Ganancias por día - usando precio REAL del tracking
    $query_diario = "SELECT 
                      DATE(COALESCE(s.completado_en, s.solicitado_en)) as fecha,
                      COALESCE(SUM(
                        COALESCE(
                          NULLIF(vrt.precio_final_aplicado, 0),
                          NULLIF(s.precio_final, 0),
                          s.precio_estimado
                        ) * 0.90
                      ), 0) as ganancias,
                      COALESCE(SUM(
                        COALESCE(
                          NULLIF(vrt.precio_final_aplicado, 0),
                          NULLIF(s.precio_final, 0),
                          s.precio_estimado
                        ) * 0.10
                      ), 0) as comision,
                      COUNT(s.id) as viajes
                     FROM solicitudes_servicio s
                     INNER JOIN asignaciones_conductor ac ON s.id = ac.solicitud_id
                     LEFT JOIN viaje_resumen_tracking vrt ON s.id = vrt.solicitud_id
                     WHERE ac.conductor_id = :conductor_id
                     AND s.estado IN ('completada', 'entregado')
                     AND DATE(COALESCE(s.completado_en, s.solicitado_en)) BETWEEN :fecha_inicio AND :fecha_fin
                     GROUP BY DATE(COALESCE(s.completado_en, s.solicitado_en))
                     ORDER BY fecha DESC";
    
    $stmt_diario = $db->prepare($query_diario);
    $stmt_diario->bindParam(':conductor_id', $conductor_id, PDO::PARAM_INT);
    $stmt_diario->bindParam(':fecha_inicio', $fecha_inicio, PDO::PARAM_STR);
    $stmt_diario->bindParam(':fecha_fin', $fecha_fin, PDO::PARAM_STR);
    $stmt_diario->execute();
    $ganancias_diarias = $stmt_diario->fetchAll(PDO::FETCH_ASSOC);

    // Formatear desglose diario
    $desglose = array_map(function($dia) {
        return [
            'fecha' => $dia['fecha'],
            'ganancias' => floatval($dia['ganancias']),
            'comision' => floatval($dia['comision']),
            'viajes' => intval($dia['viajes'])
        ];
    }, $ganancias_diarias);

    echo json_encode([
        'success' => true,
        'ganancias' => [
            'total' => floatval($totales['total_ganancias']),
            'total_cobrado' => floatval($totales['total_cobrado']),
            'total_viajes' => intval($totales['total_viajes']),
            'comision_periodo' => floatval($totales['total_comision']),
            'comision_adeudada' => floatval($comision_data['comision_adeudada']),
            'promedio_por_viaje' => $totales['total_viajes'] > 0 
                ? round(floatval($totales['total_ganancias']) / intval($totales['total_viajes']), 2)
                : 0,
            'desglose_diario' => $desglose
        ],
        'periodo' => [
            'inicio' => $fecha_inicio,
            'fin' => $fecha_fin
        ],
        'message' => 'Ganancias obtenidas exitosamente'
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
