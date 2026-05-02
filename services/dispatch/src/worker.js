'use strict';

const config = require('./config');
const {
  subscriber,
  publisher,
  commands,
  parseJson,
  tryAcquireProcessingLock,
  tryAcquireOfferSentLock,
  rememberDecision,
  publish,
} = require('./redis');
const { chooseDriver } = require('./matching');

function nowIso() {
  return new Date().toISOString();
}

function driverOfferChannel(driverId) {
  return `${config.redis.driverOfferPrefix}${driverId}:trip_offer`;
}

function readNumber(value, fallback = null) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function readLegacyTripId(rawMessage, parsedMessage) {
  const rawTrimmed = typeof rawMessage === 'string' ? rawMessage.trim() : '';
  if (/^\d+$/.test(rawTrimmed)) {
    return rawTrimmed;
  }

  if (typeof parsedMessage === 'number' && Number.isInteger(parsedMessage) && parsedMessage > 0) {
    return String(parsedMessage);
  }

  if (typeof parsedMessage === 'string') {
    const parsedTrimmed = parsedMessage.trim();
    if (/^\d+$/.test(parsedTrimmed)) {
      return parsedTrimmed;
    }
  }

  return null;
}

function shouldPublishDriverOffer() {
  return config.mode === 'hybrid' || config.behavior.enableDriverOfferPublish;
}

function buildOfferPayload(event, selection) {
  const happenedAt = nowIso();
  const estimatedPrice = readNumber(event.estimated_price, 0);

  return {
    trip_id: Number.parseInt(String(event.trip_id || 0), 10),
    user_id: Number.parseInt(String(event.user_id || 0), 10),
    driver_id: selection.driverId,
    price: estimatedPrice,
    estimated_price: estimatedPrice,
    lat: readNumber(event.lat),
    lng: readNumber(event.lng),
    timestamp: happenedAt,
    source: 'dispatch_service',
    selection_source: selection.source,
    mode: config.mode,
    metadata: {
      driver_id: selection.driverId,
      vehicle_type: String(event.vehicle_type || 'moto'),
      offered_at: happenedAt,
      offer_ttl_sec: config.matching.offerTtlSec,
      source: selection.source,
      rank: selection.rank,
      eta_minutes: selection.etaMinutes,
      distance_km: selection.distanceKm,
      mode: config.mode,
      location: selection.location,
    },
  };
}

async function publishAudit(payload) {
  if (config.behavior.emitShadowOffers) {
    await publish(config.redis.shadowOfferChannel, payload);
  }

  await publish(config.redis.auditChannel, payload);
}

async function handleTripRequested(rawMessage) {
  const parsed = parseJson(rawMessage);
  const preview = typeof rawMessage === 'string'
    ? rawMessage.substring(0, 120)
    : String(rawMessage).substring(0, 120);
  const legacyTripId = readLegacyTripId(rawMessage, parsed);

  // Compatibilidad con LPUSH legacy: el worker PHP deja el trip_id crudo en la cola.
  if (parsed === null) {
    if (legacyTripId !== null) {
      console.log('[DISPATCH_LEGACY] trip_id crudo recibido del worker PHP:', legacyTripId, '- ignorado por dispatch-service (procesado por flujo legacy)');
      return;
    }

    console.warn('[DISPATCH_WARN] Mensaje no parseable como JSON:', preview);
    return;
  }

  if (legacyTripId !== null && typeof parsed !== 'object') {
    console.log('[DISPATCH_LEGACY] trip_id crudo recibido del worker PHP:', legacyTripId, '- ignorado por dispatch-service (procesado por flujo legacy)');
    return;
  }

  const event = parsed;
  if (typeof event !== 'object') {
    console.warn('[DISPATCH_WARN] Mensaje parseado sin objeto valido:', preview);
    return;
  }

  const tripId = Number.parseInt(String(event.trip_id || 0), 10);
  if (!Number.isInteger(tripId) || tripId <= 0) {
    console.log('[dispatch-service] Evento ignorado: trip_id invalido');
    return;
  }

  console.log(`[dispatch-service] Evento recibido para trip ${tripId}`);

  const lockAcquired = await tryAcquireProcessingLock(tripId, config.matching.processingLockTtlSec);
  if (!lockAcquired) {
    console.log(`[dispatch-service] Trip ${tripId} omitido por lock existente`);
    return;
  }

  const selection = await chooseDriver(event);
  if (!selection) {
    const noDriverPayload = {
      event: 'dispatch.no_driver_candidate',
      trip_id: tripId,
      mode: config.mode,
      happened_at: nowIso(),
    };
    await publishAudit(noDriverPayload);
    await rememberDecision(tripId, noDriverPayload);
    console.log(`[dispatch-service] Trip ${tripId} sin conductor elegible`);
    return;
  }

  const offerChannel = driverOfferChannel(selection.driverId);
  const offerPayload = buildOfferPayload(event, selection);
  const publishDriverOffer = shouldPublishDriverOffer();
  const auditPayload = {
    event: 'dispatch.trip_offer_selected',
    trip_id: tripId,
    driver_id: selection.driverId,
    channel: offerChannel,
    mode: config.mode,
    happened_at: nowIso(),
    payload: offerPayload,
  };

  if (publishDriverOffer) {
    const offerLockAcquired = await tryAcquireOfferSentLock(tripId, config.matching.offerSentLockTtlSec);
    if (!offerLockAcquired) {
      const duplicatePayload = {
        event: 'dispatch.trip_offer_skipped_duplicate',
        trip_id: tripId,
        driver_id: selection.driverId,
        mode: config.mode,
        happened_at: nowIso(),
      };
      await publishAudit(duplicatePayload);
      await rememberDecision(tripId, duplicatePayload);
      console.log(`[dispatch-service] Trip ${tripId} omitido: oferta ya emitida recientemente`);
      return;
    }
  }

  await publishAudit(auditPayload);

  if (publishDriverOffer) {
    console.log('[DISPATCH_OFFER]', {
      tripId,
      driverId: selection.driverId,
      mode: config.mode,
    });
    await publish(offerChannel, offerPayload);
  }

  await rememberDecision(tripId, auditPayload);
  console.log(`[dispatch-service] Trip ${tripId} seleccionado para conductor ${selection.driverId} en modo ${config.mode}`);
}

async function shutdown(signal) {
  console.log(`[dispatch-service] Cerrando por señal ${signal}`);
  subscriber.disconnect();
  await Promise.allSettled([
    publisher.quit(),
    commands.quit(),
  ]);
  process.exit(0);
}

async function start() {
  subscriber.on('message', async (channel, message) => {
    if (channel !== config.redis.tripQueueChannel) {
      return;
    }

    try {
      await handleTripRequested(message);
    } catch (error) {
      console.error('[dispatch-service] Error procesando evento', error && error.stack ? error.stack : error.message);
    }
  });

  await commands.ping();
  await subscriber.subscribe(config.redis.tripQueueChannel);

  console.log(
    `[dispatch-service] worker iniciado, escuchando ${config.redis.tripQueueChannel} en modo ${config.mode}`,
  );
}

process.on('SIGINT', () => {
  shutdown('SIGINT');
});

process.on('SIGTERM', () => {
  shutdown('SIGTERM');
});

start().catch((error) => {
  console.error('[dispatch-service] No se pudo iniciar', error.message);
  process.exit(1);
});
