'use strict';

const config = require('./config');
const { command, getCandidateDriverIds, parseJson } = require('./redis');

function estimateEtaMinutes(distanceKm) {
  const safeDistance = Math.max(0.1, Number(distanceKm) || 0.1);
  const etaMinutes = (safeDistance / Math.max(5, config.matching.averageSpeedKmh)) * 60;
  return Math.max(1, Math.ceil(etaMinutes));
}

async function loadDriverLocation(driverId) {
  const rawValue = await command.get(`drivers:location:${driverId}`);
  const parsed = parseJson(rawValue);
  return parsed && typeof parsed === 'object' ? parsed : null;
}

async function isDriverEligible(driverId, tripId) {
  const [stateRaw, activeRideRaw, lockExists, available] = await Promise.all([
    command.get(`driver:${driverId}:state`),
    command.get(`driver:${driverId}:active_ride`),
    command.exists(`driver_offer_lock:${driverId}`),
    command.sismember(config.redis.availableKey, String(driverId)),
  ]);

  if (Number(lockExists) > 0) {
    return { eligible: false, reason: 'offer_locked' };
  }

  const activeRideId = Number.parseInt(String(activeRideRaw || '0'), 10);
  if (activeRideId > 0 && activeRideId !== tripId) {
    return { eligible: false, reason: 'active_ride' };
  }

  const state = String(stateRaw || '').trim().toLowerCase();
  if (state !== '' && state !== 'available') {
    return { eligible: false, reason: `state_${state}` };
  }

  if (Number(available) === 0 && state !== 'available') {
    return { eligible: false, reason: 'not_available' };
  }

  const location = await loadDriverLocation(driverId);
  return {
    eligible: true,
    reason: 'ok',
    location,
  };
}

async function chooseFromCandidates(event) {
  const tripId = Number.parseInt(String(event.trip_id || 0), 10);
  const candidateIds = await getCandidateDriverIds(tripId, event.candidate_driver_ids);

  for (let index = 0; index < candidateIds.length; index += 1) {
    const driverId = candidateIds[index];
    const eligibility = await isDriverEligible(driverId, tripId);
    if (!eligibility.eligible) {
      continue;
    }

    return {
      driverId,
      source: 'candidate_cache',
      rank: index + 1,
      distanceKm: eligibility.location && Number.isFinite(Number(eligibility.location.distance_km))
        ? Number(eligibility.location.distance_km)
        : null,
      etaMinutes: eligibility.location && Number.isFinite(Number(eligibility.location.distance_km))
        ? estimateEtaMinutes(Number(eligibility.location.distance_km))
        : null,
      location: eligibility.location,
    };
  }

  return null;
}

async function chooseFromGeo(event) {
  const lat = Number(event.lat);
  const lng = Number(event.lng);
  const tripId = Number.parseInt(String(event.trip_id || 0), 10);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return null;
  }

  const rows = await command.call(
    'GEOSEARCH',
    config.redis.geoKey,
    'FROMLONLAT',
    String(lng),
    String(lat),
    'BYRADIUS',
    String(config.matching.fallbackRadiusKm),
    'km',
    'WITHDIST',
    'ASC',
    'COUNT',
    String(config.matching.searchLimit),
  );

  if (!Array.isArray(rows)) {
    return null;
  }

  for (const row of rows) {
    if (!Array.isArray(row) || row.length === 0) {
      continue;
    }

    const driverId = Number.parseInt(String(row[0]), 10);
    if (!Number.isInteger(driverId) || driverId <= 0) {
      continue;
    }

    const eligibility = await isDriverEligible(driverId, tripId);
    if (!eligibility.eligible) {
      continue;
    }

    const distanceKm = row.length > 1 ? Number(row[1]) : null;
    return {
      driverId,
      source: 'redis_geo',
      rank: null,
      distanceKm: Number.isFinite(distanceKm) ? distanceKm : null,
      etaMinutes: Number.isFinite(distanceKm) ? estimateEtaMinutes(distanceKm) : null,
      location: eligibility.location,
    };
  }

  return null;
}

async function chooseDriver(event) {
  const fromCandidates = await chooseFromCandidates(event);
  if (fromCandidates) {
    return fromCandidates;
  }

  return chooseFromGeo(event);
}

module.exports = {
  chooseDriver,
};