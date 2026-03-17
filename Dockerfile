# Dockerfile
#
# A Dockerfile is a recipe. It tells Docker:
# "Here's how to build a box (container image) that runs our app."
#
# We use a TWO-STAGE build:
#   Stage 1 "builder" — install everything (messy, big)
#   Stage 2 "runner"  — copy only what we need (clean, small)
#
# Why two stages? Imagine you're baking a cake:
#   Stage 1: a messy kitchen with flour, bowls, tools everywhere
#   Stage 2: just the finished cake on a plate
# We only ship the cake, not the messy kitchen.

# ─────────────────────────────────────────────
# STAGE 1: Builder — install packages
# ─────────────────────────────────────────────
# "FROM" = start from a base image (like picking a pre-installed OS).
# node:24-alpine means "Linux with Node.js 24, minimal size".
# alpine is a tiny Linux distro (~5MB vs. ~300MB for Ubuntu).
FROM node:24-alpine AS builder

# WORKDIR = "cd into this folder inside the container".
# All commands below run from /app.
WORKDIR /app

# COPY the package files FIRST (before copying the app code).
# Why? Docker builds in layers and CACHES each layer.
# If package.json hasn't changed, Docker skips re-running npm ci
# and uses the cached layer instead — making rebuilds much faster.
COPY package*.json ./

# RUN = execute a command while building the image.
# "npm ci" = clean install using exact versions from package-lock.json.
# "--omit=dev" = skip devDependencies (jest, supertest) — those are
# only needed for tests, not for running the app in production.
RUN npm ci --omit=dev

# NOW copy the app code. This is intentionally after npm ci so that
# code changes (which happen often) don't invalidate the package cache.
COPY . .

# ── STAGE 2: The clean final image ──
# Start fresh — only what we explicitly copy comes along.
# npm cache, intermediate files, etc. are LEFT BEHIND.
FROM node:24-alpine
WORKDIR /app

# Switch to the non-root 'node' user that comes built-in with the image.
# By default, Docker runs everything as the unrestricted 'root' user.
# If a hacker breaches the app, they'd have root access. By switching
# to this restricted user, we lock down the container.
COPY --chown=node:node --from=builder /app .
USER node

# EXPOSE documents which port the app uses.
# It doesn't actually open the port — that happens when you run: -p 8080:8080
EXPOSE 8080

CMD ["node", "server.js"]
