# syntax=docker/dockerfile:1

####################################################################
# Stage 1 — builder: install production dependencies only
####################################################################
FROM node:22-alpine AS builder

WORKDIR /app
COPY package.json package-lock.json ./
# `npm ci` is reproducible (uses the lockfile); --omit=dev keeps the
# runtime layer free of test/lint tooling.
RUN npm ci --omit=dev && npm cache clean --force

####################################################################
# Stage 2 — runtime: slim, non-root image with a HEALTHCHECK
####################################################################
FROM node:22-alpine AS runtime

ENV NODE_ENV=production
WORKDIR /app

# Dedicated unprivileged user (never run as root).
RUN addgroup -S app && adduser -S app -G app

COPY --from=builder --chown=app:app /app/node_modules ./node_modules
COPY --chown=app:app package.json server.js ./
COPY --chown=app:app src ./src

USER app
EXPOSE 8080
ENV PORT=8080

# Docker/engine health check probes /health (used by `docker compose up --wait`).
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||8080)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "server.js"]
