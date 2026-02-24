'use strict';

const http     = require('http');
const es       = require('./elasticsearch');
const consumer = require('./consumer');

const PORT = 3000;

/**
 * Minimal HTTP server exposing /health for Kubernetes readiness/liveness probes.
 */
function startHealthServer() {
  const server = http.createServer(async (req, res) => {
    if (req.method !== 'GET') {
      res.writeHead(405);
      res.end();
      return;
    }

    if (req.url === '/health') {
      const esOk  = await es.ping();
      const rmqOk = consumer.getStatus();
      const ok    = esOk && rmqOk;

      const body = JSON.stringify({
        status:        ok ? 'ok' : 'degraded',
        elasticsearch: esOk  ? 'healthy' : 'error',
        rabbitmq:      rmqOk ? 'connected' : 'disconnected',
      });

      res.writeHead(ok ? 200 : 503, { 'Content-Type': 'application/json' });
      res.end(body);
      return;
    }

    res.writeHead(404);
    res.end();
  });

  server.listen(PORT, () => {
    console.log(`[Health] HTTP server listening on port ${PORT}`);
  });
}

module.exports = { startHealthServer };
