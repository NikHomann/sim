import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_app/features/auth/shared/auth_scope.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_bits.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_buttons.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_field.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_header.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_shell.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_skeleton.dart';
import 'package:sim_app/features/auth/signup/signup_cubit.dart';
import 'package:sim_app/features/auth/signup/signup_state.dart';

/// `/signup` (`auth-signup.md`).
class SignupPage extends StatefulWidget {
  const SignupPage({required this.query, super.key});

  final Map<String, String> query;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  SignupCubit? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final deps = AuthScope.of(context);
    _cubit = SignupCubit(
      api: deps.api,
      navigator: deps.navigator,
      sessionStore: deps.sessionStore,
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
  Widget build(BuildContext context) => BlocProvider<SignupCubit>.value(
    value: _cubit!,
    child: const SignupView(),
  );
}

/// The signup column under the auth shell; expects a [SignupCubit] above.
class SignupView extends StatefulWidget {
  const SignupView({super.key});

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final TextEditingController _name = TextEditingController();
  late final TextEditingController _email;
  final TextEditingController _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(
      text: context.read<SignupCubit>().state.email,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignupCubit>();
    return AuthShell(
      onHome: cubit.goHome,
      child: BlocBuilder<SignupCubit, SignupState>(
        builder: (context, state) {
          if (state.loading) return const SignupLoadingSkeleton();
          if (state.options.registrationDisabled) {
            return _RegistrationDisabled(href: cubit.loginHref);
          }
          return _SignupColumn(
            state: state,
            name: _name,
            email: _email,
            password: _password,
          );
        },
      ),
    );
  }
}

/// `registration-disabled.tsx`.
class _RegistrationDisabled extends StatelessWidget {
  const _RegistrationDisabled({required this.href});

  final String href;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignupCubit>();
    return Semantics(
      container: true,
      identifier: 'auth.signup.disabled',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 24,
        children: <Widget>[
          const AuthHeader(
            title: 'Account creation is disabled',
            description: 'Ask your admin to create an account for you.',
            identifier: 'auth.signup.disabled',
          ),
          AuthNavPrompt(
            prompt: 'Already have an account?',
            href: href,
            linkLabel: 'Sign in',
            identifier: 'auth.signup.disabled.loginPrompt',
            linkIdentifier: 'auth.signup.disabled.loginLink',
            onPressed: cubit.goToLogin,
          ),
        ],
      ),
    );
  }
}

class _SignupColumn extends StatelessWidget {
  const _SignupColumn({
    required this.state,
    required this.name,
    required this.email,
    required this.password,
  });

  final SignupState state;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController password;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignupCubit>();
    final options = state.options;
    return Semantics(
      container: true,
      identifier: 'auth.signup.root',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 24,
        children: <Widget>[
          const AuthHeader(
            title: 'Create an account',
            description: 'Create an account or log in',
            identifier: 'auth.signup',
          ),
          if (options.hasOnlySso)
            SsoLoginButton(
              identifier: 'auth.signup.ssoTop',
              primary: true,
              onPressed: cubit.openSso,
            ),
          if (options.emailEnabled)
            Semantics(
              container: true,
              identifier: 'auth.signup.form',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 24,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 20,
                    children: <Widget>[
                      AuthField(
                        label: 'Full name',
                        identifier: 'auth.signup.name',
                        errors: state.visibleNameErrors,
                        child: AuthInput(
                          controller: name,
                          identifier: 'auth.signup.name',
                          placeholder: 'Enter your name',
                          textCapitalization: TextCapitalization.words,
                          tooltip:
                              'Name can only contain letters, spaces, hyphens, and apostrophes',
                          error: state.visibleNameErrors.isNotEmpty,
                          onChanged: cubit.nameChanged,
                          onSubmit: cubit.submit,
                        ),
                      ),
                      AuthField(
                        label: 'Email',
                        identifier: 'auth.signup.email',
                        errors: state.visibleEmailErrors,
                        child: AuthInput(
                          controller: email,
                          identifier: 'auth.signup.email',
                          placeholder: 'Enter your email',
                          keyboardType: TextInputType.emailAddress,
                          error: state.emailHasError,
                          onChanged: cubit.emailChanged,
                          onSubmit: cubit.submit,
                        ),
                      ),
                      AuthField(
                        label: 'Password',
                        identifier: 'auth.signup.password',
                        errors: state.visiblePasswordErrors,
                        child: PasswordInput(
                          controller: password,
                          identifier: 'auth.signup.password',
                          placeholder: 'Enter your password',
                          error: state.visiblePasswordErrors.isNotEmpty,
                          onChanged: cubit.passwordChanged,
                          onSubmit: cubit.submit,
                        ),
                      ),
                    ],
                  ),
                  // Turnstile mounts here when a site key is configured
                  // (hosted only); with `appearance: 'execute'` it has no box
                  // until a challenge is demanded, so nothing renders.
                  if (options.turnstileSiteKey != null)
                    Semantics(
                      container: true,
                      identifier: 'auth.signup.turnstile',
                      child: const SizedBox.shrink(),
                    ),
                  if (state.formError != null)
                    AuthFormMessage(
                      lines: <String>[state.formError!],
                      identifier: 'auth.signup.formError',
                    ),
                  AuthSubmitButton(
                    label: 'Create account',
                    loadingLabel: 'Creating account…',
                    identifier: 'auth.signup.submit',
                    loading: state.submitting,
                    enabled: state.canSubmit,
                    onPressed: cubit.submit,
                  ),
                ],
              ),
            ),
          if (options.showDivider)
            const AuthDivider(
              label: 'Or continue with',
              identifier: 'auth.signup.divider',
            ),
          if (options.showBottomSection)
            SocialLoginButtons(
              identifier: 'auth.signup',
              googleAvailable: options.googleAvailable,
              microsoftAvailable: options.microsoftAvailable,
              githubAvailable: options.githubAvailable,
              inFlight: state.socialInFlight,
              onPressed: cubit.startSocial,
              trailing: options.ssoEnabled && !options.hasOnlySso
                  ? SsoLoginButton(
                      identifier: 'auth.signup.sso',
                      onPressed: cubit.openSso,
                    )
                  : null,
            ),
          AuthNavPrompt(
            prompt: 'Already have an account?',
            href: cubit.loginHref,
            linkLabel: 'Sign in',
            identifier: 'auth.signup.loginPrompt',
            linkIdentifier: 'auth.signup.loginLink',
            onPressed: cubit.goToLogin,
          ),
          AuthLegalFooter(
            action: 'creating an account',
            identifier: 'auth.signup.legal',
            onOpen: cubit.openLegal,
          ),
        ],
      ),
    );
  }
}

/// `signup/loading.tsx`: the route skeleton.
class SignupLoadingSkeleton extends StatelessWidget {
  const SignupLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const AuthLoadingFrame(
    identifier: 'auth.signup.loading',
    children: <Widget>[
      AuthLoadingSkeleton(shape: AuthSkeletonShape.title, width: 100),
      AuthLoadingField(labelWidth: 40, marginTop: 32),
      AuthLoadingField(labelWidth: 40, marginTop: 16),
      AuthLoadingField(labelWidth: 64, marginTop: 16),
      AuthLoadingSkeleton(shape: AuthSkeletonShape.control, marginTop: 24),
      AuthLoadingAlternateActions(),
      AuthLoadingSkeleton(
        shape: AuthSkeletonShape.label,
        width: 220,
        marginTop: 24,
      ),
    ],
  );
}
