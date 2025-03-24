# --- Stage 1: Build the Juice Shop (unchanged from a typical build) ---
FROM node:20-buster as builder

COPY . /juice-shop
WORKDIR /juice-shop

RUN npm i -g typescript ts-node
RUN npm install --omit=dev --unsafe-perm
RUN npm dedupe --omit=dev

# Remove unneeded folders for size
RUN rm -rf frontend/node_modules
RUN rm -rf frontend/.angular
RUN rm -rf frontend/src/assets

# Create logs folder, etc. (generic prep)
RUN mkdir logs

# Build SBOM (optional)
ARG CYCLONEDX_NPM_VERSION=latest
RUN npm install -g @cyclonedx/cyclonedx-npm@$CYCLONEDX_NPM_VERSION
RUN npm run sbom


# --- Stage 2: Final image with SSH Daemon for runtime violation ---
FROM node:20-buster

# Copy application artifacts from builder
COPY --from=builder /juice-shop /juice-shop
WORKDIR /juice-shop

# 1) Install SSH daemon & netcat (for potential suspicious usage)
RUN apt-get update && apt-get install -y \
    openssh-server \
    netcat \
 && rm -rf /var/lib/apt/lists/*

# 2) Configure SSH: create a run directory, set a simple pass or key if you wish
RUN mkdir /var/run/sshd

# 3) Expose the typical app port and SSH port (3000 and 22)
EXPOSE 3000
EXPOSE 22

# 4) Start both the Node app and the SSH service
#    We'll run SSH in the background, then start Juice Shop in the foreground
#    This is purely for demonstration - you typically wouldn't run multiple
#    services in one container.
CMD service ssh start && node build/app.js
