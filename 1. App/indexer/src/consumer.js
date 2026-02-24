'use strict';

const amqp = require('amqplib');
const es = require('./elasticsearch');
const { messagesProcessed, messagesFailed } = require('./metrics');

const RABBITMQ_HOST = process.env.RABBITMQ_HOST || '127.0.0.1';
const RABBITMQ_PORT = process.env.RABBITMQ_PORT || '5672';
const RABBITMQ_USER = process.env.RABBITMQ_USER || 'guest';
const RABBITMQ_PASSWORD = process.env.RABBITMQ_PASSWORD || 'guest';
const RABBITMQ_VHOST = process.env.RABBITMQ_VHOST || '/';

const EXCHANGE = process.env.RABBITMQ_EXCHANGE || 'products';
const QUEUE = process.env.RABBITMQ_QUEUE || 'products-indexer';
const RETRY_DELAY_MS = 5000;

const VHOST_PATH = RABBITMQ_VHOST === '/'
  ? '%2F'
  : encodeURIComponent(RABBITMQ_VHOST.replace(/^\//, ''));
const RABBITMQ_URL = `amqp://${RABBITMQ_USER}:${RABBITMQ_PASSWORD}@${RABBITMQ_HOST}:${RABBITMQ_PORT}/${VHOST_PATH}`;

let isConnected = false;

async function start() {
  while (true) {
    try {
      await connect();
    } catch (err) {
      isConnected = false;
      console.error(`[RMQ] Connection failed: ${err.message}. Retrying in ${RETRY_DELAY_MS / 1000}s...`);
      await sleep(RETRY_DELAY_MS);
    }
  }
}

async function connect() {
  console.log(`[RMQ] Connecting to ${RABBITMQ_HOST}:${RABBITMQ_PORT}...`);

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

  await channel.assertExchange(EXCHANGE, 'fanout', { durable: true });
  await channel.assertQueue(QUEUE, { durable: true });
  await channel.bindQueue(QUEUE, EXCHANGE, '');
  channel.prefetch(1);

  isConnected = true;
  console.log(`[RMQ] Ready. Consuming queue "${QUEUE}"...`);

  channel.consume(QUEUE, async (msg) => {
    if (!msg) {
      return;
    }

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
        console.warn(`[RMQ] Unknown action "${action}", discarding message.`);
      }

      messagesProcessed.inc({ action: action || 'unknown' });
      channel.ack(msg);
    } catch (err) {
      console.error(`[RMQ] Failed to process message: ${err.message}`);
      messagesFailed.inc();
      channel.nack(msg, false, false);
    }
  });

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
