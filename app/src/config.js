'use strict';

/**
 * Central application configuration, read from environment variables so the
 * same image can run locally (docker-compose), in CI tests, and on EC2.
 */
const config = {
  port: Number(process.env.PORT) || 8080,
  databaseUrl:
    process.env.DATABASE_URL || 'postgres://app:app@localhost:5432/appdb',
  version: process.env.APP_VERSION || 'local',
  environment: process.env.NODE_ENV || 'development',
};

module.exports = config;
