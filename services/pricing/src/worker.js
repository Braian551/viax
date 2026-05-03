'use strict';

// Worker principal del pricing-service.
// Modo shadow: calcula cotizaciones en paralelo al PHP para validacion.
// Canal entrada: pricing:quote_queue
// Canal salida: pricing:quote_result:{request_id}
// Canal shadow: pricing:shadow_diff

const { subscriber, publisher, commands, parseJson, publish } = require('./redis');
const { calcularCotizacion, DEFAULT_CONFIGS } = require('./calculator');
const config = require('./config');

const INPUT_CHANNEL = process.env.PRICING_QUOTE_QUEUE_CHANNEL || 'pricing:quote_queue';
const RESULT_PREFIX = process.env.PRICING_RESULT_PREFIX || 'pricing:quote_result:';
const SHADOW_DIFF_CHANNEL = process.env.PRICING_SHADOW_DIFF_CHANNEL || 'pricing:shadow_diff';
const LOCK_TTL_SEC = parseInt(process.env.PRICING_PROCESSING_LOCK_TTL_SEC || '30', 10);
const RESULT_TTL_SEC = parseInt(process.env.PRICING_RESULT_TTL_SEC || '300', 10);
const METRIC_TTL_SEC = 60 * 60 * 24 * 30;

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

async function incrementMetric(metricName) {
  try {
    const key = `pricing:metrics:${metricName}:${todayKey()}`;
    await commands.incr(key);
    await commands.expire(key, METRIC_TTL_SEC);
  } catch (error) {
    console.warn('[pricing-service] Error incrementando metrica:', metricName, error.message);
  }
}

function requestIdFor(event) {
  const raw = event.request_id || event.quote_id || event.trip_id || 0;
  const parsed = Number.parseInt(String(raw), 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
}

async function tryAcquireProcessingLock(requestId) {
  const result = await commands.set(
    `pricing:lock:${requestId}`,
    `pricing-service:${process.pid}`,
    'EX',
    LOCK_TTL_SEC,
    'NX',
  );
  return result === 'OK';
}

async function readJsonKey(key) {
  const raw = await commands.get(key);
  return parseJson(raw);
}

async function loadPricingConfig(tipoVehiculo) {
  const normalized = String(tipoVehiculo || 'moto').trim().toLowerCase();
  const candidates = [
    `pricing:config:${normalized}`,
    `pricing:configuracion:${normalized}`,
    `pricing:config:${normalized}:active`,
  ];

  for (const key of candidates) {
    const cached = await readJsonKey(key);
    if (cached && typeof cached === 'object') {
      return cached;
    }
  }

  return DEFAULT_CONFIGS[normalized] || DEFAULT_CONFIGS.moto;
}

function resolvePhpPrice(event) {
  const candidates = [
    event.php_price,
    event.precio_php,
    event.precio_estimado_php,
    event.precio_estimado,
    event.precio,
  ];

  for (const value of candidates) {
    const parsed = Number(value);
    if (Number.isFinite(parsed) && parsed > 0) {
      return parsed;
    }
  }

  return null;
}

async function publishShadowAudit(event, quote, phpPrice) {
  if (phpPrice === null) {
    return;
  }

  const nodePrice = Number(quote.precio_estimado_usuario || quote.total_normalizado || quote.total || 0);
  const diffRatio = phpPrice > 0 ? Math.abs(nodePrice - phpPrice) / phpPrice : 1;
  const matches = diffRatio <= 0.05;
  const payload = {
    event: matches ? 'pricing.shadow_match' : 'pricing.shadow_diff',
    request_id: event.request_id || null,
    trip_id: event.trip_id || null,
    php_price: phpPrice,
    node_price: nodePrice,
    diff_ratio: Number(diffRatio.toFixed(6)),
    diff_percentage: Number((diffRatio * 100).toFixed(2)),
    mode: config.PRICING_SERVICE_MODE,
    source: event.source || 'unknown',
    happened_at: new Date().toISOString(),
  };

  await incrementMetric(matches ? 'shadow_match' : 'shadow_diff');
  await publish(SHADOW_DIFF_CHANNEL, payload);
  if (event.request_id) {
    await commands.set(`${SHADOW_DIFF_CHANNEL}:${event.request_id}`, JSON.stringify(payload), 'EX', RESULT_TTL_SEC);
  }
}

async function handleQuote(rawMessage) {
  const event = parseJson(rawMessage);
  if (!event || typeof event !== 'object') {
    await incrementMetric('errors');
    console.warn('[pricing-service] Mensaje invalido recibido');
    return;
  }

  const requestId = requestIdFor(event);
  if (!requestId) {
    await incrementMetric('errors');
    console.warn('[pricing-service] Solicitud sin request_id valido');
    return;
  }

  const lockAcquired = await tryAcquireProcessingLock(requestId);
  if (!lockAcquired) {
    console.log(`[pricing-service] Solicitud ${requestId} omitida por lock existente`);
    return;
  }

  await incrementMetric('total');

  try {
    const tipoVehiculo = event.tipo_vehiculo || event.vehicle_type || 'moto';
    const pricingConfig = await loadPricingConfig(tipoVehiculo);
    const quote = await calcularCotizacion(event, pricingConfig);
    const phpPrice = resolvePhpPrice(event);
    const resultPayload = {
      success: true,
      request_id: requestId,
      trip_id: event.trip_id || null,
      mode: config.PRICING_SERVICE_MODE,
      source: 'pricing_service',
      data: quote,
      mensaje: 'Cotizacion calculada exitosamente',
    };

    await commands.set(`${RESULT_PREFIX}${requestId}`, JSON.stringify(resultPayload), 'EX', RESULT_TTL_SEC);
    await publisher.publish(`${RESULT_PREFIX}${requestId}`, JSON.stringify(resultPayload));
    await incrementMetric('quotes');
    if (quote.surge_multiplier > 1.0) {
      await incrementMetric('surge_applied');
    }
    await publishShadowAudit(event, quote, phpPrice);

    console.log(`[pricing-service] request ${requestId} calculado total=${quote.precio_estimado_usuario} surge=${quote.surge_multiplier}`);
  } catch (error) {
    await incrementMetric('errors');
    const errorPayload = {
      success: false,
      request_id: requestId,
      mode: config.PRICING_SERVICE_MODE,
      error: error.message,
      source: 'pricing_service',
    };
    await commands.set(`${RESULT_PREFIX}${requestId}`, JSON.stringify(errorPayload), 'EX', RESULT_TTL_SEC);
    console.error(`[pricing-service] Error procesando request ${requestId}:`, error.message);
  }
}

async function shutdown(signal) {
  console.log(`[pricing-service] Cerrando por señal ${signal}`);
  subscriber.disconnect();
  await Promise.allSettled([publisher.quit(), commands.quit()]);
  process.exit(0);
}

async function start() {
  subscriber.on('message', async (channel, message) => {
    if (channel !== INPUT_CHANNEL) {
      return;
    }

    try {
      await handleQuote(message);
    } catch (error) {
      await incrementMetric('errors');
      console.error('[pricing-service] Error no controlado', error && error.stack ? error.stack : error.message);
    }
  });

  await commands.ping();
  await subscriber.subscribe(INPUT_CHANNEL);

  console.log(`[pricing-service] worker iniciado en modo ${config.PRICING_SERVICE_MODE}, escuchando ${INPUT_CHANNEL}`);
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

start().catch((error) => {
  console.error('[pricing-service] No se pudo iniciar', error.message);
  process.exit(1);
});
