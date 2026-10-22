/// Tool-permission prompts, port of `stores/tool-permission/store.ts` and
/// the submit logic of `agent-group/tool-permission-card.tsx:78-231`
/// (spec chat-engine §4.14).
///
/// Cards register while they show an `awaiting_approval` call; the first
/// outstanding card offers "Allow all / Skip all" when more than one waits.
/// Decisions: Allow (`allow`), Don't ask again → For this chat
/// (`allow_chat`) / For every chat (`always_allow`), Skip (`skip`).
library;

import 'package:flutter/foundation.dart';
import 'package:sim_api/sim_api.dart';

/// The outcome of a decision POST, for the card.
enum ToolPermissionOutcome {
  /// Recorded (or another tab answered first: `applied:false`, which the
  /// card ignores, as React does).
  recorded,

  /// 404: the gate is off or the call is gone; the card shows
  /// "<title> — this request is no longer active".
  expired,

  /// Any other failure: toast "Could not record your choice. Please try
  /// again." and the buttons re-enable.
  failed,
}

const toolPermissionErrorToast =
    'Could not record your choice. Please try again.';

/// The 404 line of an expired prompt.
String toolPermissionExpiredLine(String title) =>
    '$title — this request is no longer active';

class ToolPermissionStore extends ChangeNotifier {
  final List<String> _awaiting = [];
  final List<String> _submitted = [];

  /// Awaiting ids in mount order.
  List<String> get awaitingIds => List.unmodifiable(_awaiting);
  List<String> get submittedIds => List.unmodifiable(_submitted);

  bool isSubmitted(String id) => _submitted.contains(id);

  /// Ids still waiting for an answer (registered, not submitted).
  List<String> get outstandingIds => [
    for (final id in _awaiting)
      if (!_submitted.contains(id)) id,
  ];

  /// Whether [id]'s card shows the bulk "N tools need permission · Allow all
  /// · Skip all" row: it is the first outstanding card and more than one
  /// waits (`tool-permission-card.tsx:100-104`).
  bool showsBulkActions(String id) {
    final outstanding = outstandingIds;
    return outstanding.length > 1 && outstanding.first == id;
  }

  void register(String id) {
    if (_awaiting.contains(id)) return;
    _awaiting.add(id);
    notifyListeners();
  }

  void unregister(String id) {
    _awaiting.remove(id);
    _submitted.remove(id);
    notifyListeners();
  }

  void markSubmitted(List<String> ids) {
    final next = ids.where((id) => !_submitted.contains(id)).toList();
    if (next.isEmpty) return;
    _submitted.addAll(next);
    notifyListeners();
  }

  void clearSubmitted(List<String> ids) {
    _submitted.removeWhere(ids.contains);
    notifyListeners();
  }

  void reset() {
    _awaiting.clear();
    _submitted.clear();
    notifyListeners();
  }

  /// Marks [ids] submitted, posts the decision and maps the answer. A
  /// failure clears the submitted mark so the buttons re-enable;
  /// [onAlwaysAllow] runs after an `always_allow` (React invalidates the
  /// general settings).
  Future<ToolPermissionOutcome> decide(
    MothershipClient client,
    List<String> ids,
    ToolPermissionDecision decision, {
    void Function()? onAlwaysAllow,
  }) async {
    if (ids.isEmpty) return ToolPermissionOutcome.recorded;
    markSubmitted(ids);
    try {
      await client.decideToolPermissions({for (final id in ids) id: decision});
      if (decision == ToolPermissionDecision.alwaysAllow) onAlwaysAllow?.call();
      return ToolPermissionOutcome.recorded;
    } on ApiClientError catch (error) {
      if (error.status == 404) return ToolPermissionOutcome.expired;
      clearSubmitted(ids);
      return ToolPermissionOutcome.failed;
    } on Object {
      clearSubmitted(ids);
      return ToolPermissionOutcome.failed;
    }
  }
}
