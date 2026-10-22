/// Question/credential pairing of the transcript, port of
/// `interactionPairing` (`mothership-chat.tsx:615-665`): an assistant
/// `<question>` or `<credential>` card is paired with the user message that
/// completed it. The paired user message is hidden (the answered card IS the
/// user turn) and the card renders its recap, live and on reload. A
/// credential card the user talked past is abandoned: it collapses to the
/// recap with every row "Skipped".
library;

import 'dart:convert';

import 'package:sim_app/features/chat/engine/engine.dart';
import 'package:sim_app/features/chat/messages/markdown/special_tags.dart'
    show parseLastQuestionTag;
import 'package:sim_app/features/chat/messages/model/chat_message_view.dart';

/// What the transcript pairs, by message index.
class InteractionPairing {
  const InteractionPairing({
    this.answersByIndex = const {},
    this.credentialRecapByIndex = const {},
    this.hiddenUserIndexes = const {},
  });

  /// `answersByIndex`: the answers of an answered question card.
  final Map<int, List<String>> answersByIndex;

  /// The recap rows of a submitted (`credentialSubmissionByIndex`) or
  /// abandoned (`credentialAbandonedByIndex`) credential card.
  final Map<int, List<ChatCredentialRecapItem>> credentialRecapByIndex;

  /// `hiddenUserByIndex`.
  final Set<int> hiddenUserIndexes;
}

/// `interactionPairing` (`mothership-chat.tsx:615-665`).
InteractionPairing pairInteractions(List<ChatMessage> messages) {
  final answers = <int, List<String>>{};
  final recaps = <int, List<ChatCredentialRecapItem>>{};
  final hidden = <int>{};
  var lastUserIndex = -1;
  for (var i = 0; i < messages.length; i++) {
    if (messages[i].isUser) lastUserIndex = i;
  }
  for (var index = 0; index < messages.length; index++) {
    final message = messages[index];
    if (message.isUser) continue;
    final next = index + 1 < messages.length ? messages[index + 1] : null;
    final answer = next != null && next.isUser && next.content.isNotEmpty
        ? next.content
        : null;
    final superseded = index < lastUserIndex;
    if (answer == null && !superseded) continue;
    final content = message.content;
    if (answer != null && content.contains('</question>')) {
      final questions = parseLastQuestionTag(content);
      final parsed = questions == null
          ? null
          : parseQuestionAnswerMessage([
              for (final q in questions) q.prompt,
            ], answer);
      if (parsed != null) {
        answers[index] = parsed;
        hidden.add(index + 1);
        continue;
      }
    }
    if (content.contains('</credential>')) {
      final credentials = parseLastCredentialTag(content);
      if (credentials == null) continue;
      final submission = answer == null
          ? null
          : parseCredentialSubmissionProgress(credentials, answer);
      if (submission != null) {
        recaps[index] = credentialRecap(credentials, submission);
        hidden.add(index + 1);
      } else if (superseded) {
        // `abandoned && needsContinuation`: a card without integration or
        // secret rows keeps rendering as it was.
        final recap = credentialRecap(credentials, null);
        if (recap.isNotEmpty) recaps[index] = recap;
      }
    }
  }
  return InteractionPairing(
    answersByIndex: answers,
    credentialRecapByIndex: recaps,
    hiddenUserIndexes: hidden,
  );
}

/// `parseQuestionAnswerMessage` (`question.tsx:41-55`): exactly one
/// `Prompt — Answer` line per question, in order; null otherwise.
List<String>? parseQuestionAnswerMessage(List<String> prompts, String content) {
  final lines = content.split('\n');
  if (lines.length != prompts.length) return null;
  final answers = <String>[];
  for (var i = 0; i < prompts.length; i++) {
    final prefix = '${prompts[i]} — ';
    if (!lines[i].startsWith(prefix)) return null;
    answers.add(lines[i].substring(prefix.length));
  }
  return answers;
}

/// `CREDENTIAL_TAG_TYPES` (`special-tags.tsx:159-170`).
const Set<String> credentialTagTypes = {
  'env_key',
  'oauth_key',
  'sim_key',
  'credential_id',
  'link',
  'secret_input',
  'folder_access',
  'browser_takeover',
  'terminal_handoff',
  'service_account',
};

/// One `<credential>` control (`CredentialItemData`), the fields the
/// pairing reads.
class CredentialItem {
  const CredentialItem({required this.type, this.provider, this.name});

  final String type;
  final String? provider;
  final String? name;

  bool get isIntegration => type == 'link' || type == 'service_account';
  bool get isSecret => type == 'secret_input';
}

/// `parseCredentialTagBody` (`special-tags.tsx:608-619`): a singleton object
/// or a non-empty array; one invalid control rejects the whole card. The
/// per-type value checks of `isCredentialItemData` and the search-connection
/// body (`connectorType`) are not ported: such a card is never paired.
List<CredentialItem>? parseCredentialTagBody(String body) {
  Object? parsed;
  try {
    parsed = jsonDecode(body);
  } on FormatException {
    return null;
  }
  final raw = parsed is List ? parsed : [parsed];
  if (raw.isEmpty) return null;
  final items = <CredentialItem>[];
  for (final item in raw) {
    if (item is! Map || item['connectorType'] != null) return null;
    final type = item['type'];
    if (type is! String || !credentialTagTypes.contains(type)) return null;
    final provider = item['provider'];
    final name = item['name'];
    items.add(
      CredentialItem(
        type: type,
        provider: provider is String ? provider : null,
        name: name is String ? name : null,
      ),
    );
  }
  return items;
}

/// `parseLastCredentialTag` (`special-tags.tsx:623-628`).
List<CredentialItem>? parseLastCredentialTag(String content) {
  final last = RegExp(
    r'<credential>([\s\S]*?)</credential>',
  ).allMatches(content).lastOrNull;
  return last == null ? null : parseCredentialTagBody(last.group(1)!);
}

/// `CredentialSubmissionPayload`: per-name outcomes.
class CredentialSubmission {
  const CredentialSubmission({
    required this.integrations,
    required this.secrets,
  });

  /// `connected` / `skipped` by integration index.
  final List<String> integrations;

  /// `saved` / `skipped` by secret index.
  final List<String> secrets;
}

List<String> _expectedIntegrations(List<CredentialItem> data) => [
  for (final item in data)
    if (item.isIntegration && (item.provider?.trim().isNotEmpty ?? false))
      item.provider!.trim(),
];

List<String> _expectedSecrets(List<CredentialItem> data) => [
  for (final item in data)
    if (item.isSecret && (item.name?.trim().isNotEmpty ?? false))
      item.name!.trim(),
];

/// `parseCredentialSubmissionProgress` (`special-tags.tsx:258-315`): the
/// legacy "Credential setup complete — …" line (everything done) or the
/// "Credential setup submitted — {json}" payload, validated name by name
/// against the card.
CredentialSubmission? parseCredentialSubmissionProgress(
  List<CredentialItem> data,
  String content,
) {
  final integrations = _expectedIntegrations(data);
  final secrets = _expectedSecrets(data);
  final legacyParts = [
    if (integrations.isNotEmpty) 'integrations: ${integrations.join(', ')}',
    if (secrets.isNotEmpty) 'secrets: ${secrets.join(', ')}',
  ];
  final legacy =
      'Credential setup complete'
      '${legacyParts.isNotEmpty ? ' — ${legacyParts.join('; ')}' : ''}';
  if (content == legacy) {
    return CredentialSubmission(
      integrations: [for (final _ in integrations) 'connected'],
      secrets: [for (final _ in secrets) 'saved'],
    );
  }
  const prefix = 'Credential setup submitted — ';
  if (!content.startsWith(prefix)) return null;
  Object? payload;
  try {
    payload = jsonDecode(content.substring(prefix.length));
  } on FormatException {
    return null;
  }
  if (payload is! Map) return null;
  List<String>? statuses(Object? list, List<String> names, Set<String> ok) {
    if (list is! List || list.length != names.length) return null;
    final out = <String>[];
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! Map ||
          item['name'] != names[i] ||
          !ok.contains(item['status'])) {
        return null;
      }
      out.add(item['status']! as String);
    }
    return out;
  }

  final connected = statuses(payload['integrations'], integrations, const {
    'connected',
    'skipped',
  });
  final saved = statuses(payload['secrets'], secrets, const {
    'saved',
    'skipped',
  });
  return connected == null || saved == null
      ? null
      : CredentialSubmission(integrations: connected, secrets: saved);
}

/// The recap rows of `CredentialDisplay` (`special-tags.tsx:3248-3279`):
/// integration rows ("Connected"/"Skipped") then secret rows
/// ("Added"/"Skipped"); an abandoned card ([submission] null) has no local
/// progress after a reload, so every row reads "Skipped". The row filter of
/// `isCredentialCardItemVisible` (request mode, edit permission, link URL
/// safety) and the provider display names of
/// `getCredentialProviderDisplayName` are not applied: rows name the raw
/// provider id.
List<ChatCredentialRecapItem> credentialRecap(
  List<CredentialItem> data,
  CredentialSubmission? submission,
) {
  final integrationRows = <ChatCredentialRecapItem>[];
  final secretRows = <ChatCredentialRecapItem>[];
  var integrationIndex = 0;
  var secretIndex = 0;
  for (final item in data) {
    if (item.isIntegration) {
      final i = integrationIndex++;
      final connected =
          submission != null &&
          i < submission.integrations.length &&
          submission.integrations[i] == 'connected';
      integrationRows.add(
        ChatCredentialRecapItem(
          label: item.provider ?? 'Integration',
          status: connected ? 'Connected' : 'Skipped',
        ),
      );
    } else if (item.isSecret) {
      final i = secretIndex++;
      final saved =
          submission != null &&
          i < submission.secrets.length &&
          submission.secrets[i] == 'saved';
      secretRows.add(
        ChatCredentialRecapItem(
          label: item.name ?? 'Secret',
          status: saved ? 'Added' : 'Skipped',
        ),
      );
    }
  }
  return [...integrationRows, ...secretRows];
}
