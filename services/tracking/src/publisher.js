'use strict';

const config = require('./config');

function readInt(value, fallback = null) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isInteger(parsed) ? parsed : fallback;
}

function readFloat(value, fallback = null) {
  const parsed = Number.parseFloat(String(value ?? ''));
  return Number.isFinite(parsed) ? parsed : fallback;
}

function eventIdFor(tripId, timestamp) {
  return `trip.location_updated:trip:${tripId}:${timestamp}`;
}

function buildTrackingEvent(punto) {
  const tripId = readInt(punto.trip_id);
  const driverId = readInt(punto.conductor_id ?? punto.driver_id);

  if (!tripId || tripId <= 0) {
    return null;
  }

  const timestamp = readInt(punto.timestamp, Math.floor(Date.now() / 1000));
  const payload = {
    trip_id: tripId,
    driver_id: driverId,
    conductor_id: driverId,
    lat: readFloat(punto.lat, 0),
    lng: readFloat(punto.lng, 0),
    speed: readFloat(punto.speed, 0),
    heading: readFloat(punto.heading, 0),
    timestamp,
    precision_gps: readFloat(punto.precision_gps),
    distance_km: readFloat(punto.distance_km),
    elapsed_time_sec: readInt(punto.elapsed_time_sec),
    snap_source: punto.snap_source || null,
    source: 'tracking_service',
  };

  const channels = [`trip:${tripId}`];
  if (driverId && driverId > 0) {
    channels.push(`driver:${driverId}`);
  }

  return {
    type: 'trip.location_updated',
    version: 1,
    entity: 'trip',
    entity_id: String(tripId),
    timestamp,
    payload,
    event_id: eventIdFor(tripId, timestamp),
    channels,
  };
}

/**
 * Publica un punto de tracking al gateway WS.
 * El gateway escucha viax:events y usa event.channels para fan-out a topics WS.
 * @param {Object} redis - conexion publisher
 * @param {Object} punto - datos del punto de tracking del stream
 */
async function publicarPuntoTracking(redis, punto) {
  const event = buildTrackingEvent(punto);
  if (!event) {
    return null;
  }

  await redis.publish(config.EVENTS_CHANNEL, JSON.stringify(event));
  return event;
}

module.exports = { publicarPuntoTracking, buildTrackingEvent };
