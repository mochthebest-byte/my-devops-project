# syntax=docker/dockerfile:1
# Multi-arch: use BUILDPLATFORM for build stage, TARGETPLATFORM for final image
# ═══════════════════════════════════════════════════════════════
#  CVE fix: base image pinned by digest for deterministic builds.
#  apt-get upgrade removed — CVE coverage via base image updates.
# ═══════════════════════════════════════════════════════════════

# Stage 1: Build dependencies
FROM --platform=$BUILDPLATFORM node:22-slim@sha256:813a7480f28fdadac1f7f5c824bcdad435b5bc1322a5968bbbdef8d058f9dff4 AS build
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# have nodemon available for local dev use (file watching)
RUN npm install -g nodemon

WORKDIR /usr/local/app

COPY package*.json ./

RUN npm ci && \
    npm cache clean --force && \
    mv /usr/local/app/node_modules /node_modules

COPY . .

# Stage 2: Production image
FROM node:22-slim@sha256:813a7480f28fdadac1f7f5c824bcdad435b5bc1322a5968bbbdef8d058f9dff4 AS production

# Install curl + tini for healthcheck (no apt-get upgrade — deterministic builds)
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl tini && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/app

# Copy runtime files from build stage
COPY --from=build /node_modules /usr/local/app/node_modules
COPY --from=build /usr/local/app /usr/local/app

ENV PORT=80
EXPOSE 80

# Run as non-root user for security
RUN useradd -u 1001 -r -s /bin/false appuser
USER appuser

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "server.js"]
