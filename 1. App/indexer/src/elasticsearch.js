'use strict';

const { Client } = require('@elastic/elasticsearch');

const HOST = process.env.ELASTICSEARCH_HOST || '127.0.0.1';
const PORT = process.env.ELASTICSEARCH_PORT || '9200';
const SCHEME = process.env.ELASTICSEARCH_SCHEME || 'http';
const INDEX = process.env.ELASTICSEARCH_INDEX || 'products';

const client = new Client({
  node: `${SCHEME}://${HOST}:${PORT}`,
  auth: process.env.ELASTICSEARCH_USERNAME
    ? {
        username: process.env.ELASTICSEARCH_USERNAME,
        password: process.env.ELASTICSEARCH_PASSWORD || '',
      }
    : undefined,
});

async function ping() {
  try {
    await client.ping();
    return true;
  } catch {
    return false;
  }
}

async function createIndexIfNotExists() {
  const existsResponse = await client.indices.exists({ index: INDEX });
  const exists = typeof existsResponse === 'boolean'
    ? existsResponse
    : Boolean(existsResponse?.body);

  if (exists) {
    console.log(`[ES] Index "${INDEX}" already exists.`);
    return;
  }

  await client.indices.create({
    index: INDEX,
    mappings: {
      properties: {
        id: { type: 'integer' },
        name: { type: 'text' },
        image: { type: 'keyword' },
      },
    },
  });

  console.log(`[ES] Index "${INDEX}" created.`);
}

/**
 * @param {{ id: number, name: string, image: string }} product
 */
async function indexProduct(product) {
  await client.index({
    index: INDEX,
    id: String(product.id),
    document: {
      id: product.id,
      name: product.name,
      image: product.image,
    },
  });

  console.log(`[ES] Indexed product #${product.id} ("${product.name}")`);
}

/**
 * @param {number} id
 */
async function deleteProduct(id) {
  try {
    await client.delete({ index: INDEX, id: String(id) });
    console.log(`[ES] Deleted product #${id}`);
  } catch (err) {
    if (err?.meta?.statusCode === 404) {
      console.warn(`[ES] Product #${id} not found in index (already deleted).`);
      return;
    }
    throw err;
  }
}

module.exports = { ping, createIndexIfNotExists, indexProduct, deleteProduct };
