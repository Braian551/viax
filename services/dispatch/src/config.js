'use strict';

const env = process.env.NODE_ENV || 'development';

function readBool(value, defaultValue) {
  if (value === undefined || value === null || String(value).trim() === '') {
    return defaultValue;
  }

  return !['0', 'false', 'off', 'no'].includes(String(value).trim().toLowerCase());
}

module.exports = {
  env,
  serviceName: 'viax-dispatch-service',
  mode: (process.env.DISPATCH_SERVICE_MODE || 'hybrid').trim().toLowerCase(),

  redis: {
    host: process.env.REDIS_HOST || '127.0.0.1',
    port: parseInt(process.env.REDIS_PORT || '6379', 10),
    password: process.env.REDIS_PASSWORD || undefined,
    tripQueueChannel: process.env.DISPATCH_TRIP_QUEUE_CHANNEL || 'dispatch:trip_queue',
    shadowOfferChannel: process.env.DISPATCH_SHADOW_OFFER_CHANNEL || 'dispatch:shadow_offers',
    auditChannel: process.env.DISPATCH_AUDIT_CHANNEL || 'dispatch:trip_offer_audit',
    driverOfferPrefix: process.env.DISPATCH_DRIVER_OFFER_PREFIX || 'driver:',
    geoKey: process.env.DISPATCH_GEO_KEY || 'drivers:geo',
    availableKey: process.env.DISPATCH_AVAILABLE_KEY || 'drivers:available',
  },

  matching: {
    processingLockTtlSec: parseInt(process.env.DISPATCH_PROCESSING_LOCK_TTL_SEC || '30', 10),
    offerSentLockTtlSec: parseInt(process.env.DISPATCH_OFFER_SENT_LOCK_TTL_SEC || '15', 10),
    offerTtlSec: parseInt(process.env.DISPATCH_OFFER_TTL_SEC || '25', 10),
    candidateCacheTtlSec: parseInt(process.env.DISPATCH_CANDIDATE_CACHE_TTL_SEC || '180', 10),
    searchRadiusKm: parseFloat(process.env.DISPATCH_SEARCH_RADIUS_KM || '8'),
    fallbackRadiusKm: parseFloat(process.env.DISPATCH_FALLBACK_RADIUS_KM || '10'),
    searchLimit: parseInt(process.env.DISPATCH_SEARCH_LIMIT || '12', 10),
    averageSpeedKmh: parseFloat(process.env.DISPATCH_AVG_SPEED_KMH || '24'),
  },

  behavior: {
    emitShadowOffers: readBool(process.env.DISPATCH_EMIT_SHADOW_OFFERS, true),
    enableDriverOfferPublish: readBool(process.env.DISPATCH_ENABLE_DRIVER_OFFER_PUBLISH, false),
  },
};