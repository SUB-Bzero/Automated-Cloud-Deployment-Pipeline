'use strict';

const { Pool } = require('pg');
const { createApp } = require('../src/app');

/**
 * Creates an application wired to a dedicated TEST database and returns
 * everything the tests need. The items table is (re)created and truncated so
 * every test starts from a clean slate.
 */
async function setupTestApp() {
  const databaseUrl =
    process.env.TEST_DATABASE_URL || 'postgres://app:app@localhost:5432/appdb';
  const pool = new Pool({ connectionString: databaseUrl, max: 5 });

  const db = {
    checkDatabase: async () => {
      try {
        await pool.query('SELECT 1');
        return 'up';
      } catch {
        return 'down';
      }
    },
    countItems: async () =>
      (await pool.query('SELECT count(*)::int AS count FROM items')).rows[0]
        .count,
    listItems: async () =>
      (
        await pool.query(
          'SELECT id, title, created_at FROM items ORDER BY id DESC LIMIT 50',
        )
      ).rows,
    createItem: async (title) =>
      (
        await pool.query(
          'INSERT INTO items (title) VALUES ($1) RETURNING id, title, created_at',
          [title],
        )
      ).rows[0],
    deleteItem: async (id) =>
      (await pool.query('DELETE FROM items WHERE id = $1 RETURNING id', [id]))
        .rows[0],
  };

  await pool.query(`CREATE TABLE IF NOT EXISTS items (
    id         SERIAL PRIMARY KEY,
    title      TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`);
  await pool.query('TRUNCATE items RESTART IDENTITY');

  const app = createApp(db);
  return { app, db, pool };
}

module.exports = { setupTestApp };
