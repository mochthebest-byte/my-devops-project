# syntax=docker/dockerfile:1
# Multi-arch: use BUILDPLATFORM for build stage, TARGETPLATFORM for final image
FROM --platform=$BUILDPLATFORM node:22-slim
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# add curl for healthcheck + fix CVEs in base image
RUN apt-get update && \
    apt-get upgrade -y --no-install-recommends && \
    apt-get install -y --no-install-recommends curl tini && \
    rm -rf /var/lib/apt/lists/*

# have nodemon available for local dev use (file watching)
RUN npm install -g nodemon

WORKDIR /usr/local/app

COPY package*.json ./

RUN npm ci && \
 npm cache clean --force && \
 mv /usr/local/app/node_modules /node_modules

COPY . .

ENV PORT=80
EXPOSE 80

# Run as non-root user for security
RUN useradd -u 1001 -r -s /bin/false appuser
USER appuser

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "server.js"]
