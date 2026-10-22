import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_app/features/auth/shared/auth_scope.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_bits.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_buttons.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_shell.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_skeleton.dart';
import 'package:sim_app/features/auth/sso/sso_cubit.dart';
import 'package:sim_design/sim_design.dart';

/// `/sso` (`auth-sso.md`).
class SsoPage extends StatefulWidget {
  const SsoPage({required this.query, super.key});

  final Map<String, String> query;

  @override
  State<SsoPage> createState() => _SsoPageState();
}

class _SsoPageState extends State<SsoPage> {
  SsoCubit? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final deps = AuthScope.of(context);
    _cubit = SsoCubit(
      api: deps.api,
      navigator: deps.navigator,
      origin: deps.origin,
      query: widget.query,
    );
    unawaited(_cubit!.load());
  }

  @override
  void dispose() {
    unawaited(_cubit?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider<SsoCubit>.value(
    value: _cubit!,
    child: const SsoView(),
  );
}

/// The SSO form under the auth shell plus the absolutely positioned legal
/// line; expects an [SsoCubit] above.
class SsoView extends StatefulWidget {
  const SsoView({super.key});

  @override
  State<SsoView> createState() => _SsoViewState();
}

class _SsoViewState extends State<SsoView> {
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: context.read<SsoCubit>().state.email);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SsoCubit>();
    return Stack(
      children: <Widget>[
        AuthShell(
          onHome: cubit.goHome,
          child: BlocBuilder<SsoCubit, SsoState>(
            builder: (context, state) {
              if (state.loading) return const SsoLoadingSkeleton();
              return _SsoColumn(state: state, email: _email);
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _SsoLegal(onOpen: cubit.openLegal),
        ),
      ],
    );
  }
}

class _SsoColumn extends StatelessWidget {
  const _SsoColumn({required this.state, required this.email});

  final SsoState state;
  final TextEditingController email;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SsoCubit>();
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final options = state.options;
    return Semantics(
      container: true,
      identifier: 'auth.sso.root',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            container: true,
            identifier: 'auth.sso.header',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 4,
              children: <Widget>[
                Semantics(
                  container: true,
                  identifier: 'auth.sso.title',
                  header: true,
                  child: Text(
                    'Sign in with SSO',
                    textAlign: TextAlign.center,
                    style: sim.text
                        .style(40, height: 1.1)
                        .copyWith(
                          color: c.textPrimary,
                          letterSpacing: -0.02 * 40,
                        ),
                  ),
                ),
                Semantics(
                  container: true,
                  identifier: 'auth.sso.description',
                  child: Text(
                    'Enter your work email to continue',
                    textAlign: TextAlign.center,
                    style: sim.text
                        .style(18, height: 1.25)
                        .copyWith(
                          color: c.textMuted.withValues(alpha: 0.6),
                          letterSpacing: 0.02 * 18,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Semantics(
              container: true,
              identifier: 'auth.sso.form',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 32,
                children: <Widget>[
                  if (state.formError != null)
                    AuthFormMessage(
                      lines: <String>[state.formError!],
                      identifier: 'auth.sso.formError',
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: <Widget>[
                      const Row(children: <Widget>[SimLabel('Work email')]),
                      _SsoEmailInput(
                        controller: email,
                        error: state.hasEmailError,
                        onChanged: cubit.emailChanged,
                        onSubmit: cubit.submit,
                      ),
                      if (state.hasEmailError)
                        Semantics(
                          container: true,
                          identifier: 'auth.sso.email.errors',
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: 4,
                              children: <Widget>[
                                for (final error in state.visibleEmailErrors)
                                  Text(
                                    error,
                                    style: sim.text.caption.copyWith(
                                      color: c.textError,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  AuthSubmitButton(
                    label: 'Continue with SSO',
                    loadingLabel: 'Redirecting to SSO provider…',
                    identifier: 'auth.sso.submit',
                    loading: state.submitting,
                    onPressed: cubit.submit,
                  ),
                ],
              ),
            ),
          ),
          if (options.emailEnabled) ...<Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: AuthDivider(label: 'Or', identifier: 'auth.sso.divider'),
            ),
            _OutlineLinkButton(
              label: 'Sign in with email',
              identifier: 'auth.sso.emailLink',
              href: cubit.loginHref,
              onPressed: cubit.goToLogin,
            ),
          ],
          if (options.emailEnabled && !options.registrationDisabled)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Semantics(
                container: true,
                identifier: 'auth.sso.signupPrompt',
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      const TextSpan(text: "Don't have an account? "),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: AuthTextLink(
                          label: 'Sign up',
                          identifier: 'auth.sso.signupLink',
                          style: sim.text.style(15, weight: 300),
                          restColor: c.textPrimary,
                          isLink: true,
                          onPressed: cubit.goToSignup,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: sim.text.base.copyWith(color: c.textPrimary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The legacy emcn `Input` (`input.tsx:31-32`) with the SSO error border:
/// rounded-sm, `--surface-5`, px-2 py-1.5, 14px `--text-primary`.
class _SsoEmailInput extends StatelessWidget {
  const _SsoEmailInput({
    required this.controller,
    required this.error,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool error;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    // `text-sm` on a 20px line: 6 + 20 + 6 + 2 = 34px tall.
    final style = sim.text
        .style(14, height: 20 / 14)
        .copyWith(color: c.textPrimary);
    return Semantics(
      container: true,
      identifier: 'auth.sso.email',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface5,
          border: Border.all(color: error ? c.textError : c.border),
          borderRadius: BorderRadius.circular(SimRadii.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SimEditable(
            controller: controller,
            placeholder: 'Enter your work email',
            style: style,
            placeholderStyle: style.copyWith(color: c.textMuted),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
            onKeyEvent: (node, event) {
              if (!isPlainEnter(event)) return KeyEventResult.ignored;
              onSubmit();
              return KeyEventResult.handled;
            },
            semanticsLabel: 'Work email',
          ),
        ),
      ),
    );
  }
}

/// Legacy `Button variant='outline'` (`button.tsx:37-38, 54`) wrapped in a
/// `Link`: full width, 32px tall, 12px label, radius 10, border
/// `--text-muted` / text `--text-secondary`, hovering to `--text-secondary`
/// border and `--text-primary` text.
class _OutlineLinkButton extends StatelessWidget {
  const _OutlineLinkButton({
    required this.label,
    required this.identifier,
    required this.href,
    required this.onPressed,
  });

  final String label;
  final String identifier;
  final String href;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return Semantics(
      container: true,
      identifier: identifier,
      value: href,
      child: SimPressable(
        onPressed: onPressed,
        isLink: true,
        semanticsLabel: label,
        builder: (context, state) {
          final paint = resolveButtonPaint(
            c,
            variant: SimButtonVariant.outline,
            size: SimButtonSize.md,
            hovered: state.hovered,
          );
          return AnimatedContainer(
            duration: SimMotion.of(SimMotion.colors),
            height: 32,
            decoration: BoxDecoration(
              color: paint.fill,
              border: paint.border,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: sim.text.style(12).copyWith(color: paint.text),
            ),
          );
        },
      ),
    );
  }
}

/// The SSO page's legal line (`sso-form.tsx:290-309`): pinned to the shell
/// bottom, full width, 44px side padding (32 below md), 32px bottom padding,
/// 14px / 22.75px in `--text-muted` with muted links.
class _SsoLegal extends StatelessWidget {
  const _SsoLegal({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => AuthLightTheme(
    child: Builder(
      builder: (context) {
        final sim = SimTheme.of(context);
        final c = sim.colors;
        final width = MediaQuery.sizeOf(context).width;
        final style = sim.text
            .style(14, height: 1.625)
            .copyWith(color: c.textMuted);
        return Semantics(
          container: true,
          identifier: 'auth.sso.legal',
          child: Padding(
            padding: EdgeInsets.only(
              left: width >= SimBreakpoints.md ? 44 : 32,
              right: width >= SimBreakpoints.md ? 44 : 32,
              bottom: 32,
            ),
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  const TextSpan(text: 'By signing in, you agree to our '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: AuthTextLink(
                      label: 'Terms of Service',
                      identifier: 'auth.sso.legal.terms',
                      style: style,
                      mutedBase: true,
                      isLink: true,
                      onPressed: () => onOpen('/terms'),
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: AuthTextLink(
                      label: 'Privacy Policy',
                      identifier: 'auth.sso.legal.privacy',
                      style: style,
                      mutedBase: true,
                      isLink: true,
                      onPressed: () => onOpen('/privacy'),
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
        );
      },
    ),
  );
}

/// `sso/loading.tsx`: the route skeleton.
class SsoLoadingSkeleton extends StatelessWidget {
  const SsoLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const AuthLoadingFrame(
    identifier: 'auth.sso.loading',
    children: <Widget>[
      AuthLoadingSkeleton(shape: AuthSkeletonShape.title, width: 120),
      AuthLoadingSkeleton(
        shape: AuthSkeletonShape.label,
        width: 260,
        marginTop: 12,
      ),
      AuthLoadingField(labelWidth: 80, marginTop: 32),
      AuthLoadingSkeleton(shape: AuthSkeletonShape.control, marginTop: 24),
      AuthLoadingSkeleton(
        shape: AuthSkeletonShape.label,
        width: 120,
        marginTop: 24,
      ),
    ],
  );
}
