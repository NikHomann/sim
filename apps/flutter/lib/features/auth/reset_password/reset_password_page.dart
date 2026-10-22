import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_app/features/auth/reset_password/reset_password_cubit.dart';
import 'package:sim_app/features/auth/shared/auth_scope.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_bits.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_buttons.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_field.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_header.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_shell.dart';

/// `/reset-password?token=…` (`auth-reset-password.md`).
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({required this.query, super.key});

  final Map<String, String> query;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  ResetPasswordCubit? _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit != null) return;
    final deps = AuthScope.of(context);
    _cubit = ResetPasswordCubit(
      api: deps.api,
      navigator: deps.navigator,
      timers: deps.timers,
      query: widget.query,
    );
  }

  @override
  void dispose() {
    unawaited(_cubit?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider<ResetPasswordCubit>.value(
    value: _cubit!,
    child: const ResetPasswordView(),
  );
}

/// The reset column under the auth shell; expects a [ResetPasswordCubit].
class ResetPasswordView extends StatefulWidget {
  const ResetPasswordView({super.key});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ResetPasswordCubit>();
    return AuthShell(
      onHome: cubit.goHome,
      child: BlocBuilder<ResetPasswordCubit, ResetPasswordState>(
        builder: (context, state) {
          final status = state.status;
          return Semantics(
            container: true,
            identifier: 'auth.reset.root',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 24,
              children: <Widget>[
                const AuthHeader(
                  title: 'Reset your password',
                  description: 'Enter a new password for your account',
                  identifier: 'auth.reset',
                ),
                Semantics(
                  container: true,
                  identifier: 'auth.reset.form',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 24,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 20,
                        children: <Widget>[
                          AuthField(
                            label: 'New Password',
                            identifier: 'auth.reset.password',
                            child: PasswordInput(
                              controller: _password,
                              identifier: 'auth.reset.password',
                              placeholder: 'Enter new password',
                              enabled: state.fieldsEnabled,
                              error: state.hasValidationErrors,
                              onChanged: cubit.passwordChanged,
                              onSubmit: cubit.submit,
                            ),
                          ),
                          AuthField(
                            label: 'Confirm Password',
                            identifier: 'auth.reset.confirm',
                            child: PasswordInput(
                              controller: _confirm,
                              identifier: 'auth.reset.confirm',
                              placeholder: 'Confirm new password',
                              enabled: state.fieldsEnabled,
                              error: state.hasValidationErrors,
                              onChanged: cubit.confirmChanged,
                              onSubmit: cubit.submit,
                            ),
                          ),
                          if (state.hasValidationErrors)
                            AuthFormMessage(
                              lines: state.validationMessages,
                              identifier: 'auth.reset.validation',
                            ),
                          if (status != null)
                            AuthFormMessage(
                              lines: <String>[status.text],
                              identifier: 'auth.reset.status',
                              error: status.type == ResetStatusType.error,
                            ),
                        ],
                      ),
                      AuthSubmitButton(
                        label: 'Reset Password',
                        loadingLabel: 'Resetting…',
                        identifier: 'auth.reset.submit',
                        loading: state.submitting,
                        enabled: state.canSubmit,
                        onPressed: cubit.submit,
                      ),
                    ],
                  ),
                ),
                AuthNavPrompt(
                  href: '/login',
                  linkLabel: 'Back to login',
                  identifier: 'auth.reset.backPrompt',
                  linkIdentifier: 'auth.reset.backLink',
                  onPressed: cubit.backToLogin,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
