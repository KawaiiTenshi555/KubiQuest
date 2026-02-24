'use strict';

const { Client } = require('@elastic/elasticsearch');

const INDEX = process.env.ELASTICSEARCH_INDEX || 'products';

const client = new Client({
  node: `${process.env.ELASTICSEARCH_HOST || '127.0.0.1'}:${process.env.ELASTICSEARCH_PORT || 9200}`,
  auth: process.env.ELASTICSEARCH_USERNAME
    ? {
        username: process.env.ELASTICSEARCH_USERNAME,
        password: process.env.ELASTICSEARCH_PASSWORD || '',
      }
    : undefined,
});

/**
 * Ping Elasticsearch. Returns true if reachable.
 */
async function ping() {
  try {
    await client.ping();
    return true;
  } catch {
    return false;
  }
}

/**
 * Create the products index with proper mappings if it doesn't exist yet.
 */
async function createIndexIfNotExists() {
  const exists = await client.indices.exists({ index: INDEX });
  if (exists) {
    console.log(`[ES] Index "${INDEX}" already exists.`);
    return;
  }

  await client.indices.create({
    index: INDEX,
    mappings: {
      properties: {
        id:    { type: 'integer' },
        name:  { type: 'text' },
        image: { type: 'keyword' },
      },
    },
  });

  console.log(`[ES] Index "${INDEX}" created.`);
}

/**
 * Index (upsert) a product document.
 * @param {{ id: number, name: string, image: string }} product
 */
async function indexProduct(product) {
  await client.index({
    index: INDEX,
    id:    String(product.id),
    document: {
      id:    product.id,
      name:  product.name,
      image: product.image,
    },
  });

  console.log(`[ES] Indexed product #${product.id} ("${product.name}")`);
}

/**
 * Delete a product document by id.
 * @param {number} id
 */
async function deleteProduct(id) {
  try {
    await client.delete({ index: INDEX, id: String(id) });
    console.log(`[ES] Deleted product #${id}`);
  } catch (err) {
    // 404 means it was already absent — not an error
    if (err.meta?.statusCode === 404) {
      console.warn(`[ES] Product #${id} not found in index (already deleted?)`);
    } else {
      throw err;
    }
  }
}

module.exports = { ping, createIndexIfNotExists, indexProduct, deleteProduct };
