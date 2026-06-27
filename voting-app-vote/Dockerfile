# syntax=docker/dockerfile:1
# Multi-arch: use BUILDPLATFORM for build stage, TARGETPLATFORM for final image
# ═══════════════════════════════════════════════════════════════
#  CVE fix: base image pinned by digest for deterministic builds.
#  Scheduled rebuild in CI keeps it fresh (see renovate/dependabot).
#  apt-get upgrade removed — CVE coverage via base image updates.
# ═══════════════════════════════════════════════════════════════
FROM --platform=$BUILDPLATFORM python:3.11-slim@sha256:cdbd05fb6f457ca275ff51ce00d93d865ca0b6a25f5ffb08262d94f6835771e5 AS base
ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Install curl for healthcheck (no apt-get upgrade — deterministic builds)
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Set the application directory
WORKDIR /usr/local/app

# Install our requirements.txt
COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# dev defines a stage for development, where it'll watch for filesystem changes
FROM base AS dev
RUN pip install watchdog
ENV FLASK_ENV=development
CMD ["python", "app.py"]

# final defines the stage that will bundle the application for production
FROM base AS final

# Run as non-root user for security
RUN useradd -u 1001 -r -s /bin/false appuser

# Copy our code from the current folder to the working directory inside the container
COPY . .

# Make port 80 available for links and/or publish
EXPOSE 80

USER appuser

# Define our command to be run when launching the container
CMD ["gunicorn", "app:app", "-b", "0.0.0.0:80", "--log-file", "-", "--access-logfile", "-", "--workers", "4", "--keep-alive", "0"]
