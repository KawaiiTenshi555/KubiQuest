'use strict';

const http = require('http');
const { client, esUp, rmqUp } = require('./metrics');
const es = require('./elasticsearch');
const consumer = require('./consumer');

const PORT = 3000;

function startHealthServer() {
  const server = http.createServer(async (req, res) => {
    if (req.method !== 'GET') {
      res.writeHead(405);
      res.end();
      return;
    }

    if (req.url === '/health') {
      const esOk = await es.ping();
      const rmqOk = consumer.getStatus();
      const ok = esOk && rmqOk;

      esUp.set(esOk ? 1 : 0);
      rmqUp.set(rmqOk ? 1 : 0);

      const body = JSON.stringify({
        status: ok ? 'ok' : 'degraded',
        elasticsearch: esOk ? 'healthy' : 'error',
        rabbitmq: rmqOk ? 'connected' : 'disconnected',
      });

      res.writeHead(ok ? 200 : 503, { 'Content-Type': 'application/json' });
      res.end(body);
      return;
    }

    if (req.url === '/metrics') {
      try {
        const metrics = await client.register.metrics();
        res.writeHead(200, { 'Content-Type': client.register.contentType });
        res.end(metrics);
      } catch (err) {
        res.writeHead(500);
        res.end(err.message);
      }
      return;
    }

    res.writeHead(404);
    res.end();
  });

  server.listen(PORT, () => {
    console.log(`[Health] HTTP server listening on port ${PORT} (/health, /metrics)`);
  });
}

module.exports = { startHealthServer };
