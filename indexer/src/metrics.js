'use strict';

const client = require('prom-client');

// Collect default Node.js metrics (heap, GC, event loop latency…)
client.collectDefaultMetrics({ prefix: 'indexer_' });

const messagesProcessed = new client.Counter({
  name:       'indexer_messages_processed_total',
  help:       'Total number of RabbitMQ messages successfully processed',
  labelNames: ['action'],
});

const messagesFailed = new client.Counter({
  name: 'indexer_messages_failed_total',
  help: 'Total number of RabbitMQ messages that failed processing',
});

const esUp = new client.Gauge({
  name: 'indexer_elasticsearch_up',
  help: '1 if Elasticsearch is reachable, 0 otherwise',
});

const rmqUp = new client.Gauge({
  name: 'indexer_rabbitmq_up',
  help: '1 if RabbitMQ consumer is connected, 0 otherwise',
});

module.exports = { client, messagesProcessed, messagesFailed, esUp, rmqUp };
