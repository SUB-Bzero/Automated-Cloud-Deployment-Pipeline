'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const { Pool } = require('pg');

const { createApp } = require('../src/app');
const { setupTestApp } = require('./helpers');

test('GET /health returns 200 with status "ok" when the database is up', async () => {
  const { app, pool } = await setupTestApp();
  const res = await request(app).get('/health');

  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'ok');
  assert.equal(res.body.checks.database, 'up');
  assert.ok(res.body.version, 'version should be reported');
  assert.ok(res.body.timestamp, 'timestamp should be reported');

  await pool.end();
});

test('GET /health returns 503 with status "unhealthy" when the database is down', async () => {
  // Point the pool at a closed local port -> connection refused -> "down".
  const pool = new Pool({
    connectionString: 'postgres://app:app@127.0.0.1:1/unreachable',
    connectionTimeoutMillis: 500,
  });
  const db = {
    checkDatabase: async () => {
      try {
        await pool.query('SELECT 1');
        return 'up';
      } catch {
        return 'down';
      }
    },
  };
  const app = createApp(db);
  const res = await request(app).get('/health');

  assert.equal(res.status, 503);
  assert.equal(res.body.status, 'unhealthy');
  assert.equal(res.body.checks.database, 'down');

  await pool.end();
});

test('GET / renders the home page with version and database status', async () => {
  const { app, pool } = await setupTestApp();
  const res = await request(app).get('/');

  assert.equal(res.status, 200);
  assert.match(res.headers['content-type'], /html/);
  assert.match(res.text, /Automated Cloud Deployment Pipeline/);
  assert.match(res.text, /UP/);

  await pool.end();
});
