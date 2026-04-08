<?php
if (!function_exists('viax_load_env')) {
    function viax_load_env(): void
    {
        // No-op para pruebas locales: evita parseo de .env cuando esta corrupto.
    }
}

if (!function_exists('env_value')) {
    function env_value(string $key, $default = null)
    {
        return $default;
    }
}

require_once __DIR__ . '/../backend/services/traffic_pricing.php';
require_once __DIR__ . '/../backend/user/services/CompanyService.php';

$pass = 0;
$fail = 0;

function check($condition, $message)
{
    global $pass, $fail;
    if ($condition) {
        $pass++;
        echo "[PASS] $message\n";
        return;
    }

    $fail++;
    echo "[FAIL] $message\n";
}

$serviceRef = new ReflectionClass(CompanyService::class);
$service = $serviceRef->newInstanceWithoutConstructor();

$isTimeWithinWindow = $serviceRef->getMethod('isTimeWithinWindow');
$isTimeWithinWindow->setAccessible(true);

$calculatePrice = $serviceRef->getMethod('calculatePrice');
$calculatePrice->setAccessible(true);

$inPeak = $isTimeWithinWindow->invoke($service, '07:30:00', '07:00:00', '09:00:00');
check($inPeak === true, 'Hora pico manana (07:30) detectada correctamente');

$inNocturnal = $isTimeWithinWindow->invoke($service, '22:30:00', '21:00:00', '06:00:00');
check($inNocturnal === true, 'Ventana nocturna cruzando medianoche funciona');

$tarifa = [
    'tarifa_base' => 10000,
    'costo_por_km' => 1000,
    'costo_por_minuto' => 100,
    'tarifa_minima' => 0,
    'recargo_hora_pico' => 20,
    'recargo_nocturno' => 0,
    'recargo_festivo' => 0,
    'hora_pico_inicio_manana' => '07:00:00',
    'hora_pico_fin_manana' => '09:00:00',
    'hora_pico_inicio_tarde' => '17:00:00',
    'hora_pico_fin_tarde' => '19:00:00',
    'hora_nocturna_inicio' => '21:00:00',
    'hora_nocturna_fin' => '06:00:00',
];

$result = $calculatePrice->invoke($service, $tarifa, 2.0, 10.0, '07:30:00', 1.0);
check((int)$result['recargo_porcentaje'] === 20, 'Recargo de hora pico aplicado en calculatePrice');
check((int)$result['recargo_precio'] === 2600, 'Monto de recargo de hora pico esperado (2600)');
check((int)$result['total'] === 15600, 'Total calculado con hora pico esperado (15600)');
check(strpos((string)$result['periodo'], 'hora_pico') !== false, 'Periodo incluye hora_pico');

$holidayMeta = [];
$isHoliday = trafficIsHolidayColombia(new DateTime('2026-01-01 12:00:00', new DateTimeZone('America/Bogota')), $holidayMeta);
check($isHoliday === true, 'Festivo legal (1 de enero) detectado correctamente');

$nonHolidayMeta = [];
$isNonHoliday = trafficIsHolidayColombia(new DateTime('2026-01-02 12:00:00', new DateTimeZone('America/Bogota')), $nonHolidayMeta);
check($isNonHoliday === false, 'Dia no festivo (2 de enero) no se marca como festivo');

putenv('APPLY_SUNDAY_AS_HOLIDAY_SURCHARGE=1');
$policyEnabled = trafficShouldApplySundayAsHoliday();
check($policyEnabled === true, 'Politica dominical como festivo habilitada');

$isSunday = trafficIsSundayColombia(new DateTime('2026-03-15 09:00:00', new DateTimeZone('America/Bogota')));
check($isSunday === true, 'Deteccion de domingo correcta (2026-03-15)');

echo "\nResumen: PASS=$pass FAIL=$fail\n";
exit($fail > 0 ? 1 : 0);
