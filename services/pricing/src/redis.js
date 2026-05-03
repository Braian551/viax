'use strict';

// Tres conexiones Redis separadas para evitar conflicto subscriber/publisher.
const Redis = require('ioredis');
const config = require('./config');

const opts = {
  host: config.REDIS_HOST,
  port: config.REDIS_PORT,
  lazyConnect: false,
  retryStrategy: (times) => Math.min(times * 100, 3000),
  maxRetriesPerRequest: null,
  enableReadyCheck: true,
};

const subscriber = new Redis(opts);
const publisher = new Redis(opts);
const commands = new Redis(opts);

subscriber.on('error', err => console.error('[redis:subscriber]', err.message));
publisher.on('error', err => console.error('[redis:publisher]', err.message));
commands.on('error', err => console.error('[redis:commands]', err.message));

subscriber.on('connect', () => console.log('[redis:subscriber] conectado'));
publisher.on('connect', () => console.log('[redis:publisher] conectado'));
commands.on('connect', () => console.log('[redis:commands] conectado'));

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

async function publish(channel, payload) {
  const serialized = typeof payload === 'string' ? payload : JSON.stringify(payload);
  await publisher.publish(channel, serialized);
  return serialized;
}

module.exports = { subscriber, publisher, commands, parseJson, publish };
