<?php
/**
 * Test interactivo del sistema de pagos y disputas
 * 
 * Uso: php test_pago.php
 */

require_once __DIR__ . '/backend/config/database.php';

// Colores para la consola
function verde($texto) { return "\033[32m$texto\033[0m"; }
function rojo($texto) { return "\033[31m$texto\033[0m"; }
function amarillo($texto) { return "\033[33m$texto\033[0m"; }
function cyan($texto) { return "\033[36m$texto\033[0m"; }

echo "\n" . cyan("╔════════════════════════════════════════════════════════╗") . "\n";
echo cyan("║") . "     🧪 TEST SISTEMA DE PAGOS Y DISPUTAS              " . cyan("║") . "\n";
echo cyan("╚════════════════════════════════════════════════════════╝") . "\n\n";

try {
    $db = (new Database())->getConnection();
    
    // Buscar última solicitud con conductor
    $stmt = $db->query("
        SELECT 
            s.id,
            s.cliente_id,
            a.conductor_id,
            s.estado,
            s.cliente_confirma_pago,
            s.conductor_confirma_recibo,
            s.tiene_disputa,
            uc.nombre as cliente_nombre,
            ucon.nombre as conductor_nombre
        FROM solicitudes_servicio s
        JOIN asignaciones_conductor a ON s.id = a.solicitud_id
        LEFT JOIN usuarios uc ON s.cliente_id = uc.id
        LEFT JOIN usuarios ucon ON a.conductor_id = ucon.id
        ORDER BY s.id DESC
        LIMIT 1
    ");
    $sol = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$sol) {
        echo rojo("❌ No hay solicitudes con conductor asignado\n");
        exit(1);
    }
    
    $solicitudId = $sol['id'];
    $clienteId = $sol['cliente_id'];
    $conductorId = $sol['conductor_id'];
    
    echo "📋 " . amarillo("Solicitud #$solicitudId") . "\n";
    echo "   👤 Cliente: {$sol['cliente_nombre']} (ID: $clienteId)\n";
    echo "   🚗 Conductor: {$sol['conductor_nombre']} (ID: $conductorId)\n";
    echo "   📊 Estado: {$sol['estado']}\n";
    
    $cliConf = $sol['cliente_confirma_pago'];
    $conConf = $sol['conductor_confirma_recibo'];
    
    echo "\n   💰 Estado de pagos:\n";
    echo "      • Cliente confirma pago: " . ($cliConf === null ? amarillo("Sin confirmar") : ($cliConf ? verde("SÍ") : rojo("NO"))) . "\n";
    echo "      • Conductor confirma recibo: " . ($conConf === null ? amarillo("Sin confirmar") : ($conConf ? verde("SÍ") : rojo("NO"))) . "\n";
    echo "      • Tiene disputa: " . ($sol['tiene_disputa'] ? rojo("SÍ") : verde("NO")) . "\n";
    
    echo "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    echo "Selecciona una acción:\n\n";
    echo "  " . verde("1") . ". Cliente confirma: SÍ PAGUÉ\n";
    echo "  " . verde("2") . ". Cliente confirma: NO PAGUÉ\n";
    echo "  " . cyan("3") . ". Conductor confirma: SÍ RECIBÍ\n";
    echo "  " . cyan("4") . ". Conductor confirma: NO RECIBÍ\n";
    echo "  " . amarillo("5") . ". Verificar disputa del cliente\n";
    echo "  " . amarillo("6") . ". Verificar disputa del conductor\n";
    echo "  " . rojo("7") . ". Limpiar estados (reset)\n";
    echo "  0. Salir\n\n";
    
    echo "Opción: ";
    $opcion = trim(fgets(STDIN));
    
    echo "\n";
    
    switch ($opcion) {
        case '1':
            clienteConfirma($db, $solicitudId, $clienteId, true);
            break;
        case '2':
            clienteConfirma($db, $solicitudId, $clienteId, false);
            break;
        case '3':
            conductorConfirma($db, $solicitudId, $conductorId, true);
            break;
        case '4':
            conductorConfirma($db, $solicitudId, $conductorId, false);
            break;
        case '5':
            verificarDisputa($db, $clienteId, 'cliente');
            break;
        case '6':
            verificarDisputa($db, $conductorId, 'conductor');
            break;
        case '7':
            limpiarEstados($db, $solicitudId, $clienteId, $conductorId);
            break;
        case '0':
            echo "👋 Saliendo...\n";
            break;
        default:
            echo rojo("❌ Opción inválida\n");
    }
    
} catch (Exception $e) {
    echo rojo("❌ Error: " . $e->getMessage()) . "\n";
    exit(1);
}

// ============ FUNCIONES ============

function clienteConfirma($db, $solicitudId, $clienteId, $pago) {
    $db->beginTransaction();
    
    try {
        // Actualizar
        $stmt = $db->prepare("UPDATE solicitudes_servicio SET cliente_confirma_pago = ? WHERE id = ?");
        $stmt->execute([$pago, $solicitudId]);
        
        echo verde("✅ Cliente confirmó: " . ($pago ? "SÍ PAGUÉ" : "NO PAGUÉ")) . "\n";
        
        // Verificar disputa
        verificarYCrearDisputa($db, $solicitudId, $clienteId);
        
        $db->commit();
    } catch (Exception $e) {
        $db->rollBack();
        throw $e;
    }
}

function conductorConfirma($db, $solicitudId, $conductorId, $recibio) {
    $db->beginTransaction();
    
    try {
        // Actualizar
        $stmt = $db->prepare("UPDATE solicitudes_servicio SET conductor_confirma_recibo = ? WHERE id = ?");
        $stmt->execute([$recibio, $solicitudId]);
        
        echo cyan("✅ Conductor confirmó: " . ($recibio ? "SÍ RECIBÍ" : "NO RECIBÍ")) . "\n";
        
        // Verificar disputa
        verificarYCrearDisputa($db, $solicitudId, $conductorId);
        
        $db->commit();
    } catch (Exception $e) {
        $db->rollBack();
        throw $e;
    }
}

function verificarYCrearDisputa($db, $solicitudId, $usuarioActual) {
    $stmt = $db->prepare("
        SELECT s.cliente_id, s.cliente_confirma_pago, s.conductor_confirma_recibo, s.tiene_disputa, a.conductor_id
        FROM solicitudes_servicio s
        JOIN asignaciones_conductor a ON s.id = a.solicitud_id
        WHERE s.id = ?
    ");
    $stmt->execute([$solicitudId]);
    $sol = $stmt->fetch(PDO::FETCH_ASSOC);
    
    $cliConf = $sol['cliente_confirma_pago'];
    $conConf = $sol['conductor_confirma_recibo'];
    
    // Solo crear disputa si ambos confirmaron Y hay desacuerdo
    if ($cliConf !== null && $conConf !== null && !$sol['tiene_disputa']) {
        // Disputa: Cliente dice SÍ pagó, Conductor dice NO recibió
        if ($cliConf == true && $conConf == false) {
            echo "\n" . rojo("🔥 CONFLICTO DETECTADO") . "\n";
            echo "   • Cliente dice: SÍ pagué\n";
            echo "   • Conductor dice: NO recibí\n\n";
            
            // Crear disputa
            $stmt = $db->prepare("
                INSERT INTO disputas_pago (solicitud_id, cliente_id, conductor_id, cliente_confirma_pago, conductor_confirma_recibo, estado, creado_en)
                VALUES (?, ?, ?, TRUE, FALSE, 'pendiente', NOW())
                RETURNING id
            ");
            $stmt->execute([$solicitudId, $sol['cliente_id'], $sol['conductor_id']]);
            $disputaId = $stmt->fetchColumn();
            
            // Actualizar solicitud
            $stmt = $db->prepare("UPDATE solicitudes_servicio SET tiene_disputa = TRUE, disputa_id = ? WHERE id = ?");
            $stmt->execute([$disputaId, $solicitudId]);
            
            // Suspender ambas cuentas
            $stmt = $db->prepare("UPDATE usuarios SET tiene_disputa_activa = TRUE, disputa_activa_id = ? WHERE id IN (?, ?)");
            $stmt->execute([$disputaId, $sol['cliente_id'], $sol['conductor_id']]);
            
            echo rojo("🔒 DISPUTA CREADA (ID: $disputaId)") . "\n";
            echo rojo("🔒 Ambas cuentas SUSPENDIDAS") . "\n";
        } else {
            echo verde("\n✓ No hay conflicto - Viaje completado correctamente") . "\n";
        }
    }
}

function verificarDisputa($db, $usuarioId, $tipo) {
    $stmt = $db->prepare("SELECT tiene_disputa_activa, disputa_activa_id FROM usuarios WHERE id = ?");
    $stmt->execute([$usuarioId]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($user['tiene_disputa_activa']) {
        echo rojo("🔒 $tipo (ID: $usuarioId) tiene cuenta SUSPENDIDA") . "\n";
        echo "   Disputa ID: {$user['disputa_activa_id']}\n";
    } else {
        echo verde("✅ $tipo (ID: $usuarioId) NO tiene disputas activas") . "\n";
    }
}

function limpiarEstados($db, $solicitudId, $clienteId, $conductorId) {
    // Limpiar solicitud
    $stmt = $db->prepare("
        UPDATE solicitudes_servicio 
        SET cliente_confirma_pago = NULL, 
            conductor_confirma_recibo = NULL,
            tiene_disputa = FALSE,
            disputa_id = NULL
        WHERE id = ?
    ");
    $stmt->execute([$solicitudId]);
    
    // Limpiar usuarios
    $stmt = $db->prepare("
        UPDATE usuarios 
        SET tiene_disputa_activa = FALSE, 
            disputa_activa_id = NULL
        WHERE id IN (?, ?)
    ");
    $stmt->execute([$clienteId, $conductorId]);
    
    // Eliminar disputas de esta solicitud
    $stmt = $db->prepare("DELETE FROM disputas_pago WHERE solicitud_id = ?");
    $stmt->execute([$solicitudId]);
    
    echo verde("✅ Estados limpiados - Listo para nueva prueba") . "\n";
}

echo "\n";
