# Toolchain (pinned)

| Tool | Version | Notes |
|---|---|---|
| Flutter | 3.38.9 stable (2026-01-28) | as installed at C:\Dev\flutter; upgrading is a user decision (plan §2) |
| Dart | 3.10.8 | package floors must resolve on Dart 3.10 (e.g. desktop_drop 0.8.4, not 0.9.x) |
| Node | 22.18 | dev proxy, parity tooling (Playwright pinned Chromium) |
| Docker Desktop | engine 20.10.22, Compose v2.15.1 | Compose cannot parse the `env_file: path/required` mapping; run from a transformed copy of docker-compose.local.yml |
| bun | not on host | TypeScript scripts run inside a container built from the repo |
| Chrome | 155 | e2e via chromedriver (`flutter drive`), parity via Playwright |
| VS Build Tools | 2026 18.2 | Windows desktop target |

Package pins live in each pubspec.yaml; dependencies use caret ranges and pubspec.lock (committed) is the pin, because several current package versions require Dart >3.10. Upstream baseline: `docs/port/UPSTREAM_COMMIT`.
