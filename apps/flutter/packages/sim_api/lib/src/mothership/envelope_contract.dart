/// Client-side validation of mothership stream v1 envelopes, ported from
/// `parsePersistedStreamEventEnvelope`
/// (`apps/sim/lib/mothership/request/session/contract.ts:233-509`).
///
/// React runs it on every live frame and every batch event; a failure aborts
/// the read with "Client stream schema enforcement failed. ..." (spec
/// chat-engine Â§2.2).
library;

const _knownTypes = {
  'session',
  'text',
  'tool',
  'span',
  'resource',
  'run',
  'error',
  'complete',
};

/// `MothershipStreamV1RunKind` (generated contract): every contracted kind is
/// valid, `steering_applied` included.
const mothershipRunKinds = {
  'checkpoint_pause',
  'resumed',
  'compaction_start',
  'compaction_done',
  'steering_applied',
  'task_armed',
  'task_delivered',
};

/// `ResourceType` of `generated/resources.ts`.
const mothershipResourceTypes = {
  'search',
  'sources',
  'workflow',
  'table',
  'knowledgebase',
  'file',
  'dashboard',
  'test',
  'folder',
  'filefolder',
  'log',
  'task',
  'integration',
  'browser',
  'terminal',
  'generic',
};

const _filePreviewPhases = {
  'file_preview_start',
  'file_preview_target',
  'file_preview_edit_meta',
  'file_preview_content',
  'file_preview_complete',
};

/// The schema-enforcement failure React throws as `StreamSchemaValidationError`.
class MothershipStreamSchemaError implements Exception {
  const MothershipStreamSchemaError(this.message);

  /// `createStreamSchemaValidationError(failure, context)`.
  factory MothershipStreamSchemaError.forFailure(
    List<String> hints, {
    String? context,
    String failure = 'A stream event failed validation.',
  }) => MothershipStreamSchemaError(
    [
      prefix,
      context,
      failure,
      if (hints.isNotEmpty) hints.join('; '),
    ].whereType<String>().where((part) => part.isNotEmpty).join(' '),
  );

  /// Starts with [prefix], like the React message.
  final String message;

  static const prefix = 'Client stream schema enforcement failed.';

  @override
  String toString() => message;
}

/// Hints of why [value] is not a valid envelope; empty when it is valid,
/// and possibly empty for an invalid one too (React lists hints only for
/// `v`, `type` and `payload`): test validity with [isValidMothershipEnvelope].
///
/// Mirrors `isContractEnvelope || isSyntheticFilePreviewEventEnvelope`, and
/// on failure the hint list `parsePersistedStreamEventEnvelope` builds (plus
/// a generic payload hint when the shell was fine but the payload was not).
List<String> mothershipEnvelopeProblems(Object? value) {
  if (_isContractEnvelope(value) || _isSyntheticFilePreview(value)) {
    return const [];
  }
  final hints = <String>[];
  if (value is! Map) {
    hints.add('value is not an object');
    return hints;
  }
  if (value['v'] != 1) hints.add('unexpected v=${_json(value['v'])}');
  final type = value['type'];
  if (type is! String) {
    hints.add('missing type');
  } else if (!_knownTypes.contains(type)) {
    hints.add('unknown type="$type"');
  }
  if (value['payload'] is! Map) hints.add('missing or invalid payload');
  return hints;
}

/// Whether [value] passes the React client validation.
bool isValidMothershipEnvelope(Object? value) =>
    _isContractEnvelope(value) || _isSyntheticFilePreview(value);

String _json(Object? value) => switch (value) {
  null => 'undefined',
  final String s => '"$s"',
  _ => '$value',
};

/// JS `value === undefined || typeof value === 'string'`: an explicit JSON
/// `null` fails, a missing key passes.
bool _optStr(Map<Object?, Object?> map, String key) =>
    !map.containsKey(key) || map[key] is String;

/// An optional field that must satisfy [test] when present (null fails).
bool _opt(Map<Object?, Object?> map, String key, bool Function(Object?) test) =>
    !map.containsKey(key) || test(map[key]);

bool _finite(Object? value) => value is num && value.isFinite;

bool _safeInt(Object? value) =>
    value is num &&
    value.isFinite &&
    value == value.truncate() &&
    value.abs() <= 9007199254740991;

bool _isStreamRef(Object? value) =>
    value is Map &&
    value['streamId'] is String &&
    (value['streamId'] as String).isNotEmpty &&
    _optStr(value, 'chatId') &&
    _optStr(value, 'cursor');

bool _isTrace(Object? value) =>
    value is Map &&
    value['requestId'] is String &&
    _optStr(value, 'goTraceId') &&
    _optStr(value, 'spanId');

bool _isScope(Object? value) =>
    value is Map &&
    value['lane'] == 'subagent' &&
    _optStr(value, 'agentId') &&
    _optStr(value, 'parentToolCallId');

bool _isShell(Map<Object?, Object?> value) {
  if (value['v'] != 1) return false;
  if (!_finite(value['seq'])) return false;
  if (value['ts'] is! String) return false;
  if (!_isStreamRef(value['stream'])) return false;
  if (!_opt(value, 'trace', _isTrace)) return false;
  if (!_opt(value, 'scope', _isScope)) return false;
  final type = value['type'];
  if (type is! String || !_knownTypes.contains(type)) return false;
  return value['payload'] is Map;
}

bool _isContractEnvelope(Object? value) {
  if (value is! Map || !_isShell(value)) return false;
  final payload = value['payload']! as Map;
  return switch (value['type']) {
    'session' => _session(payload),
    'text' => _text(payload),
    'tool' => _tool(payload),
    'span' => const {
      'subagent',
      'structured_result',
      'subagent_result',
    }.contains(payload['kind']),
    'resource' => _resource(payload),
    'run' =>
      payload['kind'] is String &&
          mothershipRunKinds.contains(payload['kind']) &&
          _activityCheckpoint(payload),
    'error' => payload['message'] is String || payload['error'] is String,
    'complete' => payload['status'] is String && _activityCheckpoint(payload),
    _ => false,
  };
}

bool _session(Map<Object?, Object?> payload) => switch (payload['kind']) {
  'start' => true,
  'chat' => payload['chatId'] is String,
  'title' => payload['title'] is String,
  'trace' => payload['requestId'] is String,
  _ => false,
};

bool _text(Map<Object?, Object?> payload) {
  final channel = payload['channel'];
  return (channel == 'assistant' || channel == 'thinking') &&
      payload['text'] is String &&
      _opt(payload, 'textOffset', (v) => _safeInt(v) && (v! as num) >= 0);
}

bool _tool(Map<Object?, Object?> payload) {
  if (!_opt(payload, 'replay', (v) => v == true)) return false;
  if (payload['toolCallId'] is! String) return false;
  if (payload['toolName'] is! String) return false;
  final phase = payload['phase'];
  return phase == 'call' || phase == 'args_delta' || phase == 'result';
}

bool _activityCheckpoint(Map<Object?, Object?> payload) {
  if (!payload.containsKey('activityReceipt')) return true;
  final receipt = payload['activityReceipt'];
  if (receipt is! Map) return false;
  final emitter = receipt['emitterId'];
  final sequence = receipt['sequence'];
  return emitter is String &&
      emitter.isNotEmpty &&
      emitter.length <= 128 &&
      _safeInt(sequence) &&
      (sequence as num) >= 0;
}

bool _nonBlank(Object? value) =>
    value is String && RegExp(r'\S').hasMatch(value);

/// A structural reading of the `ResourcePayload` zod schema: the op, the
/// resource address shape per op, and the optional `effectId`/`replay`.
bool _resource(Map<Object?, Object?> payload) {
  final effectOk = _opt(
    payload,
    'effectId',
    (v) => v is String && v.trim().isNotEmpty && v.trim().length <= 512,
  );
  if (!effectOk) return false;
  if (!_opt(payload, 'replay', (v) => v == true)) return false;
  final resource = payload['resource'];
  if (resource is! Map) return false;
  switch (payload['op']) {
    case 'upsert':
      if (!_opt(payload, 'readOnly', (v) => v == true)) return false;
      return _address(resource);
    case 'remove':
      return _address(resource);
    case 'clear_view':
      return resource['type'] == 'table' &&
          _nonBlank(resource['id']) &&
          _nonBlank(resource['viewId']);
    case 'refresh':
      if (resource['type'] == 'settings') {
        return resource['id'] is String &&
            (resource['id'] as String).trim().isNotEmpty &&
            const {
              'account',
              'organization',
              'workspace',
            }.contains(resource['scope']);
      }
      return mothershipResourceTypes.contains(resource['type']) &&
          _opt(resource, 'id', _nonBlank);
    default:
      return false;
  }
}

bool _address(Map<Object?, Object?> resource) =>
    mothershipResourceTypes.contains(resource['type']) &&
    _nonBlank(resource['id']) &&
    _optStr(resource, 'title') &&
    _optStr(resource, 'workspaceId');

bool _isSyntheticFilePreview(Object? value) {
  if (value is! Map) return false;
  if (value['v'] != 1 || value['type'] != 'tool') return false;
  if (!_finite(value['seq']) || value['ts'] is! String) return false;
  if (!_isStreamRef(value['stream'])) return false;
  if (!_opt(value, 'trace', _isTrace)) return false;
  if (!_opt(value, 'scope', _isScope)) return false;
  final payload = value['payload'];
  if (payload is! Map) return false;
  if (payload['toolCallId'] is! String ||
      payload['toolName'] != 'prepare_file_edit') {
    return false;
  }
  final phase = payload['previewPhase'];
  if (!_filePreviewPhases.contains(phase)) return false;
  switch (phase) {
    case 'file_preview_start':
      return true;
    case 'file_preview_target':
      final target = payload['target'];
      return target is Map &&
          (target['kind'] == 'new_file' || target['kind'] == 'file_id') &&
          _optStr(target, 'fileId') &&
          _optStr(target, 'fileName') &&
          _optStr(payload, 'operation') &&
          _optStr(payload, 'title');
    case 'file_preview_edit_meta':
      return payload['edit'] is Map;
    case 'file_preview_content':
      final mode = payload['contentMode'];
      return payload['content'] is String &&
          (mode == 'delta' || mode == 'snapshot') &&
          _finite(payload['previewVersion']) &&
          payload['fileName'] is String &&
          _optStr(payload, 'fileId') &&
          _optStr(payload, 'targetKind') &&
          _optStr(payload, 'operation') &&
          _opt(payload, 'edit', (v) => v is Map);
    case 'file_preview_complete':
      return _optStr(payload, 'fileId') &&
          _opt(payload, 'previewVersion', _finite);
  }
  return false;
}
