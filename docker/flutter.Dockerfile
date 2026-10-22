# syntax=docker/dockerfile:1
# Flutter web bundle served by Caddy under /app/ (apps/flutter/docs/port/00-plan.md section 3).
#
# Build from the repo root:  docker build -f docker/flutter.Dockerfile -t sim-flutter-web .
# docker-compose.flutter.yml builds it as the `caddy` service. Development does not need this
# image: apps/flutter/tools/dev_proxy.mjs serves `flutter run` behind the same routes.

# ========================================
# Build Stage: pinned Flutter SDK (TOOLCHAIN: Flutter 3.38.9)
# ========================================
FROM ghcr.io/cirruslabs/flutter:3.38.9 AS build
WORKDIR /src/apps/flutter

# The root .dockerignore only excludes top-level build output, so drop any host build artefacts
# that came with the context before resolving dependencies.
COPY apps/flutter/ ./
RUN rm -rf build .dart_tool packages/*/.dart_tool

RUN flutter config --no-analytics --no-cli-animations \
    && flutter pub get

# --no-web-resources-cdn bundles CanvasKit locally so the page's CSP can stay at 'self'.
# --pwa-strategy none: a service worker would keep serving the previous bundle to test runs.
RUN flutter build web --release --base-href /app/ --no-web-resources-cdn --pwa-strategy none

# ========================================
# Runner Stage: Caddy serving the bundle and proxying the rest
# ========================================
FROM caddy:2.10.0-alpine AS runner

COPY docker/caddy/Caddyfile /etc/caddy/Caddyfile
COPY --from=build /src/apps/flutter/build/web /srv/app

EXPOSE 3001
