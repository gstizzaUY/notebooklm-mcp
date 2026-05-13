# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM node:20-slim AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src/ ./src/

RUN npm run build

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM node:20-slim AS runtime

# Chrome / Chromium runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    chromium-sandbox \
    fonts-liberation \
    fonts-noto-color-emoji \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libx11-6 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libxshmfence1 \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy build output and production deps
COPY --from=builder /app/dist ./dist
COPY package*.json ./
RUN npm ci --omit=dev

# Tell Patchright to use the system Chromium instead of downloading its own
ENV BROWSER_CHANNEL=chromium
ENV PATCHRIGHT_SKIP_BROWSER_DOWNLOAD=1

# Use HTTP transport so Easypanel can route requests
ENV NOTEBOOKLM_TRANSPORT=http
ENV NOTEBOOKLM_PORT=3000
ENV NOTEBOOKLM_HOST=0.0.0.0

# Run headless (no display required at runtime after auth is set up)
ENV HEADLESS=true

EXPOSE 3000

# Run as non-root for security (Chrome sandbox still works with --no-sandbox)
RUN groupadd -r appuser && useradd -r -g appuser -d /app appuser \
    && chown -R appuser:appuser /app
USER appuser

CMD ["node", "dist/index.js"]
