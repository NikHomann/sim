import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:sim_app/features/auth/shared/auth_redirect.dart';
import 'package:sim_app/features/auth/shared/auth_scope.dart';
import 'package:sim_app/features/auth/shared/auth_session_store.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_shell.dart';
import 'package:sim_design/sim_design.dart';

/// `oauth-error/page.tsx:26-57`: `?error=` → message.
String oauthErrorMessage(String? code) => switch (code) {
  'access_denied' =>
    'You declined the request at the provider, so nothing was connected.',
  'oAuth_code_missing' =>
    'The provider didn’t return a valid response. Please try again.',
  'signup_disabled' =>
    'Account creation is disabled on this instance. Ask your admin to create an account for you.',
  'account_not_linked' =>
    'An account already exists for this email address. Sign in using the method you originally signed up with.',
  'SSO_REQUIRED' =>
    'Your organization requires single sign-on. Sign in through your identity provider.',
  'email_not_found' =>
    'Your identity provider didn’t share an email address with us, so we couldn’t complete sign-in. Please contact your administrator.',
  _ => 'The sign-in couldn’t be completed. Please try again.',
};

/// `/oauth-error` (`auth-oauth-pages.md` C): the handoff frame with the
/// friendly message and the close-this-tab suffix.
class OAuthErrorPage extends StatelessWidget {
  const OAuthErrorPage({required this.query, super.key});

  final Map<String, String> query;

  @override
  Widget build(BuildContext context) {
    final deps = AuthScope.of(context);
    return LogoShell(
      onHome: () => deps.navigator.openTopLevel('/'),
      child: StatusCard(
        identifier: 'oauth.error.card',
        title: 'Sign-in couldn’t be completed',
        description:
            '${oauthErrorMessage(query['error'])} You can close this tab and return to Sim.',
      ),
    );
  }
}

/// `OAUTH_CHAT_ATTEMPT_PARAM` / `OAUTH_CHAT_RETURN_TO_PARAM` and the
/// localStorage record (`lib/credentials/oauth-chat-attempt.ts`).
abstract final class OAuthChatAttempt {
  static const String attemptParam = 'oauthAttempt';
  static const String returnToParam = 'returnTo';
  static const String keyPrefix = 'sim.oauth-chat-attempt.';
  static const Duration closeFallbackDelay = Duration(milliseconds: 400);

  /// `setOAuthChatAttemptStatus`: rewrites the stored attempt's `status`,
  /// leaving a missing record alone.
  static void setStatus(
    AuthSessionStore local,
    String attemptId,
    String status,
  ) {
    final raw = local.read('$keyPrefix$attemptId');
    if (raw == null) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    final updated = <String, Object?>{
      ...decoded.cast<String, Object?>(),
      'status': status,
    };
    local.write('$keyPrefix$attemptId', jsonEncode(updated));
  }

  /// `sanitizeReturnTo`: same-origin only.
  static String? sanitizeReturnTo(String? raw, {required String origin}) {
    if (raw == null || raw.isEmpty) return null;
    if (!validateCallbackUrl(raw, origin: origin)) return null;
    return Uri.parse(origin).resolve(raw).toString();
  }
}

/// `/oauth/chat-complete` (`auth-oauth-pages.md` D): publishes the attempt
/// verdict, closes the window, and falls back to the chat after 400ms.
class OAuthChatCompletePage extends StatefulWidget {
  const OAuthChatCompletePage({required this.query, super.key});

  final Map<String, String> query;

  @override
  State<OAuthChatCompletePage> createState() => _OAuthChatCompletePageState();
}

class _OAuthChatCompletePageState extends State<OAuthChatCompletePage> {
  bool _ran = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ran) return;
    _ran = true;
    final deps = AuthScope.of(context);
    final attemptId = widget.query[OAuthChatAttempt.attemptParam];
    final returnTo = OAuthChatAttempt.sanitizeReturnTo(
      widget.query[OAuthChatAttempt.returnToParam],
      origin: deps.origin,
    );
    if (attemptId != null && attemptId.isNotEmpty) {
      OAuthChatAttempt.setStatus(
        deps.localStore,
        attemptId,
        widget.query.containsKey('error') ? 'failed' : 'connected',
      );
    }
    deps.navigator.closeWindow();
    deps.timers.schedule(OAuthChatAttempt.closeFallbackDelay, () {
      if (mounted) {
        deps.navigator.replaceTopLevel(returnTo ?? defaultPostAuthRoute);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final deps = AuthScope.of(context);
    return LogoShell(
      onHome: () => deps.navigator.openTopLevel('/'),
      child: const StatusCard(
        identifier: 'oauth.chatComplete',
        title: 'Finishing the connection',
        description: 'Returning you to Sim.',
      ),
    );
  }
}

/// `/oauth/credential-connected` (`auth-oauth-pages.md` E).
class CredentialConnectedPage extends StatelessWidget {
  const CredentialConnectedPage({required this.query, super.key});

  final Map<String, String> query;

  @override
  Widget build(BuildContext context) {
    final deps = AuthScope.of(context);
    final connected =
        query['result'] == 'connected' && !query.containsKey('error');
    return LogoShell(
      onHome: () => deps.navigator.openTopLevel('/'),
      child: StatusCard(
        identifier: 'oauth.credentialConnected',
        title: connected ? 'Credential connected' : 'Connection failed',
        description: connected
            ? 'The credential is ready to use. You can close this tab and return to the app that started the connection.'
            : 'The credential could not be connected. Return to the app that started the connection and try again.',
        mutedDescription: false,
        actions: <Widget>[
          Semantics(
            container: true,
            identifier: 'oauth.credentialConnected.open',
            value: defaultPostAuthRoute,
            child: SimChip(
              label: 'Open Sim',
              variant: SimChipVariant.primary,
              isLink: true,
              onPressed: () => deps.navigator.go(defaultPostAuthRoute),
            ),
          ),
        ],
      ),
    );
  }
}
