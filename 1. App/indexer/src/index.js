'use strict';

const es = require('./elasticsearch');
const consumer = require('./consumer');
const { startHealthServer } = require('./health');

const RETRY_DELAY_MS = 5000;

async function main() {
  console.log('[Indexer] Starting KubiQuest Indexer...');

  // Start the health server immediately for probes.
  startHealthServer();

  // Wait until Elasticsearch is reachable.
  console.log('[Indexer] Waiting for Elasticsearch...');
  let esReady = false;
  while (!esReady) {
    esReady = await es.ping();
    if (!esReady) {
      console.warn(`[Indexer] Elasticsearch not reachable. Retrying in ${RETRY_DELAY_MS / 1000}s...`);
      await sleep(RETRY_DELAY_MS);
    }
  }
  console.log('[Indexer] Elasticsearch is reachable.');

  // Ensure the products index exists.
  await es.createIndexIfNotExists();

  // Start RabbitMQ consumer (retries internally).
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

function handleSignal(signal) {
  console.log(`[Indexer] ${signal} received, shutting down.`);
  process.exit(0);
}

process.on('SIGTERM', () => handleSignal('SIGTERM'));
process.on('SIGINT', () => handleSignal('SIGINT'));

main().catch((err) => {
  console.error('[Indexer] Fatal error:', err);
  process.exit(1);
});
