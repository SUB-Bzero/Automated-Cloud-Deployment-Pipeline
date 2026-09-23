'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const { setupTestApp } = require('./helpers');

test('POST /api/items creates an item and GET /api/items lists it', async () => {
  const { app, pool } = await setupTestApp();

  const created = await request(app)
    .post('/api/items')
    .send({ title: 'deploy to production' });
  assert.equal(created.status, 201);
  assert.equal(created.body.item.title, 'deploy to production');
  assert.ok(created.body.item.id > 0);

  const listed = await request(app).get('/api/items');
  assert.equal(listed.status, 200);
  assert.equal(listed.body.items.length, 1);
  assert.equal(listed.body.items[0].title, 'deploy to production');

  await pool.end();
});

test('POST /api/items rejects an empty or missing title with 400', async () => {
  const { app, pool } = await setupTestApp();

  const empty = await request(app).post('/api/items').send({ title: '   ' });
  assert.equal(empty.status, 400);

  const missing = await request(app).post('/api/items').send({});
  assert.equal(missing.status, 400);

  await pool.end();
});

test('DELETE /api/items/:id removes the item and then returns 404', async () => {
  const { app, pool } = await setupTestApp();

  const created = await request(app)
    .post('/api/items')
    .send({ title: 'temporary item' });
  const id = created.body.item.id;

  const deleted = await request(app).delete(`/api/items/${id}`);
  assert.equal(deleted.status, 204);

  const again = await request(app).delete(`/api/items/${id}`);
  assert.equal(again.status, 404);

  await pool.end();
});

test('GET /api/unknown returns 404 JSON', async () => {
  const { app, pool } = await setupTestApp();
  const res = await request(app).get('/api/unknown');
  assert.equal(res.status, 404);
  assert.deepEqual(res.body, { error: 'Not found' });
  await pool.end();
});
