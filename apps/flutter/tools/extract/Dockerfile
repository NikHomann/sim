# syntax=docker/dockerfile:1
#
# One-off extraction image for the Flutter port (docs/port/00-plan.md §4.5).
# Build context is the monorepo root. Mirrors the pruner/deps stages of
# docker/app.Dockerfile (same bun, same turbo prune, same install flags) but
# skips the native toolchain and the isolated-vm rebuild: the export script
# only reads registries and renders React to strings.
#
#   docker build -f apps/flutter/tools/extract/Dockerfile -t sim-flutter-extract .
#   docker run --rm -e UPSTREAM_COMMIT=<sha> -v <abs>/apps/flutter/generated:/out sim-flutter-extract

FROM oven/bun:1.4.2-slim AS pruner
WORKDIR /app
COPY . .
RUN APP_PACKAGE_NAME="$(bun -e "console.log(require('./apps/sim/package.json').name)")" && \
    TURBO_VERSION="$(bun -e "console.log(require('./package.json').devDependencies.turbo)")" && \
    bunx --bun "turbo@${TURBO_VERSION}" prune "$APP_PACKAGE_NAME" --docker

FROM oven/bun:1.4.2-slim AS deps
WORKDIR /app
COPY --from=pruner /app/out/json/ ./
COPY --from=pruner /app/bun.lock ./bun.lock
COPY --from=pruner /app/patches ./patches
# The pruned manifests describe a subset of the full lockfile, so the lockfile
# cannot be frozen here (docker/app.Dockerfile has the same constraint).
RUN --mount=type=cache,id=bun-cache,target=/root/.bun/install/cache \
    HUSKY=0 bun install --ignore-scripts --linker=hoisted

FROM deps AS extract
COPY --from=pruner /app/out/full/ ./
COPY --from=pruner /app/bun.lock ./bun.lock
ENV NODE_ENV=development
ENV FLUTTER_PORT_OUT=/out
ENTRYPOINT ["bun", "--no-env-file", "run", "apps/sim/scripts/export-flutter-port.ts"]
