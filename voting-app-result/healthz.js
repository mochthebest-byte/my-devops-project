#!/usr/bin/env node
/**
 * Health check HTTP server for Kubernetes probes.
 *
 * Runs on port 8081, separate from the main app (port 80).
 * Serves /healthz and /readyz endpoints for liveness and readiness probes.
 * This avoids coupling health checks to application traffic.
 */

const http = require('http');

const server = http.createServer((req, res) => {
    const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

    if (url.pathname === '/healthz' || url.pathname === '/readyz') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ status: 'ok' }));
    } else {
        res.writeHead(404);
        res.end();
    }
});

const PORT = 8081;
server.listen(PORT, '0.0.0.0', () => {
    console.log(`Healthz server listening on port ${PORT}`);
});
