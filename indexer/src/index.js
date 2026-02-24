'use strict';

const es       = require('./elasticsearch');
const consumer = require('./consumer');
const { startHealthServer } = require('./health');

const RETRY_DELAY = 5000;

async function main() {
  console.log('[Indexer] Starting KubiQuest Indexer...');

  // 1. Start the health check HTTP server immediately
  startHealthServer();

  // 2. Wait for Elasticsearch to be reachable
  console.log('[Indexer] Waiting for Elasticsearch...');
  let esReady = false;
  while (!esReady) {
    esReady = await es.ping();
    if (!esReady) {
      console.warn(`[Indexer] Elasticsearch not reachable. Retrying in ${RETRY_DELAY / 1000}s...`);
      await sleep(RETRY_DELAY);
    }
  }
  console.log('[Indexer] Elasticsearch is reachable.');

  // 3. Ensure the products index exists
  await es.createIndexIfNotExists();

  // 4. Start consuming RabbitMQ (retries internally)
  console.log('[Indexer] Starting RabbitMQ consumer...');
  consumer.start().catch((err) => {
    console.error('[Indexer] Fatal consumer error:', err.message);
    process.exit(1);
  });

  console.log('[Indexer] Ready.');
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('[Indexer] SIGTERM received — shutting down gracefully.');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('[Indexer] SIGINT received — shutting down.');
  process.exit(0);
});

main().catch((err) => {
  console.error('[Indexer] Fatal error:', err);
  process.exit(1);
});
