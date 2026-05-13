# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM node:20-slim AS builder

WORKDIR /app

COPY package*.json ./
# --ignore-scripts skips the "prepare" hook (which runs tsc) so the build
# doesn't fail because src/ hasn't been copied yet at this stage.
RUN npm ci --ignore-scripts

COPY tsconfig.json ./
COPY src/ ./src/

RUN npm run build

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM node:20-slim AS runtime

WORKDIR /app

# Copy build output and production deps
COPY --from=builder /app/dist ./dist
COPY package*.json ./
# --ignore-scripts prevents the "prepare" hook from running tsc (devDep, not available here).
RUN npm ci --omit=dev --ignore-scripts

# Install Patchright's bundled Chromium and all its OS-level dependencies.
# --with-deps handles everything (fonts, nss, libgbm, etc.) automatically.
RUN npx patchright install chromium --with-deps

# ── Transport ─────────────────────────────────────────────────────────────────
# Use HTTP transport so Easypanel can route requests to the MCP endpoint.
ENV NOTEBOOKLM_TRANSPORT=http
ENV NOTEBOOKLM_PORT=3000
ENV NOTEBOOKLM_HOST=0.0.0.0

# ── Browser ───────────────────────────────────────────────────────────────────
# Use the Patchright bundled Chromium (no system Chrome required).
ENV BROWSER_CHANNEL=chromium
# Headless mode (required in containers without a display server).
ENV HEADLESS=true
# Docker containers run without kernel namespaces for Chrome sandboxing.
# CHROME_NO_SANDBOX=true adds --no-sandbox and --disable-setuid-sandbox to
# the browser launch args (handled in shared-context-manager.ts).
ENV CHROME_NO_SANDBOX=true

EXPOSE 3000

CMD ["node", "dist/index.js"]
