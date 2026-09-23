'use strict';

const express = require('express');
const config = require('./config');
const defaultDb = require('./db');

/**
 * Renders a small self-describing home page so a browser visit immediately
 * shows which version is deployed and whether the database is reachable.
 */
function renderHomePage({ version, environment, database, itemCount }) {
  const dbUp = database === 'up';
  const dbLabel = dbUp ? `UP (${itemCount} items)` : 'DOWN';
  const dbColor = dbUp ? '#16a34a' : '#dc2626';
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ACDP Demo App</title>
<style>
  :root { color-scheme: dark; }
  body { font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
         background: #0f172a; color: #e2e8f0; margin: 0; display: flex;
         min-height: 100vh; align-items: center; justify-content: center; }
  .card { background: #1e293b; border-radius: 16px; padding: 40px 48px;
          box-shadow: 0 20px 50px rgba(0,0,0,.45); max-width: 640px; }
  h1 { margin: 0 0 4px; font-size: 1.6rem; letter-spacing: .3px; }
  .sub { color: #94a3b8; margin: 0 0 24px; }
  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  .tile { background: #0f172a; border: 1px solid #334155; border-radius: 10px;
          padding: 14px 16px; }
  .label { font-size: .72rem; text-transform: uppercase; letter-spacing: .08em;
           color: #94a3b8; margin-bottom: 6px; }
  .value { font-size: 1.05rem; font-weight: 600; }
  footer { margin-top: 24px; color: #64748b; font-size: .8rem; line-height: 1.6; }
  code { background: #334155; padding: 1px 6px; border-radius: 4px; }
  .pill { display: inline-block; padding: 2px 10px; border-radius: 999px;
          color: #fff; background: ${dbColor}; }
</style>
</head>
<body>
  <main class="card">
    <h1>Automated Cloud Deployment Pipeline</h1>
    <p class="sub">Containerized demo application &mdash; Node.js / Express / PostgreSQL</p>
    <div class="grid">
      <div class="tile"><div class="label">Version</div>
        <div class="value">${version}</div></div>
      <div class="tile"><div class="label">Environment</div>
        <div class="value">${environment}</div></div>
      <div class="tile"><div class="label">Database</div>
        <div class="value"><span class="pill">${dbLabel}</span></div></div>
      <div class="tile"><div class="label">App port</div>
        <div class="value">${config.port}</div></div>
    </div>
    <footer>
      Health endpoint: <code>GET /health</code> &middot; Items API:
      <code>GET /api/items</code> &middot; <code>POST /api/items</code>
    </footer>
  </main>
</body>
</html>`;
}

/**
 * Express application factory. The database layer is injected so unit tests
 * can supply their own connection pool.
 */
function createApp(db = defaultDb) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json());

  // Liveness/readiness probe used by Docker, the ALB target group health check
  // and the CI smoke test. Returns 503 when the database is unreachable.
  app.get('/health', async (_req, res) => {
    const database = await db.checkDatabase();
    const healthy = database === 'up';
    res.status(healthy ? 200 : 503).json({
      status: healthy ? 'ok' : 'unhealthy',
      version: config.version,
      environment: config.environment,
      uptimeSeconds: Math.round(process.uptime()),
      checks: { database },
      timestamp: new Date().toISOString(),
    });
  });

  // Human-friendly landing page that proves version + DB connectivity.
  app.get('/', async (_req, res, next) => {
    try {
      const database = await db.checkDatabase();
      let itemCount = null;
      if (database === 'up') {
        try {
          itemCount = await db.countItems();
        } catch {
          itemCount = null;
        }
      }
      res.type('html').send(
        renderHomePage({
          version: config.version,
          environment: config.environment,
          database,
          itemCount,
        }),
      );
    } catch (err) {
      next(err);
    }
  });

  // Tiny REST API backed by PostgreSQL.
  app.get('/api/items', async (_req, res, next) => {
    try {
      res.json({ items: await db.listItems() });
    } catch (err) {
      next(err);
    }
  });

  app.post('/api/items', async (req, res, next) => {
    try {
      const title = typeof req.body?.title === 'string' ? req.body.title.trim() : '';
      if (title.length < 1 || title.length > 200) {
        return res
          .status(400)
          .json({ error: "'title' is required (1-200 characters)" });
      }
      res.status(201).json({ item: await db.createItem(title) });
    } catch (err) {
      next(err);
    }
  });

  app.delete('/api/items/:id', async (req, res, next) => {
    try {
      const id = Number.parseInt(req.params.id, 10);
      if (!Number.isInteger(id) || id < 1) {
        return res.status(400).json({ error: 'id must be a positive integer' });
      }
      const deleted = await db.deleteItem(id);
      if (!deleted) {
        return res.status(404).json({ error: `item ${id} not found` });
      }
      res.status(204).end();
    } catch (err) {
      next(err);
    }
  });

  // 404 for unknown routes.
  app.use((_req, res) => {
    res.status(404).json({ error: 'Not found' });
  });

  // Central error handler -> HTTP 500 (this is what feeds the ALB 5xx alarm
  // if the application or database starts failing).
  app.use((err, _req, res, _next) => {
    console.error('[app] unhandled error:', err.message);
    res.status(500).json({ error: 'Internal server error' });
  });

  return app;
}

module.exports = { createApp, renderHomePage };
