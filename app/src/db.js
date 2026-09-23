'use strict';

const { Pool } = require('pg');
const config = require('./config');

const pool = new Pool({
  connectionString: config.databaseUrl,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

/** Run a parameterised query on the pool. */
async function query(text, params) {
  return pool.query(text, params);
}

/** Lightweight connectivity probe used by the /health endpoint. */
async function checkDatabase() {
  try {
    await pool.query('SELECT 1');
    return 'up';
  } catch {
    return 'down';
  }
}

/**
 * Wait for the database to accept connections. The app container often starts
 * before RDS/Postgres is reachable, so we retry instead of crashing.
 */
async function waitForDatabase(maxAttempts = 30, delayMs = 2000) {
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      await pool.query('SELECT 1');
      console.log(`[db] connected (attempt ${attempt})`);
      return;
    } catch (err) {
      console.warn(
        `[db] not ready yet (attempt ${attempt}/${maxAttempts}): ${err.message}`,
      );
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
  throw new Error('database never became ready');
}

/** Idempotent schema migration (single table keeps the demo simple). */
async function migrate() {
  await pool.query(`CREATE TABLE IF NOT EXISTS items (
    id         SERIAL PRIMARY KEY,
    title      TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`);
  console.log('[db] schema ready');
}

async function listItems(limit = 50) {
  const { rows } = await pool.query(
    'SELECT id, title, created_at FROM items ORDER BY id DESC LIMIT $1',
    [limit],
  );
  return rows;
}

async function createItem(title) {
  const { rows } = await pool.query(
    'INSERT INTO items (title) VALUES ($1) RETURNING id, title, created_at',
    [title],
  );
  return rows[0];
}

async function deleteItem(id) {
  const { rows } = await pool.query(
    'DELETE FROM items WHERE id = $1 RETURNING id',
    [id],
  );
  return rows[0];
}

async function countItems() {
  const { rows } = await pool.query('SELECT count(*)::int AS count FROM items');
  return rows[0].count;
}

async function close() {
  await pool.end();
}

module.exports = {
  pool,
  query,
  checkDatabase,
  waitForDatabase,
  migrate,
  listItems,
  createItem,
  deleteItem,
  countItems,
  close,
};
