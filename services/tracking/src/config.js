'use strict';

// Configuracion del tracking-service con fallbacks seguros.
module.exports = {
  REDIS_HOST: process.env.REDIS_HOST || '127.0.0.1',
  REDIS_PORT: parseInt(process.env.REDIS_PORT || '6379', 10),
  NODE_ENV: process.env.NODE_ENV || 'production',

  // Stream de entrada: mismo stream que consume el worker PHP.
  TRACKING_STREAM_KEY: process.env.TRACKING_STREAM_KEY || 'trip_tracking_stream',

  // Grupo separado para no competir con la persistencia del worker PHP.
  TRACKING_CONSUMER_GROUP: process.env.TRACKING_CONSUMER_GROUP || 'tracking_realtime_publishers',
  TRACKING_CONSUMER_NAME: process.env.TRACKING_CONSUMER_NAME || 'tracking_publisher_01',

  // Canal formal que consume el realtime-gateway.
  EVENTS_CHANNEL: process.env.VIAX_EVENTS_CHANNEL || 'viax:events',

  // TTL de claves auxiliares publicadas en Redis, en segundos.
  EVENT_TTL: parseInt(process.env.EVENT_TTL || '30', 10),

  // Parametros de consumo del stream.
  BATCH_COUNT: parseInt(process.env.TRACKING_BATCH_COUNT || '50', 10),
  BLOCK_MS: parseInt(process.env.TRACKING_BLOCK_MS || '3000', 10),
  PENDING_MIN_IDLE_MS: parseInt(process.env.TRACKING_PENDING_MIN_IDLE_MS || '30000', 10),
  METRIC_TTL_SEC: parseInt(process.env.TRACKING_METRIC_TTL_SEC || String(60 * 60 * 24 * 30), 10),
};
