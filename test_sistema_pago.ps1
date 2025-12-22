# Script para probar el sistema completo de pagos y disputas
# Uso: .\test_sistema_pago.ps1

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     🧪 TESTS DEL SISTEMA DE PAGOS Y DISPUTAS        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Selecciona el test a ejecutar:`n" -ForegroundColor Yellow

Write-Host "TESTS INDIVIDUALES:" -ForegroundColor Green
Write-Host "  1. Cliente confirma que SÍ pagó" -ForegroundColor White
Write-Host "  2. Cliente confirma que NO pagó" -ForegroundColor White
Write-Host "  3. Conductor confirma que SÍ recibió pago" -ForegroundColor White
Write-Host "  4. Conductor reporta que NO recibió pago" -ForegroundColor White
Write-Host ""
Write-Host "TESTS DE FLUJO COMPLETO:" -ForegroundColor Green
Write-Host "  5. Crear una DISPUTA (cliente pagó, conductor no recibió)" -ForegroundColor White
Write-Host "  6. Verificar si usuario tiene disputa activa" -ForegroundColor White
Write-Host "  7. Resolver una disputa existente" -ForegroundColor White
Write-Host ""
Write-Host "ESCENARIOS COMPLETOS:" -ForegroundColor Green
Write-Host "  8. Flujo exitoso (ambos confirman pago)" -ForegroundColor White
Write-Host "  9. Flujo sin pago (ambos confirman que no hubo pago)" -ForegroundColor White
Write-Host ""
Write-Host "  0. Salir`n" -ForegroundColor Gray

$opcion = Read-Host "Opción"

switch ($opcion) {
    "1" {
        Write-Host "`n📋 Test: Cliente confirma pago" -ForegroundColor Cyan
        $solicitudId = Read-Host "ID de solicitud"
        $usuarioId = Read-Host "ID de usuario (cliente)"
        php test_cliente_confirma_pago.php $solicitudId $usuarioId
    }
    "2" {
        Write-Host "`n📋 Test: Cliente NO pagó" -ForegroundColor Cyan
        $solicitudId = Read-Host "ID de solicitud"
        $usuarioId = Read-Host "ID de usuario (cliente)"
        php test_cliente_no_pago.php $solicitudId $usuarioId
    }
    "3" {
        Write-Host "`n📋 Test: Conductor recibió pago" -ForegroundColor Cyan
        $solicitudId = Read-Host "ID de solicitud"
        $usuarioId = Read-Host "ID de usuario (conductor)"
        php test_conductor_recibio_pago.php $solicitudId $usuarioId
    }
    "4" {
        Write-Host "`n📋 Test: Conductor NO recibió pago" -ForegroundColor Cyan
        $solicitudId = Read-Host "ID de solicitud"
        $usuarioId = Read-Host "ID de usuario (conductor)"
        php test_conductor_no_recibio.php $solicitudId $usuarioId
    }
    "5" {
        Write-Host "`n📋 Test: Crear DISPUTA" -ForegroundColor Red
        $solicitudId = Read-Host "ID de solicitud"
        $clienteId = Read-Host "ID de cliente"
        $conductorId = Read-Host "ID de conductor"
        php test_crear_disputa.php $solicitudId $clienteId $conductorId
    }
    "6" {
        Write-Host "`n📋 Test: Verificar disputa" -ForegroundColor Cyan
        $usuarioId = Read-Host "ID de usuario"
        php test_verificar_disputa.php $usuarioId
    }
    "7" {
        Write-Host "`n📋 Test: Resolver disputa" -ForegroundColor Green
        $solicitudId = Read-Host "ID de solicitud"
        $conductorId = Read-Host "ID de conductor"
        php test_resolver_disputa.php $solicitudId $conductorId
    }
    "8" {
        Write-Host "`n📋 Escenario: Flujo exitoso completo" -ForegroundColor Green
        $solicitudId = Read-Host "ID de solicitud"
        $clienteId = Read-Host "ID de cliente"
        $conductorId = Read-Host "ID de conductor"
        
        Write-Host "`n1. Cliente confirma pago..." -ForegroundColor Yellow
        php test_cliente_confirma_pago.php $solicitudId $clienteId
        
        Start-Sleep -Seconds 2
        Write-Host "`n2. Conductor confirma recibido..." -ForegroundColor Yellow
        php test_conductor_recibio_pago.php $solicitudId $conductorId
        
        Write-Host "`n✅ FLUJO COMPLETADO SIN DISPUTAS" -ForegroundColor Green
    }
    "9" {
        Write-Host "`n📋 Escenario: Ambos confirman NO hubo pago" -ForegroundColor Yellow
        $solicitudId = Read-Host "ID de solicitud"
        $clienteId = Read-Host "ID de cliente"
        $conductorId = Read-Host "ID de conductor"
        
        Write-Host "`n1. Cliente confirma que NO pagó..." -ForegroundColor Yellow
        php test_cliente_no_pago.php $solicitudId $clienteId
        
        Start-Sleep -Seconds 2
        Write-Host "`n2. Conductor confirma NO recibió..." -ForegroundColor Yellow
        php test_conductor_no_recibio.php $solicitudId $conductorId
        
        Write-Host "`n✅ FLUJO COMPLETADO - Ambos de acuerdo en que no hubo pago" -ForegroundColor Green
    }
    "0" {
        Write-Host "`nSaliendo..." -ForegroundColor Gray
        exit
    }
    default {
        Write-Host "`n❌ Opción inválida" -ForegroundColor Red
    }
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Gray
