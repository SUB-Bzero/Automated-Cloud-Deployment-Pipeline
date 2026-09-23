'use strict';

const config = require('./src/config');
const db = require('./src/db');
const { createApp } = require('./src/app');

async function main() {
  // Wait for PostgreSQL (RDS can take a while to accept connections) and
  // apply the schema before accepting traffic.
  await db.waitForDatabase();
  await db.migrate();

  const app = createApp(db);
  const server = app.listen(config.port, () => {
    console.log(
      `[app] listening on :${config.port} ` +
        `(version=${config.version}, env=${config.environment})`,
    );
  });

  // Graceful shutdown so `docker stop` / instance termination drain cleanly.
  const shutdown = (signal) => {
    console.log(`[app] ${signal} received, shutting down`);
    server.close(async () => {
      await db.close();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10000).unref();
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

main().catch((err) => {
  console.error('[app] fatal startup error:', err.message);
  process.exit(1);
});
