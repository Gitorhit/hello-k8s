# ============================================================
# Dockerfile — Instructions to package your app into a container.
# ============================================================
#
# WHY CONTAINERIZE?
# You've deployed containers to ECS, so you know the value:
# a container bundles your app + dependencies into one portable unit.
# This Dockerfile is the "recipe" to build that container image.
#
# MULTI-STAGE BUILD EXPLAINED:
# We use TWO stages: "builder" and "runner".
# - Stage 1 (builder): Install ALL dependencies (including dev tools like jest)
# - Stage 2 (runner): Copy ONLY production code + deps (no test tools)
# Result: a much smaller, more secure final image.
# Think of it like: building a car in a factory (stage 1), then shipping
# just the finished car to the customer (stage 2), not the whole factory.
#
# ============================================================

# ── STAGE 1: BUILDER ──────────────────────────────────────────
# Start from an official Node.js image.
# "alpine" = a tiny Linux distro (~5MB base vs ~900MB for Ubuntu).
# Think of this like picking an AMI for EC2 — we want the smallest one.
FROM node:20-alpine AS builder

# Set the working directory inside the container.
# All subsequent commands (COPY, RUN, etc.) happen relative to /app.
# It's like running "mkdir /app && cd /app".
WORKDIR /app

# COPY dependency files FIRST, before the rest of the code.
# WHY? Docker caches each step ("layer"). If package.json hasn't changed
# since last build, Docker skips the "npm ci" step entirely → faster builds!
# This is called "layer caching" and is a key Docker optimization.
COPY package.json package-lock.json ./

# Install ONLY production dependencies (no jest, no supertest).
# "npm ci" is stricter than "npm install":
#   - Uses exact versions from package-lock.json (reproducible builds)
#   - Fails if package-lock.json is out of sync with package.json
#   - Faster because it skips the dependency resolution step
# "--omit=dev" skips devDependencies (jest, supertest) — we don't need
# test tools in the production container.
RUN npm ci --omit=dev

# Now copy the rest of the application source code.
# This is AFTER npm ci so that code changes don't invalidate the
# npm ci cache layer (dependencies rarely change, code changes often).
COPY . .


# ── STAGE 2: RUNNER ───────────────────────────────────────────
# Start a fresh, clean image for the final container.
# We DON'T carry over the build tools, npm cache, or devDependencies.
# Only what we explicitly COPY from stage 1 ends up in the final image.
FROM node:20-alpine AS runner

# Labels add metadata to the image. These show up in registries (GHCR, ECR)
# and help identify what this image is, who built it, and where the source is.
LABEL org.opencontainers.image.source="https://github.com/Gitorhit/hello-k8s"
LABEL org.opencontainers.image.description="Hello K8s learning app"

# Create a non-root user for security.
# By default, containers run as root, which is dangerous:
# if someone exploits your app, they have root access to the container.
# Running as a non-root user limits the blast radius.
# (In ECS, you'd set this in the Task Definition's "user" field.)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set working directory in the clean image.
WORKDIR /app

# Copy ONLY what we need from the builder stage:
# - node_modules/ (production deps only, no jest/supertest)
# - All .js files (our app code)
# - package.json (for "npm start")
# The "--from=builder" flag means "copy from stage 1, not from my local machine".
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/server.js ./server.js

# Switch to non-root user. All subsequent commands and the running
# container will use this user instead of root.
USER appuser

# EXPOSE tells Docker (and Kubernetes) which port the app listens on.
# It does NOT actually open the port — it's documentation for humans
# and tools like K8s to know where to route traffic.
# In ECS, this is the containerPort in your Task Definition.
EXPOSE 8080

# HEALTHCHECK lets Docker itself monitor if your app is healthy.
# Docker will hit GET /health every 30s. If it fails 3 times, Docker
# marks the container as "unhealthy".
# In K8s, we'll use livenessProbe instead (more flexible), but this
# is useful for local Docker development and Docker Compose.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# CMD is the command that runs when the container starts.
# "node server.js" = start your Express app.
# In ECS, you'd set this in the Task Definition's "command" field.
# We use the array form ["node", "server.js"] instead of a string
# so signals (SIGTERM) go directly to Node.js, enabling graceful shutdown.
CMD ["node", "server.js"]
