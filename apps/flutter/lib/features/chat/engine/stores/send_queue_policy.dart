/// Requeue and resend policy, port of `home/hooks/send-queue-policy.ts`
/// (spec chat-engine §4.11).
library;

import 'dart:math';

import 'package:sim_api/sim_api.dart';
import 'package:sim_app/features/chat/engine/stores/queue_store.dart';

/// Why a send came back instead of going out.
enum WithdrawalReason { withdrawn, offline, unreachable, busy, stopFailed }

/// A withdrawal, or `failed` (the user decides).
enum RequeueReason { withdrawn, offline, unreachable, busy, stopFailed, failed }

RequeueReason requeueReasonOf(WithdrawalReason reason) =>
    RequeueReason.values.byName(reason.name);

const _sendRetryBase = Duration(seconds: 1);
const _sendRetryMax = Duration(seconds: 30);

/// `backoffWithJitter(attempt, null, {baseMs, maxMs})` of `@sim/utils/retry`:
/// `min(base·2^(attempt-1), max)` with ±20 % jitter.
int backoffWithJitterMs(
  int attempt, {
  required Duration base,
  required Duration max,
  Random? random,
}) {
  final exponential = min(
    base.inMilliseconds * pow(2, attempt - 1).toDouble(),
    max.inMilliseconds.toDouble(),
  );
  final jitter = (random ?? Random()).nextDouble();
  return (exponential * (0.8 + jitter * 0.4)).round();
}

/// `sendRetry(attempt)`.
SendRetry sendRetry(int attempt, {required int nowMs, Random? random}) =>
    SendRetry(
      attempt: attempt,
      notBefore:
          nowMs +
          backoffWithJitterMs(
            attempt,
            base: _sendRetryBase,
            max: _sendRetryMax,
            random: random,
          ),
    );

/// `requeuedFields`: offline → hold online; unreachable/busy → retry with
/// backoff; stop-failed/failed → hold for the user; withdrawn → nothing.
QueuedMessage requeued(
  QueuedMessage entry,
  RequeueReason reason, {
  required int previousAttempts,
  required int nowMs,
  String? chatlessSurface,
  Random? random,
}) {
  final base = entry.withoutRequeueFields().copyWith(
    heldSurface: chatlessSurface,
  );
  return switch (reason) {
    RequeueReason.offline => base.copyWith(hold: QueueHold.online),
    RequeueReason.unreachable || RequeueReason.busy => base.copyWith(
      retry: sendRetry(previousAttempts + 1, nowMs: nowMs, random: random),
    ),
    RequeueReason.stopFailed ||
    RequeueReason.failed => base.copyWith(hold: QueueHold.user),
    RequeueReason.withdrawn => entry.withoutRequeueFields(),
  };
}

/// `acceptedMessageIds`: user messages plus the running turn.
Set<String> acceptedMessageIds(MothershipChatHistory history) => {
  for (final m in history.messages)
    if (m.role == 'user') m.id,
  ?history.activeStreamId,
};

/// `needsResendCheck`.
bool needsResendCheck(QueuedMessage entry) =>
    (entry.admissionUnknown ?? false) && entry.resumeUserMessageId != null;

enum ResendVerdict { send, wait, drop }

/// `resendVerdict`: drop when history shows it accepted, wait when the
/// history could not be read.
ResendVerdict resendVerdict(
  QueuedMessage entry,
  MothershipChatHistory? history,
) {
  final requestId = entry.resumeUserMessageId;
  if (!needsResendCheck(entry) || requestId == null) return ResendVerdict.send;
  if (history == null) return ResendVerdict.wait;
  return acceptedMessageIds(history).contains(requestId)
      ? ResendVerdict.drop
      : ResendVerdict.send;
}

/// `shouldQueueOutgoingMessage`: queue while sending (or admitting), while
/// a stop is pending, or behind anything already queued.
bool shouldQueueOutgoingMessage({
  required bool sending,
  required bool stopPending,
  required int queuedAhead,
}) => sending || stopPending || queuedAhead > 0;
