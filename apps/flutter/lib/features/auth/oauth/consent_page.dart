import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_app/features/auth/oauth/consent_cubit.dart';
import 'package:sim_app/features/auth/shared/auth_scope.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_bits.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_buttons.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_header.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_shell.dart';
import 'package:sim_design/sim_design.dart';

/// `/oauth/consent` (`auth-oauth-pages.md` B).
class OAuthConsentPage extends StatefulWidget {
  const OAuthConsentPage({required this.uri, super.key});

  final Uri uri;

  @override
  State<OAuthConsentPage> createState() => _OAuthConsentPageState();
}

class _OAuthConsentPageState extends State<OAuthConsentPage> {
  ConsentCubit? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final deps = AuthScope.of(context);
    _cubit = ConsentCubit(
      api: deps.api,
      navigator: deps.navigator,
      queryAll: widget.uri.queryParametersAll,
      rawQuery: widget.uri.query,
    );
    unawaited(_cubit!.load());
  }

  @override
  void dispose() {
    unawaited(_cubit?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider<ConsentCubit>.value(
    value: _cubit!,
    child: const OAuthConsentView(),
  );
}

/// The consent column under the auth shell; expects a [ConsentCubit] above.
class OAuthConsentView extends StatelessWidget {
  const OAuthConsentView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ConsentCubit>();
    return AuthShell(
      onHome: cubit.goHome,
      child: BlocBuilder<ConsentCubit, ConsentState>(
        builder: (context, state) => switch (state.phase) {
          ConsentPhase.loading => const OAuthConsentLoading(),
          ConsentPhase.refusal => AuthHeader(
            title: 'Unable to connect',
            description: state.refusalMessage,
            identifier: 'oauth.consent.refusal',
          ),
          ConsentPhase.ready => _ConsentColumn(state: state),
        },
      ),
    );
  }
}

/// `consent/loading.tsx`: header + 20px spinner.
class OAuthConsentLoading extends StatelessWidget {
  const OAuthConsentLoading({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    identifier: 'oauth.consent.loading',
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: <Widget>[
        const AuthHeader(
          title: 'Review app access',
          description: 'Loading the authorization request…',
          identifier: 'oauth.consent.loading',
        ),
        Center(
          child: SimSpinner(
            size: 20,
            color: SimTheme.of(context).colors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

class _ConsentColumn extends StatelessWidget {
  const _ConsentColumn({required this.state});

  final ConsentState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ConsentCubit>();
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final muted = sim.text.caption.copyWith(color: c.textMuted);
    return Semantics(
      container: true,
      identifier: 'oauth.consent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 24,
        children: <Widget>[
          AuthHeader(
            title: 'Authorize ${state.appName}',
            description: state.isCli
                ? null
                : 'Only continue if you started this yourself.',
            identifier: 'oauth.consent',
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: <Widget>[
              if (state.scopes.isNotEmpty)
                Semantics(
                  container: true,
                  identifier: 'oauth.consent.scopes',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 8,
                      children: <Widget>[
                        for (final scope in state.scopes)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 8,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: SimIcon(
                                  SimIcons.check,
                                  color: c.textIcon,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  oauthScopeDescriptions[scope] ?? scope,
                                  style: sim.text.sm.copyWith(
                                    color: c.textBody,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              AuthSubmitButton(
                label: 'Allow',
                loadingLabel: 'Authorizing',
                identifier: 'oauth.consent.allow',
                loading: state.deciding ?? false,
                enabled: !state.isPending,
                onPressed: () => cubit.decide(accept: true),
              ),
              AuthChipButton(
                label: state.deciding == false ? 'Declining…' : 'Deny',
                identifier: 'oauth.consent.deny',
                style: AuthChipStyle.ring,
                enabled: !state.isPending,
                onPressed: () => cubit.decide(accept: false),
              ),
              if (!state.isCli && state.destination != null)
                Semantics(
                  container: true,
                  identifier: 'oauth.consent.destination',
                  child: Text(
                    'Returns to ${state.destination}.',
                    textAlign: TextAlign.center,
                    style: muted,
                  ),
                ),
              if (state.errorMessage != null)
                AuthFormMessage(
                  lines: <String>[state.errorMessage!],
                  identifier: 'oauth.consent.error',
                  center: true,
                ),
              Semantics(
                container: true,
                identifier: 'oauth.consent.account',
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(text: 'Continuing as ${state.email}. '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: AuthTextLink(
                          label: state.switching
                              ? 'Signing out…'
                              : 'Use another account',
                          identifier: 'oauth.consent.switch',
                          style: sim.text.caption,
                          enabled: !state.isPending,
                          onPressed: cubit.switchAccount,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
