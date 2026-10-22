/// Model selection and effort picks, port of `stores/mothership-effort` and
/// `lib/mothership/model-options.ts` (spec chat-engine §4.13, §5).
///
/// `localStorage['mothership-effort']` (Build) and
/// `localStorage['mothership-plan-effort']` (Plan) hold
/// `{"state":{"modelSelection":{"model":…,"fastMode":bool}},"version":0}`;
/// `newChatEffort` and `chatEfforts` are memory only.
library;

import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:sim_app/features/chat/engine/storage/chat_storage.dart';

/// `MothershipEffort` values (`none` is retired and reads as `low`).
const mothershipEfforts = ['low', 'medium', 'high', 'xhigh', 'max'];

/// The simple picker omits `max`.
const mothershipSimpleEfforts = ['low', 'medium', 'high', 'xhigh'];

const mothershipModels = ['gpt-6-astra', 'gpt-6-sol', 'claude-opus-5-5'];

/// `DEFAULT_MOTHERSHIP_EFFORT`.
const defaultMothershipEffort = 'high';

/// `ModelSelection`.
class ModelSelection extends Equatable {
  const ModelSelection({required this.model, this.fastMode = false});

  /// `ModelSelectionSchema.safeParse`: `null` when invalid.
  static ModelSelection? tryParse(Object? json) {
    if (json is! Map) return null;
    final model = json['model'];
    final fast = json['fastMode'];
    if (model is! String ||
        !(mothershipModels.contains(model) || model == 'claude-opus-5')) {
      return null;
    }
    if (fast != null && fast is! bool) return null;
    return ModelSelection(model: model, fastMode: fast == true);
  }

  final String model;
  final bool fastMode;

  /// `normalizeModelSelection`: Opus 5 reads as Opus 5.5, which has no fast
  /// mode.
  ModelSelection normalized() {
    final m = model == 'claude-opus-5' ? 'claude-opus-5-5' : model;
    return ModelSelection(
      model: m,
      fastMode: m != 'claude-opus-5-5' && fastMode,
    );
  }

  Map<String, Object?> toJson() => {'model': model, 'fastMode': fastMode};

  @override
  List<Object?> get props => [model, fastMode];
}

/// `resolveMothershipModelSettings`: without the selector flag Build sends
/// no model selection and caps `max` at `xhigh`; Plan forces Opus 5.5.
({String effort, ModelSelection? modelSelection})
resolveMothershipModelSettings({
  required bool advanced,
  String? effort,
  ModelSelection? modelSelection,
  bool plan = false,
}) {
  var resolved = effort ?? (plan ? 'medium' : defaultMothershipEffort);
  if (resolved == 'none') resolved = 'low';
  if (!advanced) {
    if (!plan && resolved == 'max') resolved = 'xhigh';
    return (
      effort: resolved,
      modelSelection: plan
          ? const ModelSelection(model: 'claude-opus-5-5')
          : null,
    );
  }
  return (
    effort: resolved,
    modelSelection:
        (modelSelection ??
                ModelSelection(
                  model: plan ? 'claude-opus-5-5' : 'gpt-6-astra',
                ))
            .normalized(),
  );
}

/// One store per mode (Build / Plan).
class MothershipEffortStore extends ChangeNotifier {
  MothershipEffortStore(this._storage, {required this.plan}) {
    final raw = _storage.getItem(storageKey);
    if (raw != null) {
      try {
        final envelope = jsonDecode(raw);
        final state = envelope is Map ? envelope['state'] : null;
        final parsed = ModelSelection.tryParse(
          state is Map ? state['modelSelection'] : null,
        );
        if (parsed != null) _modelSelection = parsed.normalized();
      } on FormatException {
        // Invalid → default.
      }
    }
  }

  final ChatStorage _storage;
  final bool plan;

  String get storageKey =>
      plan ? 'mothership-plan-effort' : 'mothership-effort';

  ModelSelection get _default =>
      ModelSelection(model: plan ? 'claude-opus-5-5' : 'gpt-6-astra');

  late ModelSelection _modelSelection = _default;
  String? _newChatEffort;
  final Map<String, ({String effort, int pick})> _chatEfforts = {};
  int _lastPick = 0;

  ModelSelection get modelSelection => _modelSelection;
  String? get newChatEffort => _newChatEffort;
  String? chatEffort(String chatId) => _chatEfforts[chatId]?.effort;

  void _persist() => _storage.setItem(
    storageKey,
    jsonEncode({
      'state': {'modelSelection': _modelSelection.toJson()},
      'version': 0,
    }),
  );

  void setModel(String model) {
    _modelSelection = ModelSelection(
      model: model,
      fastMode: _modelSelection.fastMode,
    ).normalized();
    _persist();
    notifyListeners();
  }

  void setFastMode({required bool fastMode}) {
    _modelSelection = ModelSelection(
      model: _modelSelection.model,
      fastMode: fastMode,
    ).normalized();
    _persist();
    notifyListeners();
  }

  void setNewChatEffort(String? effort) {
    _newChatEffort = effort;
    notifyListeners();
  }

  /// Records a pick and returns its token for [dropChatEffort].
  int setChatEffort(String chatId, String effort) {
    final pick = ++_lastPick;
    _chatEfforts[chatId] = (effort: effort, pick: pick);
    notifyListeners();
    return pick;
  }

  /// Drops a pick whose save failed unless a newer one replaced it.
  bool dropChatEffort(String chatId, int pick) {
    if (_chatEfforts[chatId]?.pick != pick) return false;
    _chatEfforts.remove(chatId);
    notifyListeners();
    return true;
  }

  /// Moves the new-chat pick onto the chat its first send created.
  void adoptNewChatEffort(String chatId, String effort) {
    final pick = ++_lastPick;
    _newChatEffort = null;
    _chatEfforts[chatId] = (effort: effort, pick: pick);
    notifyListeners();
  }

  void reset() {
    _modelSelection = _default;
    _newChatEffort = null;
    _chatEfforts.clear();
    _persist();
    notifyListeners();
  }
}
