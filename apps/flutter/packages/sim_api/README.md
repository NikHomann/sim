# sim_api

Sim backend client for the Flutter port (plan `docs/port/00-plan.md` §4.3,
transport map `docs/port/03-api-and-auth.md`).

- `SimHttpClient`: Dio with the upstream request conventions (`x-sim-client-id`,
  path/query serialisation, error envelopes to `ApiClientError`), page origin on
  web, configured origin plus a persistent cookie jar on desktop.
- Streaming: fetch-based `HttpClientAdapter` on web, `SseDecoder`, typed decoders
  for the execution stream, the API-flavour stream, mothership stream v1 and the
  named workspace events (`RotatingEventSource`).
- `AuthRepository` (Better Auth endpoints, socket token, desktop handoff redeem).
- `UploadSession` / `UploadSessionClient` (signed upload protocol).
- `KeyValueStore` (IndexedDB on web, JSON file on desktop, in-memory for tests),
  `SharedWebState` for the keys shared with the React app.
- `QueryClient` / `Query<T>` server-data cache.
- `RealtimeTransport` / `SocketTransport` over `socket_io_client`.

Tests: `flutter test` (fake servers on `dart:io`). Contract tests against the
docker stack: `flutter test test_contract --tags contract` with `SIM_BASE_URL`,
`SIM_TEST_EMAIL`, `SIM_TEST_PASSWORD` and `SIM_TEST_WORKFLOW_ID` set.
