import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_app/features/auth/login/forgot_password_modal.dart';
import 'package:sim_app/features/auth/login/login_cubit.dart';
import 'package:sim_app/features/auth/login/login_state.dart';
import 'package:sim_app/features/auth/shared/auth_scope.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_bits.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_buttons.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_field.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_header.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_shell.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_skeleton.dart';
import 'package:sim_design/sim_design.dart';

/// `/login` (`auth-login.md`).
class LoginPage extends StatefulWidget {
  const LoginPage({required this.query, super.key});

  final Map<String, String> query;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  LoginCubit? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final deps = AuthScope.of(context);
    _cubit = LoginCubit(
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
  Widget build(BuildContext context) => BlocProvider<LoginCubit>.value(
    value: _cubit!,
    child: const LoginView(),
  );
}

/// The login column under the auth shell; expects a [LoginCubit] above.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _emailFocus = FocusNode(debugLabel: 'login.email');
  final FocusNode _passwordFocus = FocusNode(debugLabel: 'login.password');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoginCubit>();
    return ForgotPasswordModalHost(
      child: AuthShell(
        onHome: cubit.goHome,
        child: BlocBuilder<LoginCubit, LoginState>(
          builder: (context, state) {
            if (state.loading) return const LoginLoadingSkeleton();
            return _LoginColumn(
              state: state,
              email: _email,
              password: _password,
              emailFocus: _emailFocus,
              passwordFocus: _passwordFocus,
            );
          },
        ),
      ),
    );
  }
}

class _LoginColumn extends StatelessWidget {
  const _LoginColumn({
    required this.state,
    required this.email,
    required this.password,
    required this.emailFocus,
    required this.passwordFocus,
  });

  final LoginState state;
  final TextEditingController email;
  final TextEditingController password;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoginCubit>();
    final sim = SimTheme.of(context);
    final options = state.options;
    return Semantics(
      container: true,
      identifier: 'auth.login.root',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 24,
        children: <Widget>[
          const AuthHeader(
            title: 'Sign in',
            description: 'Enter your details',
            identifier: 'auth.login',
          ),
          if (options.hasOnlySso)
            SsoLoginButton(
              identifier: 'auth.login.ssoTop',
              primary: true,
              onPressed: cubit.openSso,
            ),
          if (options.emailEnabled)
            Semantics(
              container: true,
              identifier: 'auth.login.form',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 24,
                children: <Widget>[
                  Semantics(
                    container: true,
                    identifier: 'auth.login.fields',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 20,
                      children: <Widget>[
                        AuthField(
                          label: 'Email',
                          identifier: 'auth.login.email',
                          errors: state.visibleEmailErrors,
                          child: AuthInput(
                            controller: email,
                            focusNode: emailFocus,
                            identifier: 'auth.login.email',
                            placeholder: 'Enter your email',
                            keyboardType: TextInputType.emailAddress,
                            error: state.visibleEmailErrors.isNotEmpty,
                            onChanged: cubit.emailChanged,
                            onSubmit: cubit.submit,
                          ),
                        ),
                        AuthField(
                          label: 'Password',
                          identifier: 'auth.login.password',
                          errors: state.visiblePasswordErrors,
                          action: AuthTextLink(
                            label: 'Forgot password?',
                            identifier: 'auth.login.forgot',
                            style: sim.text.caption,
                            onPressed: cubit.openForgot,
                          ),
                          child: PasswordInput(
                            controller: password,
                            focusNode: passwordFocus,
                            identifier: 'auth.login.password',
                            placeholder: 'Enter your password',
                            error: state.visiblePasswordErrors.isNotEmpty,
                            onChanged: cubit.passwordChanged,
                            onSubmit: cubit.submit,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.policyError != null)
                    AuthFormMessage(
                      lines: <String>[state.policyError!],
                      identifier: 'auth.login.policyError',
                    ),
                  if (state.resetSuccessMessage != null)
                    AuthFormMessage(
                      lines: <String>[state.resetSuccessMessage!],
                      identifier: 'auth.login.resetSuccess',
                      error: false,
                    ),
                  AuthSubmitButton(
                    label: 'Sign in',
                    loadingLabel: 'Signing in…',
                    identifier: 'auth.login.submit',
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
              identifier: 'auth.login.divider',
            ),
          if (options.showBottomSection)
            SocialLoginButtons(
              identifier: 'auth.login',
              googleAvailable: options.googleAvailable,
              microsoftAvailable: options.microsoftAvailable,
              githubAvailable: options.githubAvailable,
              inFlight: state.socialInFlight,
              onPressed: cubit.startSocial,
              trailing: options.ssoEnabled && !options.hasOnlySso
                  ? SsoLoginButton(
                      identifier: 'auth.login.sso',
                      onPressed: cubit.openSso,
                    )
                  : null,
            ),
          if (options.emailEnabled && !options.registrationDisabled)
            AuthNavPrompt(
              prompt: "Don't have an account?",
              href: cubit.signupHref,
              linkLabel: 'Sign up',
              identifier: 'auth.login.signupPrompt',
              linkIdentifier: 'auth.login.signupLink',
              onPressed: cubit.goToSignup,
            ),
          AuthLegalFooter(
            action: 'signing in',
            identifier: 'auth.login.legal',
            onOpen: cubit.openLegal,
          ),
        ],
      ),
    );
  }
}

/// `login/loading.tsx`: the route skeleton.
class LoginLoadingSkeleton extends StatelessWidget {
  const LoginLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const AuthLoadingFrame(
    identifier: 'auth.login.loading',
    children: <Widget>[
      AuthLoadingSkeleton(shape: AuthSkeletonShape.title, width: 80),
      AuthLoadingField(labelWidth: 40, marginTop: 32),
      AuthLoadingField(labelWidth: 64, marginTop: 16),
      AuthLoadingSkeleton(shape: AuthSkeletonShape.control, marginTop: 24),
      AuthLoadingAlternateActions(),
      AuthLoadingSkeleton(
        shape: AuthSkeletonShape.label,
        width: 200,
        marginTop: 24,
      ),
    ],
  );
}
