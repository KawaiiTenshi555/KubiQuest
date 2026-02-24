'use strict';

const amqp                                 = require('amqplib');
const es                                   = require('./elasticsearch');
const { messagesProcessed, messagesFailed } = require('./metrics');

const RABBITMQ_URL = `amqp://${process.env.RABBITMQ_USER || 'guest'}:${process.env.RABBITMQ_PASSWORD || 'guest'}@${process.env.RABBITMQ_HOST || '127.0.0.1'}:${process.env.RABBITMQ_PORT || 5672}${process.env.RABBITMQ_VHOST || '/'}`;
const EXCHANGE     = process.env.RABBITMQ_EXCHANGE || 'products';
const QUEUE        = process.env.RABBITMQ_QUEUE    || 'products-indexer';
const RETRY_DELAY  = 5000; // ms

let isConnected = false;

/**
 * Start consuming messages from RabbitMQ.
 * Retries the connection indefinitely on failure.
 */
async function start() {
  while (true) {
    try {
      await connect();
    } catch (err) {
      isConnected = false;
      console.error(`[RMQ] Connection failed: ${err.message}. Retrying in ${RETRY_DELAY / 1000}s...`);
      await sleep(RETRY_DELAY);
    }
  }
}

async function connect() {
  console.log(`[RMQ] Connecting to ${process.env.RABBITMQ_HOST}:${process.env.RABBITMQ_PORT}...`);

  const connection = await amqp.connect(RABBITMQ_URL);

  connection.on('error', (err) => {
    console.error('[RMQ] Connection error:', err.message);
    isConnected = false;
  });

  connection.on('close', () => {
    console.warn('[RMQ] Connection closed.');
    isConnected = false;
  });

  const channel = await connection.createChannel();

  // Declare fanout exchange (idempotent)
  await channel.assertExchange(EXCHANGE, 'fanout', { durable: true });

  // Declare durable queue
  await channel.assertQueue(QUEUE, { durable: true });

  // Bind queue to exchange
  await channel.bindQueue(QUEUE, EXCHANGE, '');

  // Process one message at a time
  channel.prefetch(1);

  isConnected = true;
  console.log(`[RMQ] Ready. Consuming queue "${QUEUE}"...`);

  channel.consume(QUEUE, async (msg) => {
    if (!msg) return;

    try {
      const payload = JSON.parse(msg.content.toString());
      const { action, product } = payload;

      if (!action || !product) {
        throw new Error('Invalid message format: missing action or product');
      }

      if (action === 'created') {
        await es.indexProduct(product);
      } else if (action === 'deleted') {
        await es.deleteProduct(product.id);
      } else {
        console.warn(`[RMQ] Unknown action: "${action}" — discarding message`);
      }

      messagesProcessed.inc({ action: action || 'unknown' });
      channel.ack(msg);
    } catch (err) {
      console.error(`[RMQ] Failed to process message: ${err.message}`);
      messagesFailed.inc();
      // Discard malformed/unprocessable messages (no requeue)
      channel.nack(msg, false, false);
    }
  });

  // Keep the promise alive until connection drops
  await new Promise((_, reject) => {
    connection.on('close', () => reject(new Error('Connection closed')));
    connection.on('error', reject);
  });
}

function getStatus() {
  return isConnected;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

module.exports = { start, getStatus };
