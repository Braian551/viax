'use strict';

// Consume trip_tracking_stream y publica eventos realtime al WS gateway.
// NO persiste en BD: eso lo sigue haciendo el worker PHP.

const { streamReader, publisher, commands } = require('./redis');
const { publicarPuntoTracking } = require('./publisher');
const config = require('./config');

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

async function incrementMetric(metricName, amount = 1) {
  try {
    const key = `tracking:metrics:${metricName}:${todayKey()}`;
    await commands.incrby(key, amount);
    await commands.expire(key, config.METRIC_TTL_SEC);
  } catch (error) {
    console.warn('[tracking-service] Error incrementando metrica:', metricName, error.message);
  }
}

async function ensureConsumerGroup() {
  try {
    await commands.xgroup(
      'CREATE',
      config.TRACKING_STREAM_KEY,
      config.TRACKING_CONSUMER_GROUP,
      '$',
      'MKSTREAM',
    );
    console.log(`[tracking-service] grupo creado: ${config.TRACKING_CONSUMER_GROUP}`);
  } catch (error) {
    if (!String(error.message || '').includes('BUSYGROUP')) {
      throw error;
    }
  }
}

function fieldsArrayToObject(fieldsRaw) {
  const fields = {};

  if (!Array.isArray(fieldsRaw)) {
    return fieldsRaw && typeof fieldsRaw === 'object' ? fieldsRaw : fields;
  }

  for (let i = 0; i < fieldsRaw.length - 1; i += 2) {
    fields[String(fieldsRaw[i])] = fieldsRaw[i + 1];
  }

  return fields;
}

function parseStreamRows(rows) {
  const messages = [];
  if (!Array.isArray(rows)) {
    return messages;
  }

  for (const streamRows of rows) {
    const entries = Array.isArray(streamRows) ? streamRows[1] : [];
    if (!Array.isArray(entries)) {
      continue;
    }

    for (const entry of entries) {
      if (!Array.isArray(entry) || entry.length < 2) {
        continue;
      }

      messages.push({
        id: String(entry[0]),
        fields: fieldsArrayToObject(entry[1]),
      });
    }
  }

  return messages;
}

function parseClaimedRows(rows) {
  if (!Array.isArray(rows) || !Array.isArray(rows[1])) {
    return [];
  }

  return rows[1]
    .filter((entry) => Array.isArray(entry) && entry.length >= 2)
    .map((entry) => ({
      id: String(entry[0]),
      fields: fieldsArrayToObject(entry[1]),
    }));
}

async function ackMessage(id) {
  await commands.xack(config.TRACKING_STREAM_KEY, config.TRACKING_CONSUMER_GROUP, id);
}

async function processMessage(message) {
  await incrementMetric('total');
  const event = await publicarPuntoTracking(publisher, message.fields);

  if (!event) {
    await incrementMetric('errores');
    console.warn(`[tracking-service] mensaje ${message.id} omitido: trip_id invalido`);
    await ackMessage(message.id);
    return;
  }

  await commands.set(
    `tracking:last_event:${event.entity_id}`,
    JSON.stringify(event),
    'EX',
    config.EVENT_TTL,
  );
  await ackMessage(message.id);
  await incrementMetric('puntos_publicados');
  console.log(`[tracking-service] punto publicado trip=${event.entity_id} canales=${event.channels.join(',')}`);
}

async function processMessages(messages) {
  for (const message of messages) {
    try {
      await processMessage(message);
    } catch (error) {
      await incrementMetric('errores');
      console.error(`[tracking-service] Error procesando mensaje ${message.id}:`, error.message);
    }
  }
}

async function reclaimPending() {
  try {
    const rows = await streamReader.xautoclaim(
      config.TRACKING_STREAM_KEY,
      config.TRACKING_CONSUMER_GROUP,
      config.TRACKING_CONSUMER_NAME,
      config.PENDING_MIN_IDLE_MS,
      '0-0',
      'COUNT',
      config.BATCH_COUNT,
    );
    const messages = parseClaimedRows(rows);
    if (messages.length > 0) {
      console.log(`[tracking-service] reintentando ${messages.length} mensajes pendientes`);
      await processMessages(messages);
    }
  } catch (error) {
    await incrementMetric('errores');
    console.error('[tracking-service] Error reintentando pendientes:', error.message);
  }
}

async function readNewMessages() {
  const rows = await streamReader.xreadgroup(
    'GROUP',
    config.TRACKING_CONSUMER_GROUP,
    config.TRACKING_CONSUMER_NAME,
    'COUNT',
    config.BATCH_COUNT,
    'BLOCK',
    config.BLOCK_MS,
    'STREAMS',
    config.TRACKING_STREAM_KEY,
    '>',
  );

  return parseStreamRows(rows);
}

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function shutdown(signal) {
  console.log(`[tracking-service] Cerrando por senal ${signal}`);
  await Promise.allSettled([
    streamReader.quit(),
    publisher.quit(),
    commands.quit(),
  ]);
  process.exit(0);
}

async function start() {
  await commands.ping();
  await ensureConsumerGroup();

  console.log(
    `[tracking-service] worker iniciado, escuchando ${config.TRACKING_STREAM_KEY} (grupo: ${config.TRACKING_CONSUMER_GROUP})`,
  );

  while (true) {
    try {
      await reclaimPending();
      const messages = await readNewMessages();
      await processMessages(messages);
    } catch (error) {
      await incrementMetric('errores');
      console.error('[tracking-service] Error en loop principal:', error.message);
      await sleep(500);
    }
  }
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

start().catch((error) => {
  console.error('[tracking-service] No se pudo iniciar', error.message);
  process.exit(1);
});
