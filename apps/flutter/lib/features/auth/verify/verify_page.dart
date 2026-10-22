import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_app/features/auth/shared/auth_scope.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_bits.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_buttons.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_header.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_shell.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_skeleton.dart';
import 'package:sim_app/features/auth/verify/otp_input.dart';
import 'package:sim_app/features/auth/verify/verify_cubit.dart';
import 'package:sim_design/sim_design.dart';

/// `/verify` (`auth-verify.md`).
class VerifyPage extends StatefulWidget {
  const VerifyPage({required this.query, super.key});

  final Map<String, String> query;

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  VerifyCubit? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final deps = AuthScope.of(context);
    _cubit = VerifyCubit(
      api: deps.api,
      navigator: deps.navigator,
      sessionStore: deps.sessionStore,
      timers: deps.timers,
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
  Widget build(BuildContext context) => BlocProvider<VerifyCubit>.value(
    value: _cubit!,
    child: const VerifyView(),
  );
}

/// The verify column under the auth shell; expects a [VerifyCubit] above.
class VerifyView extends StatelessWidget {
  const VerifyView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VerifyCubit>();
    return AuthShell(
      onHome: cubit.goHome,
      child: BlocBuilder<VerifyCubit, VerifyState>(
        builder: (context, state) {
          if (state.loading) return const VerifyLoadingSkeleton();
          return _VerifyColumn(state: state);
        },
      ),
    );
  }
}

class _VerifyColumn extends StatelessWidget {
  const _VerifyColumn({required this.state});

  final VerifyState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VerifyCubit>();
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final muted = sim.text.sm.copyWith(color: c.textMuted);
    return Semantics(
      container: true,
      identifier: 'auth.verify.root',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 24,
        children: <Widget>[
          AuthHeader(
            title: state.title,
            description: state.description,
            identifier: 'auth.verify',
          ),
          if (!state.isVerified && state.isEmailVerificationEnabled)
            Semantics(
              container: true,
              identifier: 'auth.verify.body',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 24,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 20,
                    children: <Widget>[
                      Semantics(
                        container: true,
                        identifier: 'auth.verify.hint',
                        child: Text(
                          'Enter the 6-digit code to verify your account.'
                          '${state.hasEmailService ? " If you don't see it in your inbox, check your spam folder." : ''}',
                          textAlign: TextAlign.center,
                          style: muted,
                        ),
                      ),
                      Center(
                        child: OtpInput(
                          value: state.otp,
                          onChanged: cubit.otpChanged,
                          enabled: !state.isLoading,
                          invalid: state.isInvalidOtp,
                        ),
                      ),
                      if (state.errorMessage.isNotEmpty)
                        AuthFormMessage(
                          lines: <String>[state.errorMessage],
                          identifier: 'auth.verify.error',
                          center: true,
                        ),
                    ],
                  ),
                  AuthSubmitButton(
                    label: 'Verify Email',
                    loadingLabel: 'Verifying…',
                    identifier: 'auth.verify.submit',
                    loading: state.isLoading,
                    enabled: state.isOtpComplete,
                    onPressed: cubit.verifyCode,
                  ),
                  if (state.hasEmailService)
                    Semantics(
                      container: true,
                      identifier: 'auth.verify.resend',
                      child: Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            const TextSpan(text: "Didn't receive a code? "),
                            if (state.countdown > 0)
                              TextSpan(
                                children: <InlineSpan>[
                                  const TextSpan(text: 'Resend in '),
                                  TextSpan(
                                    text: '${state.countdown}s',
                                    style: TextStyle(color: c.textPrimary),
                                  ),
                                ],
                              )
                            else
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: AuthTextLink(
                                  label: 'Resend',
                                  identifier: 'auth.verify.resendLink',
                                  style: sim.text.sm,
                                  enabled: !state.isLoading,
                                  onPressed: cubit.resend,
                                ),
                              ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: muted,
                      ),
                    ),
                  AuthNavPrompt(
                    href: '/signup',
                    linkLabel: 'Back to signup',
                    identifier: 'auth.verify.backPrompt',
                    linkIdentifier: 'auth.verify.backLink',
                    onPressed: cubit.backToSignup,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// `verify/loading.tsx`: the route skeleton.
class VerifyLoadingSkeleton extends StatelessWidget {
  const VerifyLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const AuthLoadingFrame(
    identifier: 'auth.verify.loading',
    children: <Widget>[
      AuthLoadingSkeleton(shape: AuthSkeletonShape.title, width: 180),
      AuthLoadingSkeleton(
        shape: AuthSkeletonShape.label,
        width: 300,
        marginTop: 12,
      ),
      AuthLoadingSkeleton(
        shape: AuthSkeletonShape.label,
        width: 240,
        marginTop: 4,
      ),
      AuthLoadingSkeleton(shape: AuthSkeletonShape.control, marginTop: 32),
    ],
  );
}
