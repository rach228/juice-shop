FROM node:20-buster as installer
COPY . /juice-shop
WORKDIR /juice-shop

# Install necessary tooling and dependencies
RUN npm i -g typescript ts-node
RUN npm install --omit=dev --unsafe-perm
RUN npm dedupe --omit=dev

# Remove unneeded folders
RUN rm -rf frontend/node_modules
RUN rm -rf frontend/.angular
RUN rm -rf frontend/src/assets

# Create logs directory with proper ownership
RUN mkdir logs
RUN chown -R 65532 logs

# Create .well-known/csaf folder and fix permissions
RUN mkdir -p .well-known/csaf
RUN chown -R 65532:0 .well-known/csaf

# Align group ownership and permissions for directories we need to write to
RUN chgrp -R 0 ftp/ frontend/dist/ logs/ data/ i18n/ .well-known/csaf
RUN chmod -R g=u ftp/ frontend/dist/ logs/ data/ i18n/ .well-known/csaf

# Clean up optional files if present
RUN rm data/chatbot/botDefaultTrainingData.json || true
RUN rm ftp/legal.md || true
RUN rm i18n/*.json || true

# Install SBOM generator
ARG CYCLONEDX_NPM_VERSION=latest
RUN npm install -g @cyclonedx/cyclonedx-npm@$CYCLONEDX_NPM_VERSION
RUN npm run sbom

#
# Build libxmljs in a separate stage to avoid runtime issues
#
FROM node:20-buster as libxmljs-builder
WORKDIR /juice-shop
RUN apt-get update && apt-get install -y build-essential python3
COPY --from=installer /juice-shop/node_modules ./node_modules
RUN rm -rf node_modules/libxmljs/build && \
    cd node_modules/libxmljs && \
    npm run build

#
# Final stage: Use Distroless for a minimal runtime
#
FROM gcr.io/distroless/nodejs20-debian11
ARG BUILD_DATE
ARG VCS_REF
LABEL maintainer="Bjoern Kimminich <bjoern.kimminich@owasp.org>" \
      org.opencontainers.image.title="OWASP Juice Shop" \
      org.opencontainers.image.description="Probably the most modern and sophisticated insecure web application" \
      org.opencontainers.image.authors="Bjoern Kimminich <bjoern.kimminich@owasp.org>" \
      org.opencontainers.image.vendor="Open Worldwide Application Security Project" \
      org.opencontainers.image.documentation="https://help.owasp-juice.shop" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="17.2.0" \
      org.opencontainers.image.url="https://owasp-juice.shop" \
      org.opencontainers.image.source="https://github.com/juice-shop/juice-shop" \
      org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.created=$BUILD_DATE

WORKDIR /juice-shop

# Copy app code from installer stage and libxmljs build
COPY --from=installer --chown=65532:0 /juice-shop .
COPY --chown=65532:0 --from=libxmljs-builder /juice-shop/node_modules/libxmljs ./node_modules/libxmljs

USER 65532

EXPOSE 3000
CMD ["/juice-shop/build/app.js"]
