'use strict';

// Tres conexiones Redis separadas: lectura del stream, publicacion de eventos y comandos.
const Redis = require('ioredis');
const config = require('./config');

function createClient(role) {
  const client = new Redis({
    host: config.REDIS_HOST,
    port: config.REDIS_PORT,
    lazyConnect: false,
    retryStrategy: (times) => Math.min(times * 100, 3000),
    maxRetriesPerRequest: null,
    enableReadyCheck: true,
  });

  client.on('connect', () => console.log(`[redis:${role}] conectado`));
  client.on('error', (error) => console.error(`[redis:${role}] error:`, error.message));
  client.on('reconnecting', () => console.warn(`[redis:${role}] reconectando...`));

  return client;
}

const streamReader = createClient('streamReader');
const publisher = createClient('publisher');
const commands = createClient('commands');

module.exports = { streamReader, publisher, commands };
