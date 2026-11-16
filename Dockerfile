# A self-hosted Ember in one container. Ember is a Cloudflare Workers app, so this image runs the
# Worker through `wrangler dev` (Miniflare), which simulates Durable Objects, DO SQLite, R2, Images
# and Email on the local machine. It is meant for self-hosting and evaluation, not as a replacement
# for Cloudflare's production runtime. State lives in /data; mount a volume there to keep it.
FROM node:22-bookworm-slim

ENV WRANGLER_SEND_METRICS=false \
    CI=true

RUN corepack enable && corepack prepare pnpm@10.18.3 --activate

WORKDIR /app

# Manifests first, so dependency installation is cached across source changes.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml tsconfig.base.json ./
COPY apps/web/package.json apps/web/
COPY apps/worker/package.json apps/worker/
COPY e2e/package.json e2e/
COPY packages/protocol/package.json packages/protocol/
COPY packages/richtext/package.json packages/richtext/
COPY perf/package.json perf/

RUN pnpm install --frozen-lockfile

# The rest of the source, then the same build CI runs (web assets + Worker dry-run bundle).
COPY . .
RUN pnpm build

EXPOSE 8787
VOLUME ["/data"]

# SESSION_SECRET and EMBER_GUEST_SIGN_IN can be overridden at run time. The defaults match Ember's
# own `pnpm dev`, and are only safe because nobody else should reach a fresh self-hosted instance.
CMD ["sh", "-c", "pnpm --filter @ember/worker exec wrangler dev -c ../../wrangler.jsonc --ip 0.0.0.0 --port 8787 --persist-to /data/state --var SESSION_SECRET:${SESSION_SECRET:-local-dev-only} --var EMBER_GUEST_SIGN_IN:${EMBER_GUEST_SIGN_IN:-false}"]
