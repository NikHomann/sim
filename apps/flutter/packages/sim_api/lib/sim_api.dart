/// Sim backend client for the Flutter port: the Dio client, streaming and
/// SSE decoders, auth, uploads, key-value persistence, the query cache, the
/// socket transport, and the Phase 1 contracts and repositories (plan §4.3,
/// `docs/port/specs/data-phase1.md`).
library;

export 'src/auth/auth_models.dart';
export 'src/auth/auth_repository.dart';
export 'src/client/api_client_error.dart';
export 'src/client/client_id.dart';
export 'src/client/cookie_storage.dart';
export 'src/client/platform/origin.dart' show resolvePageOrigin;
export 'src/client/query_serialization.dart';
export 'src/client/retry.dart';
export 'src/client/sim_http_client.dart';
export 'src/client/streaming/fetch_streaming.dart';
export 'src/contracts/blocks.dart';
export 'src/contracts/common.dart';
export 'src/contracts/folders.dart';
export 'src/contracts/invitations.dart';
export 'src/contracts/json.dart';
export 'src/contracts/organizations.dart';
export 'src/contracts/pinned_items.dart';
export 'src/contracts/public_env.dart';
export 'src/contracts/recently_deleted.dart';
export 'src/contracts/user.dart';
export 'src/contracts/workflows.dart';
export 'src/contracts/workspaces.dart';
export 'src/mothership/envelope_contract.dart';
export 'src/mothership/mothership_client.dart';
export 'src/mothership/mothership_models.dart';
export 'src/query/query_client.dart';
export 'src/realtime/realtime_transport.dart';
export 'src/realtime/socket_transport.dart';
export 'src/repositories/blocks_repository.dart';
export 'src/repositories/contract_request.dart';
export 'src/repositories/folders_repository.dart';
export 'src/repositories/help_repository.dart';
export 'src/repositories/invitations_repository.dart';
export 'src/repositories/organizations_repository.dart';
export 'src/repositories/pinned_items_repository.dart';
export 'src/repositories/recently_deleted_repository.dart';
export 'src/repositories/runtime_config_repository.dart';
export 'src/repositories/settings_repository.dart';
export 'src/repositories/users_repository.dart';
export 'src/repositories/workflows_repository.dart';
export 'src/repositories/workspaces_repository.dart';
export 'src/sse/api_stream.dart';
export 'src/sse/execution_stream.dart';
export 'src/sse/mothership_stream.dart';
export 'src/sse/named_events.dart';
export 'src/sse/sse_decoder.dart';
export 'src/storage/file_key_value_store.dart'
    if (dart.library.js_interop) 'src/storage/indexed_db_key_value_store.dart';
export 'src/storage/key_value_store.dart';
export 'src/storage/platform/platform_store.dart';
export 'src/storage/shared_web_state.dart';
export 'src/uploads/upload_models.dart';
export 'src/uploads/upload_session.dart';
