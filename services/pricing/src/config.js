'use strict';

// Configuracion del pricing-service con fallbacks seguros.
module.exports = {
  REDIS_HOST: process.env.REDIS_HOST || '127.0.0.1',
  REDIS_PORT: parseInt(process.env.REDIS_PORT || '6379', 10),
  NODE_ENV: process.env.NODE_ENV || 'production',
  PRICING_SERVICE_MODE: (process.env.PRICING_SERVICE_MODE || 'shadow').trim().toLowerCase(),
  CONFIG_CACHE_TTL: parseInt(process.env.CONFIG_CACHE_TTL || '300', 10),
};
