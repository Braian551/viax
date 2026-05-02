'use strict';

const Redis = require('ioredis');
const config = require('./config');

function createClient(role) {
  const client = new Redis({
    host: config.redis.host,
    port: config.redis.port,
    password: config.redis.password,
    retryStrategy: (times) => Math.min(times * 100, 3000),
    lazyConnect: false,
    maxRetriesPerRequest: null,
    enableReadyCheck: true,
  });

  client.on('connect', () => {
    console.log(`[redis:${role}] conectado`);
  });

  client.on('error', (error) => {
    console.error(`[redis:${role}] error:`, error.message);
  });

  client.on('reconnecting', () => {
    console.warn(`[redis:${role}] reconectando...`);
  });

  return client;
}

const commands = createClient('commands');
const publisher = createClient('publisher');
const subscriber = createClient('subscriber');

function parseJson(rawValue) {
  if (typeof rawValue !== 'string' || rawValue.trim() === '') {
    return null;
  }

  try {
    return JSON.parse(rawValue);
  } catch (_error) {
    return null;
  }
}

function normalizeDriverIds(values) {
  if (!Array.isArray(values)) {
    return [];
  }

  const unique = new Set();
  for (const value of values) {
    const driverId = Number.parseInt(String(value), 10);
    if (Number.isInteger(driverId) && driverId > 0) {
      unique.add(driverId);
    }
  }

  return Array.from(unique);
}

async function getCandidateDriverIds(tripId, eventCandidateIds = []) {
  const fromEvent = normalizeDriverIds(eventCandidateIds);
  if (fromEvent.length > 0) {
    return fromEvent;
  }

  const keyNames = [
    `ride:${tripId}:drivers`,
    `ride:${tripId}:drivers_queue`,
  ];

  for (const keyName of keyNames) {
    const rawValue = await commands.get(keyName);
    const parsed = parseJson(rawValue);
    if (Array.isArray(parsed)) {
      const normalized = normalizeDriverIds(parsed);
      if (normalized.length > 0) {
        return normalized;
      }
    }
  }

  return [];
}

async function tryAcquireProcessingLock(tripId, ttlSec) {
  const lockKey = `trip:${tripId}:processing`;
  const lockValue = `dispatch-service:${process.pid}`;
  const result = await commands.set(lockKey, lockValue, 'EX', ttlSec, 'NX');
  return result === 'OK';
}

async function tryAcquireOfferSentLock(tripId, ttlSec) {
  const lockKey = `trip:${tripId}:offer_sent`;
  const lockValue = `dispatch-service-offer:${process.pid}`;
  const result = await commands.set(lockKey, lockValue, 'EX', ttlSec, 'NX');
  return result === 'OK';
}

async function rememberDecision(tripId, payload, ttlSec = 600) {
  await commands.set(
    `dispatch_service:last_offer:${tripId}`,
    JSON.stringify(payload),
    'EX',
    ttlSec,
  );
}

async function publish(channel, payload) {
  const serialized = typeof payload === 'string' ? payload : JSON.stringify(payload);
  await publisher.publish(channel, serialized);
  return serialized;
}

module.exports = {
  command: commands,
  commands,
  publisher,
  subscriber,
  parseJson,
  normalizeDriverIds,
  getCandidateDriverIds,
  tryAcquireProcessingLock,
  tryAcquireOfferSentLock,
  rememberDecision,
  publish,
};
