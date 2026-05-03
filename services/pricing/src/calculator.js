'use strict';

const { commands, parseJson } = require('./redis');

// Motor de cotizacion pre-viaje.
// Replica la logica de calculate_quote.php, pricing_service.php y upfront_pricing_service.php.
// Expone helpers de paridad, pero el cierre final sigue en finalize.php.

const MIN_SURGE = 1.0;
const MAX_SURGE = 2.0;
const DEFAULT_MIN_ACTIVE_REQUESTS = 5;
const DEFAULT_COOLDOWN_SECONDS = 45;
const DEFAULT_UPFRONT_MAX_LOSS_RATIO = 0.20;
const DEFAULT_UPFRONT_DESVIACION_MAXIMA_RATIO = 0.30;
const DEFAULT_MARGIN_PROTECTION_ENABLED = true;
const DEFAULT_SURGE_SCALE_TABLE = [
  { ratio: 1.1, multiplier: 1.2 },
  { ratio: 1.3, multiplier: 1.4 },
  { ratio: 1.5, multiplier: 1.6 },
  { ratio: 2.0, multiplier: 2.0 },
];

const DEFAULT_CONFIGS = {
  moto: {
    tipo_vehiculo: 'moto',
    tarifa_base: 4000,
    costo_por_km: 2000,
    costo_por_minuto: 250,
    tarifa_minima: 6000,
    tarifa_maxima: null,
    recargo_hora_pico: 15,
    recargo_nocturno: 20,
    recargo_festivo: 25,
    descuento_distancia_larga: 10,
    umbral_km_descuento: 15,
    comision_plataforma: 0,
    distancia_minima: 1,
    distancia_maxima: 50,
    hora_pico_inicio_manana: '07:00:00',
    hora_pico_fin_manana: '09:00:00',
    hora_pico_inicio_tarde: '17:00:00',
    hora_pico_fin_tarde: '19:00:00',
    hora_nocturna_inicio: '22:00:00',
    hora_nocturna_fin: '06:00:00',
  },
  mototaxi: {
    tipo_vehiculo: 'mototaxi',
    tarifa_base: 4000,
    costo_por_km: 2000,
    costo_por_minuto: 250,
    tarifa_minima: 6000,
    tarifa_maxima: null,
    recargo_hora_pico: 15,
    recargo_nocturno: 20,
    recargo_festivo: 25,
    descuento_distancia_larga: 10,
    umbral_km_descuento: 15,
    comision_plataforma: 0,
    distancia_minima: 1,
    distancia_maxima: 50,
    hora_pico_inicio_manana: '07:00:00',
    hora_pico_fin_manana: '09:00:00',
    hora_pico_inicio_tarde: '17:00:00',
    hora_pico_fin_tarde: '19:00:00',
    hora_nocturna_inicio: '22:00:00',
    hora_nocturna_fin: '06:00:00',
  },
  carro: {
    tipo_vehiculo: 'carro',
    tarifa_base: 6000,
    costo_por_km: 3000,
    costo_por_minuto: 400,
    tarifa_minima: 9000,
    tarifa_maxima: null,
    recargo_hora_pico: 20,
    recargo_nocturno: 25,
    recargo_festivo: 30,
    descuento_distancia_larga: 10,
    umbral_km_descuento: 15,
    comision_plataforma: 0,
    distancia_minima: 1,
    distancia_maxima: 50,
    hora_pico_inicio_manana: '07:00:00',
    hora_pico_fin_manana: '09:00:00',
    hora_pico_inicio_tarde: '17:00:00',
    hora_pico_fin_tarde: '19:00:00',
    hora_nocturna_inicio: '22:00:00',
    hora_nocturna_fin: '06:00:00',
  },
  taxi: {
    tipo_vehiculo: 'taxi',
    tarifa_base: 7000,
    costo_por_km: 3200,
    costo_por_minuto: 450,
    tarifa_minima: 10000,
    tarifa_maxima: null,
    recargo_hora_pico: 22,
    recargo_nocturno: 28,
    recargo_festivo: 35,
    descuento_distancia_larga: 12,
    umbral_km_descuento: 12,
    comision_plataforma: 0,
    distancia_minima: 0.5,
    distancia_maxima: 100,
    hora_pico_inicio_manana: '07:00:00',
    hora_pico_fin_manana: '09:00:00',
    hora_pico_inicio_tarde: '17:00:00',
    hora_pico_fin_tarde: '19:00:00',
    hora_nocturna_inicio: '22:00:00',
    hora_nocturna_fin: '06:00:00',
  },
};

function toNumber(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function round2(value) {
  return Math.round((toNumber(value, 0) + Number.EPSILON) * 100) / 100;
}

function normalizeCopAmount(value, step = 100) {
  const safeStep = Math.max(1, Number.parseInt(String(step), 10) || 100);
  return Math.round(Math.max(0, toNumber(value, 0)) / safeStep) * safeStep;
}

function formatCop(value) {
  return '$' + Math.round(toNumber(value, 0)).toLocaleString('es-CO');
}

function toBool(value) {
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'number') {
    return Number.isFinite(value) && Math.trunc(value) === 1;
  }

  const normalized = String(value ?? '').trim().toLowerCase();
  return ['1', 'true', 'yes', 'on', 't', 'si', 's'].includes(normalized);
}

function pickNumber(values, fallback = 0) {
  for (const value of values) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }

  return fallback;
}

function pickBool(values, fallback = false) {
  for (const value of values) {
    if (value === undefined || value === null || value === '') {
      continue;
    }

    return toBool(value);
  }

  return fallback;
}

function currentColombiaTime() {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'America/Bogota',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).formatToParts(new Date());

  const byType = Object.fromEntries(parts.map(part => [part.type, part.value]));
  return `${byType.hour}:${byType.minute}:${byType.second}`;
}

function currentColombiaTimestamp() {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Bogota',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).formatToParts(new Date());

  const byType = Object.fromEntries(parts.map(part => [part.type, part.value]));
  return `${byType.year}-${byType.month}-${byType.day} ${byType.hour}:${byType.minute}:${byType.second}`;
}

function isBetweenTime(value, start, end) {
  return String(value) >= String(start) && String(value) <= String(end);
}

function resolveVehicleType(tipoVehiculo) {
  const normalized = String(tipoVehiculo || 'moto').trim().toLowerCase();
  if (normalized === 'auto') {
    return 'carro';
  }
  return normalized || 'moto';
}

function normalizeConfig(rawConfig, tipoVehiculo) {
  const vehicleType = resolveVehicleType(tipoVehiculo);
  const fallback = DEFAULT_CONFIGS[vehicleType] || DEFAULT_CONFIGS.moto;
  const source = rawConfig && typeof rawConfig === 'object' ? rawConfig : {};
  return { ...fallback, ...source, tipo_vehiculo: source.tipo_vehiculo || vehicleType };
}

function resolvePeriod(config, nowTime = currentColombiaTime()) {
  let periodoActual = 'normal';
  let recargoPorcentaje = 0;

  if (isBetweenTime(nowTime, config.hora_pico_inicio_manana, config.hora_pico_fin_manana)) {
    periodoActual = 'hora_pico_manana';
    recargoPorcentaje = toNumber(config.recargo_hora_pico, 0);
  } else if (isBetweenTime(nowTime, config.hora_pico_inicio_tarde, config.hora_pico_fin_tarde)) {
    periodoActual = 'hora_pico_tarde';
    recargoPorcentaje = toNumber(config.recargo_hora_pico, 0);
  } else if (String(nowTime) >= String(config.hora_nocturna_inicio) || String(nowTime) <= String(config.hora_nocturna_fin)) {
    periodoActual = 'nocturno';
    recargoPorcentaje = toNumber(config.recargo_nocturno, 0);
  }

  // calculate_quote.php mantiene festivos en false; se conserva ese comportamiento.
  return { periodoActual, recargoPorcentaje };
}

function gridIdForCoordinates(lat, lng) {
  const latIndex = Math.floor(toNumber(lat, 0) * 100);
  const lngIndex = Math.floor(toNumber(lng, 0) * 100);
  return `${latIndex}:${lngIndex}`;
}

function zoneKeyForCoordinates(lat, lng) {
  return `zone:${gridIdForCoordinates(lat, lng)}`;
}

function normalizeMultiplier(multiplier) {
  return Math.min(MAX_SURGE, Math.max(MIN_SURGE, round2(toNumber(multiplier, MIN_SURGE))));
}

function minActiveRequestsForSurge() {
  return Math.max(1, Math.trunc(toNumber(process.env.SURGE_MIN_ACTIVE_REQUESTS, DEFAULT_MIN_ACTIVE_REQUESTS)));
}

function surgeCooldownSeconds() {
  const parsed = Math.trunc(toNumber(process.env.SURGE_COOLDOWN_SECONDS, DEFAULT_COOLDOWN_SECONDS));
  return Math.max(30, Math.min(120, parsed));
}

function surgeScaleTable() {
  const raw = String(process.env.SURGE_SCALE_JSON || '').trim();
  if (raw === '') {
    return DEFAULT_SURGE_SCALE_TABLE;
  }

  try {
    const decoded = JSON.parse(raw);
    if (!Array.isArray(decoded) || decoded.length === 0) {
      return DEFAULT_SURGE_SCALE_TABLE;
    }

    const table = decoded
      .filter(entry => entry && typeof entry === 'object')
      .map(entry => ({
        ratio: toNumber(entry.ratio, 0),
        multiplier: normalizeMultiplier(entry.multiplier),
      }))
      .filter(entry => entry.ratio > 0)
      .sort((left, right) => left.ratio - right.ratio);

    return table.length > 0 ? table : DEFAULT_SURGE_SCALE_TABLE;
  } catch (_error) {
    return DEFAULT_SURGE_SCALE_TABLE;
  }
}

function resolveSurgeTarget(ratio, activeRequests, availableDrivers) {
  const safeActiveRequests = Math.max(0, Math.trunc(toNumber(activeRequests, 0)));
  const safeAvailableDrivers = Math.max(0, Math.trunc(toNumber(availableDrivers, 0)));
  const safeRatio = toNumber(ratio, 0);
  const minActive = minActiveRequestsForSurge();

  if (safeActiveRequests < minActive) {
    return MIN_SURGE;
  }

  if (safeAvailableDrivers > safeActiveRequests) {
    return MIN_SURGE;
  }

  if (safeRatio <= 1.0) {
    return MIN_SURGE;
  }

  for (const entry of surgeScaleTable()) {
    if (safeRatio < toNumber(entry.ratio, 0)) {
      return normalizeMultiplier(entry.multiplier);
    }
  }

  return MAX_SURGE;
}

function smoothSurge(previous, current, weightPrev = 0.7, weightCurrent = 0.3) {
  const prev = normalizeMultiplier(previous);
  const curr = normalizeMultiplier(current);
  const wp = Math.max(0, Math.min(1, toNumber(weightPrev, 0.7)));
  const wc = Math.max(0, Math.min(1, toNumber(weightCurrent, 0.3)));
  const sum = wp + wc;

  if (sum <= 0) {
    return curr;
  }

  const smoothed = ((prev * wp) + (curr * wc)) / sum;
  if (curr <= MIN_SURGE && smoothed < 1.03) {
    return MIN_SURGE;
  }

  return normalizeMultiplier(smoothed);
}

function demandLevel(multiplier) {
  const m = normalizeMultiplier(multiplier);
  if (m >= 1.55) return 'alta';
  if (m >= 1.30) return 'media';
  if (m > 1.00) return 'leve';
  return 'normal';
}

function demandMessage(multiplier) {
  const level = demandLevel(multiplier);
  if (level === 'alta') return 'Alta demanda, pocos conductores disponibles';
  if (level === 'media') return 'Alta demanda en la zona';
  if (level === 'leve') return 'Demanda ligeramente alta';
  return '';
}

async function getSurgeForZone(zoneKey, redisCommands = commands) {
  const normalizedZoneKey = String(zoneKey || '').trim();
  if (normalizedZoneKey === '') {
    return MIN_SURGE;
  }

  try {
    const cached = await redisCommands.get(`surge_zone:${normalizedZoneKey}`);
    if (typeof cached === 'string' && cached.trim() !== '' && Number.isFinite(Number(cached))) {
      return normalizeMultiplier(Number(cached));
    }
  } catch (error) {
    console.warn('[pricing-service] Error leyendo surge en Redis:', error.message);
  }

  return MIN_SURGE;
}

async function updateZoneDemand(zoneKey, activeRequests, availableDrivers, redisCommands = commands, nowTs = Math.floor(Date.now() / 1000)) {
  const normalizedZoneKey = String(zoneKey || '').trim();
  if (normalizedZoneKey === '') {
    return MIN_SURGE;
  }

  const active = Math.max(0, Math.trunc(toNumber(activeRequests, 0)));
  const available = Math.max(0, Math.trunc(toNumber(availableDrivers, 0)));
  const cooldown = surgeCooldownSeconds();
  const metaKey = `surge_zone_meta:${normalizedZoneKey}`;

  try {
    const cachedMetaRaw = await redisCommands.get(metaKey);
    const cachedMeta = parseJson(cachedMetaRaw);
    if (cachedMeta && typeof cachedMeta === 'object' && cachedMeta.updated_at) {
      const lastUpdate = Math.trunc(toNumber(cachedMeta.updated_at, 0));
      if (lastUpdate > 0 && (nowTs - lastUpdate) < cooldown) {
        const cachedMultiplier = cachedMeta.multiplier !== undefined
          ? cachedMeta.multiplier
          : await getSurgeForZone(normalizedZoneKey, redisCommands);
        return normalizeMultiplier(cachedMultiplier);
      }
    }

    const ratio = available > 0 ? (active / available) : (active > 0 ? 99.0 : 0.0);
    const target = resolveSurgeTarget(ratio, active, available);
    const previous = await getSurgeForZone(normalizedZoneKey, redisCommands);
    const smoothed = smoothSurge(previous, target);
    const payload = {
      active_requests: active,
      available_drivers: available,
      ratio: round2(ratio),
      target: round2(target),
      previous: round2(previous),
      multiplier: round2(smoothed),
      updated_at: nowTs,
      cooldown_seconds: cooldown,
      level: demandLevel(smoothed),
      message: demandMessage(smoothed),
    };

    await redisCommands.set(`surge_zone:${normalizedZoneKey}`, String(smoothed), 'EX', cooldown * 2);
    await redisCommands.set(metaKey, JSON.stringify(payload), 'EX', cooldown * 2);
    return smoothed;
  } catch (error) {
    console.warn('[pricing-service] Error actualizando demanda de zona:', error.message);
    return MIN_SURGE;
  }
}

async function registerRequestInZone(zoneKey, requestId = null, redisCommands = commands) {
  const normalizedZoneKey = String(zoneKey || '').trim();
  if (normalizedZoneKey === '') {
    return;
  }

  const nowMs = Math.round(Date.now());
  const safeRequestId = requestId !== null && toNumber(requestId, 0) > 0 ? Math.trunc(toNumber(requestId, 0)) : 0;
  const member = `${safeRequestId > 0 ? `req:${safeRequestId}` : 'req'}:${nowMs}:${String(Math.random()).slice(-8)}`;
  const recentKey = `${normalizedZoneKey}:recent_requests`;
  const recentCountKey = `${normalizedZoneKey}:recent_requests_count`;
  const activeKey = `${normalizedZoneKey}:active_requests`;
  const windowMs = 5 * 60 * 1000;

  try {
    await redisCommands.zadd(recentKey, nowMs, member);
    await redisCommands.zremrangebyscore(recentKey, 0, nowMs - windowMs);
    await redisCommands.expire(recentKey, 900);

    const recentCount = toNumber(await redisCommands.zcount(recentKey, nowMs - windowMs, nowMs), 0);
    await redisCommands.setex(recentCountKey, 120, String(Math.max(0, Math.trunc(recentCount))));

    const currentActiveRaw = await redisCommands.get(activeKey);
    const currentActive = typeof currentActiveRaw === 'string' && Number.isFinite(Number(currentActiveRaw))
      ? Math.trunc(Number(currentActiveRaw))
      : 0;
    await redisCommands.setex(activeKey, 120, String(Math.max(currentActive, Math.trunc(recentCount))));
  } catch (error) {
    console.warn('[pricing-service] Aviso registrando solicitud en zona:', error.message);
  }
}

function resolveUpfrontMaxLossRatio(metricsReales = {}, precioCongelado = {}) {
  let maxLossRatio = pickNumber([
    metricsReales.max_loss_ratio,
    metricsReales.upfront_max_loss_ratio,
    precioCongelado.max_loss_ratio,
    precioCongelado.upfront_max_loss_ratio,
    process.env.UPFRONT_PRICING_MAX_LOSS_RATIO,
  ], DEFAULT_UPFRONT_MAX_LOSS_RATIO);

  if (maxLossRatio <= 0) {
    maxLossRatio = DEFAULT_UPFRONT_MAX_LOSS_RATIO;
  }

  return maxLossRatio;
}

function resolveUpfrontDesviacionMaximaRatio(metricsReales = {}, precioCongelado = {}) {
  return pickNumber([
    metricsReales.desviacion_maxima_ratio,
    metricsReales.upfront_desviacion_maxima_ratio,
    precioCongelado.desviacion_maxima_ratio,
    precioCongelado.upfront_desviacion_maxima_ratio,
  ], DEFAULT_UPFRONT_DESVIACION_MAXIMA_RATIO);
}

function isMarginProtectionEnabled(metricsReales = {}, precioCongelado = {}) {
  return pickBool([
    metricsReales.margin_protection_enabled,
    precioCongelado.margin_protection_enabled,
    process.env.UPFRONT_PRICING_MARGIN_PROTECTION,
  ], DEFAULT_MARGIN_PROTECTION_ENABLED);
}

function resolverPrecioFinal(precioCongelado = {}, metricsReales = {}) {
  const precioReal = Math.max(0, pickNumber([
    metricsReales.precio_real,
    metricsReales.precio_calculado_real,
    metricsReales.precio_final_real,
    metricsReales.total_real,
    metricsReales.total,
  ], 0));
  const precioFijoNormalizado = Math.max(0, pickNumber([
    precioCongelado.precio_fijo,
    precioCongelado.frozen_price,
    precioCongelado.precio_estimado_usuario,
    precioCongelado.total_normalizado,
    precioCongelado.total,
  ], 0));
  const precioCongeladoActual = pickBool([
    precioCongelado.precio_congelado,
    precioCongelado.frozen,
  ], true);
  const upfrontEnabled = pickBool([
    precioCongelado.upfront_pricing,
    metricsReales.upfront_enabled,
    process.env.UPFRONT_PRICING_ENABLED,
  ], true);
  const trackingValido = pickBool([
    metricsReales.tracking_valido,
    metricsReales.valid_tracking,
  ], true);

  if (!upfrontEnabled || !precioCongeladoActual || precioFijoNormalizado <= 0) {
    return {
      precio_real: round2(precioReal),
      precio_fijo: round2(precioFijoNormalizado),
      precio_final: round2(precioReal),
      precio_congelado: false,
      desviacion_ratio: 0,
      desviacion_porcentaje: 0,
      tracking_valido: trackingValido,
      recalculo_forzado: false,
      reasons: ['fallback_legacy_flow'],
    };
  }

  const desviacionRatio = Math.abs(precioReal - precioFijoNormalizado) / precioFijoNormalizado;
  const desviacionPorcentaje = desviacionRatio * 100;
  const desviacionMaximaRatio = resolveUpfrontDesviacionMaximaRatio(metricsReales, precioCongelado);
  const marginProtectionEnabled = isMarginProtectionEnabled(metricsReales, precioCongelado);
  const maxLossRatio = resolveUpfrontMaxLossRatio(metricsReales, precioCongelado);
  const triggerDestinoCambio = pickBool([
    metricsReales.triggerDestinoCambio,
    metricsReales.trigger_destino_cambio,
    metricsReales.destination_changed,
    metricsReales.cambio_destino,
  ], false);
  const triggerDesvioFuerte = pickBool([
    metricsReales.triggerDesvioFuerte,
    metricsReales.trigger_desvio_fuerte,
    metricsReales.strong_route_deviation,
    metricsReales.desvio_fuerte,
  ], false);
  const triggerParadasAdicionales = pickBool([
    metricsReales.triggerParadasAdicionales,
    metricsReales.trigger_paradas_adicionales,
    metricsReales.additional_stops,
    metricsReales.paradas_adicionales,
  ], false);

  const reasons = [];
  if (trackingValido && desviacionRatio > desviacionMaximaRatio) {
    reasons.push('high_price_deviation');
  }
  if (
    trackingValido &&
    marginProtectionEnabled &&
    precioReal > (precioFijoNormalizado * (1 + maxLossRatio))
  ) {
    reasons.push('margin_protection');
  }
  if (triggerDestinoCambio) {
    reasons.push('destination_changed');
  }
  if (triggerDesvioFuerte) {
    reasons.push('strong_route_deviation');
  }
  if (triggerParadasAdicionales) {
    reasons.push('additional_stops');
  }

  const recalculoForzado = reasons.length > 0;
  const precioFinal = recalculoForzado ? precioReal : precioFijoNormalizado;
  const precioCongeladoFinal = !recalculoForzado;

  return {
    precio_real: round2(precioReal),
    precio_fijo: round2(precioFijoNormalizado),
    precio_final: round2(precioFinal),
    precio_congelado: precioCongeladoFinal,
    desviacion_ratio: Math.round((desviacionRatio + Number.EPSILON) * 1000000) / 1000000,
    desviacion_porcentaje: round2(desviacionPorcentaje),
    tracking_valido: trackingValido,
    recalculo_forzado: recalculoForzado,
    reasons,
  };
}

function calcularCompensacionConductor(distanciaRealKm, tiempoRealMin, tarifaPorKm, tarifaPorMin, comisionPorcentaje) {
  const distancia = Math.max(0, toNumber(distanciaRealKm, 0));
  const tiempo = Math.max(0, Math.trunc(toNumber(tiempoRealMin, 0)));
  const tarifaKm = Math.max(0, toNumber(tarifaPorKm, 0));
  const tarifaMin = Math.max(0, toNumber(tarifaPorMin, 0));
  const comision = Math.min(100, Math.max(0, toNumber(comisionPorcentaje, 0)));
  const costoReal = (distancia * tarifaKm) + (tiempo * tarifaMin);
  const comisionValor = costoReal * (comision / 100);
  const pagoConductor = Math.max(0, costoReal - comisionValor);

  return {
    costo_real: round2(costoReal),
    comision_porcentaje: round2(comision),
    comision_valor: round2(comisionValor),
    pago_conductor: round2(pagoConductor),
  };
}

async function calcularCotizacion(params, config, options = {}) {
  const context = options && typeof options === 'object' && !Array.isArray(options) ? options : {};
  const tipoVehiculo = resolveVehicleType(params.tipo_vehiculo || params.vehicle_type);
  const effectiveConfig = normalizeConfig(config, tipoVehiculo);
  const distanciaKm = toNumber(params.distancia_km ?? params.distance_km, 0);
  const duracionMinutos = Math.trunc(toNumber(params.duracion_minutos ?? params.time_min, 0));

  if (distanciaKm <= 0) {
    throw new Error('La distancia debe ser mayor a 0');
  }
  if (duracionMinutos <= 0) {
    throw new Error('La duracion debe ser mayor a 0');
  }

  const distanciaMinima = toNumber(effectiveConfig.distancia_minima, 0);
  const distanciaMaxima = toNumber(effectiveConfig.distancia_maxima, Number.POSITIVE_INFINITY);
  if (distanciaKm < distanciaMinima) {
    throw new Error(`La distancia minima es ${distanciaMinima} km`);
  }
  if (distanciaKm > distanciaMaxima) {
    throw new Error(`La distancia maxima es ${distanciaMaxima} km`);
  }

  const tarifaBase = toNumber(effectiveConfig.tarifa_base, 0);
  const precioDistancia = distanciaKm * toNumber(effectiveConfig.costo_por_km, 0);
  const precioTiempo = duracionMinutos * toNumber(effectiveConfig.costo_por_minuto, 0);
  const subtotal = tarifaBase + precioDistancia + precioTiempo;

  let descuentoDistancia = 0;
  if (distanciaKm >= toNumber(effectiveConfig.umbral_km_descuento, Number.POSITIVE_INFINITY)) {
    descuentoDistancia = subtotal * (toNumber(effectiveConfig.descuento_distancia_larga, 0) / 100);
  }

  const subtotalConDescuento = subtotal - descuentoDistancia;
  const { periodoActual, recargoPorcentaje } = resolvePeriod(effectiveConfig, params.hora_actual || currentColombiaTime());
  const recargoPrecio = recargoPorcentaje > 0 ? subtotalConDescuento * (recargoPorcentaje / 100) : 0;
  const zoneKey = zoneKeyForCoordinates(params.lat_origen ?? params.lat, params.lng_origen ?? params.lng);
  const safeSurge = await getSurgeForZone(zoneKey, context.redisCommands || commands);
  const surgePrecio = subtotalConDescuento * (safeSurge - 1);

  let total = subtotalConDescuento + recargoPrecio + surgePrecio;
  const tarifaMinima = toNumber(effectiveConfig.tarifa_minima, 0);
  if (total < tarifaMinima) {
    total = tarifaMinima;
  }
  if (effectiveConfig.tarifa_maxima !== null && effectiveConfig.tarifa_maxima !== undefined && effectiveConfig.tarifa_maxima !== '') {
    total = Math.min(total, toNumber(effectiveConfig.tarifa_maxima, total));
  }

  const distanciaRealKm = pickNumber([
    params.distancia_real_km,
    params.distance_real_km,
    params.real_distance_km,
    params.distancia_km_real,
    distanciaKm,
  ], distanciaKm);
  const tiempoRealMin = Math.trunc(pickNumber([
    params.tiempo_real_min,
    params.tiempo_real_minutos,
    params.duration_real_min,
    params.real_time_min,
    params.duracion_real_minutos,
    duracionMinutos,
  ], duracionMinutos));
  const compensacionConductor = calcularCompensacionConductor(
    distanciaRealKm,
    tiempoRealMin,
    effectiveConfig.costo_por_km,
    effectiveConfig.costo_por_minuto,
    effectiveConfig.comision_plataforma,
  );
  const totalNormalizado = normalizeCopAmount(total, 100);
  const gridId = gridIdForCoordinates(params.lat_origen ?? params.lat, params.lng_origen ?? params.lng);

  return {
    distancia_km: round2(distanciaKm),
    duracion_minutos: duracionMinutos,
    tipo_vehiculo: tipoVehiculo,
    tarifa_base: round2(tarifaBase),
    precio_distancia: round2(precioDistancia),
    precio_tiempo: round2(precioTiempo),
    subtotal: round2(subtotal),
    descuento_distancia: round2(descuentoDistancia),
    descuento_porcentaje: descuentoDistancia > 0 ? toNumber(effectiveConfig.descuento_distancia_larga, 0) : 0,
    subtotal_con_descuento: round2(subtotalConDescuento),
    periodo_actual: periodoActual,
    recargo_porcentaje: round2(recargoPorcentaje),
    recargo_precio: round2(recargoPrecio),
    surge_multiplier: round2(safeSurge),
    surge_precio: round2(surgePrecio),
    surge_level: demandLevel(safeSurge),
    surge_message: demandMessage(safeSurge),
    total: round2(total),
    total_normalizado: totalNormalizado,
    total_formateado: formatCop(total),
    tarifa_minima_aplicada: round2(total) === round2(tarifaMinima),
    comision_plataforma: compensacionConductor.comision_valor,
    comision_porcentaje: compensacionConductor.comision_porcentaje,
    costo_real_conductor: compensacionConductor.costo_real,
    ganancia_conductor: compensacionConductor.pago_conductor,
    precio_estimado_usuario: totalNormalizado,
    precio_congelado: true,
    frozen_price: totalNormalizado,
    upfront_pricing: true,
    calculado_en: currentColombiaTimestamp(),
    zone_key: zoneKey,
    grid_id: gridId,
  };
}

module.exports = {
  calcularCotizacion,
  DEFAULT_CONFIGS,
  calcularCompensacionConductor,
  demandLevel,
  demandMessage,
  getSurgeForZone,
  gridIdForCoordinates,
  minActiveRequestsForSurge,
  normalizeMultiplier,
  normalizeConfig,
  normalizeCopAmount,
  registerRequestInZone,
  resolveSurgeTarget,
  resolverPrecioFinal,
  smoothSurge,
  surgeCooldownSeconds,
  surgeScaleTable,
  updateZoneDemand,
  zoneKeyForCoordinates,
};
