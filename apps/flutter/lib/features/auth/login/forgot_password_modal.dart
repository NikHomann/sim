import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sim_app/features/auth/login/login_cubit.dart';
import 'package:sim_app/features/auth/login/login_state.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_shell.dart';
import 'package:sim_design/sim_design.dart';

/// Opens and closes the forgot-password `ChipModal` as the cubit's
/// `forgot.open` flag changes, so Escape, the overlay, X and Cancel all end
/// in the same state as the 2s success auto-close.
///
/// The layer is built on [SimOverlayEntry] directly (overlay `bg-black/10`
/// blurred 2px, centred `md` surface, initial focus in the first input)
/// rather than `openSimModal`, whose barrier does not survive its own
/// `Opacity` wrapper.
class ForgotPasswordModalHost extends StatefulWidget {
  const ForgotPasswordModalHost({required this.child, super.key});

  final Widget child;

  @override
  State<ForgotPasswordModalHost> createState() =>
      _ForgotPasswordModalHostState();
}

class _ForgotPasswordModalHostState extends State<ForgotPasswordModalHost> {
  SimOverlayEntry? _entry;

  void _open(LoginCubit cubit) {
    final overlay = SimOverlay.of(context);
    final registry = SimModalRegistry();
    late final SimOverlayEntry entry;
    void close() {
      if (_entry == entry) _entry = null;
      entry.remove();
      if (!cubit.isClosed) cubit.closeForgot();
    }

    entry = SimOverlayEntry(
      z: SimZ.modal,
      modal: true,
      onDismissRequested: close,
      builder: (context) => _ForgotModalLayer(
        contentKey: entry.contentKey,
        registry: registry,
        close: close,
        child: BlocProvider<LoginCubit>.value(
          value: cubit,
          child: const ForgotPasswordModal(),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  void _close() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocListener<LoginCubit, LoginState>(
    listenWhen: (previous, current) =>
        previous.forgot.open != current.forgot.open,
    listener: (context, state) {
      if (state.forgot.open) {
        _open(context.read<LoginCubit>());
      } else {
        _close();
      }
    },
    child: widget.child,
  );
}

/// `ChipModal size='md'`: overlay black/10 + 2px blur, content `w-[90vw]
/// max-w-[500px] max-h-[84vh]` centred, on the chip-modal surface.
class _ForgotModalLayer extends StatelessWidget {
  const _ForgotModalLayer({
    required this.contentKey,
    required this.registry,
    required this.close,
    required this.child,
  });

  final GlobalKey contentKey;
  final SimModalRegistry registry;
  final VoidCallback close;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final fraction = viewport.width * SimLayout.modalWidthFraction;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: AbsorbPointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: SimLayout.modalOverlayBlur,
                sigmaY: SimLayout.modalOverlayBlur,
              ),
              child: const ColoredBox(color: Color(0x1A000000)),
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: fraction < SimLayout.modalMd
                  ? fraction
                  : SimLayout.modalMd,
              maxHeight: viewport.height * SimLayout.modalMaxHeightFraction,
            ),
            child: KeyedSubtree(
              key: contentKey,
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                label: 'Reset Password',
                explicitChildNodes: true,
                child: SimModalScope(
                  close: ([result]) => close(),
                  dismissDisabled: false,
                  registry: registry,
                  // Text fields need an Overlay (selection toolbar) and an
                  // Escape action; the layer sits outside the Navigator.
                  child: Overlay.wrap(
                    child: Actions(
                      actions: <Type, Action<Intent>>{
                        DismissIntent: CallbackAction<DismissIntent>(
                          onInvoke: (_) {
                            close();
                            return null;
                          },
                        ),
                      },
                      child: AuthLightTheme(
                        child: SimChipModalSurface(child: child),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The modal body (`login-form.tsx:467-504`): description, the email field,
/// the success line / error, and the Cancel / Send Reset Link footer.
class ForgotPasswordModal extends StatefulWidget {
  const ForgotPasswordModal({super.key});

  @override
  State<ForgotPasswordModal> createState() => _ForgotPasswordModalState();
}

class _ForgotPasswordModalState extends State<ForgotPasswordModal> {
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(
      text: context.read<LoginCubit>().state.forgot.email,
    );
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoginCubit>();
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return BlocBuilder<LoginCubit, LoginState>(
      buildWhen: (previous, current) => previous.forgot != current.forgot,
      builder: (context, state) {
        final forgot = state.forgot;
        return Semantics(
          container: true,
          identifier: 'auth.login.forgotModal',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                container: true,
                identifier: 'auth.login.forgotModal.header',
                child: SimChipModalHeader(
                  title: 'Reset Password',
                  onClose: cubit.closeForgot,
                ),
              ),
              SimChipModalBody(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      "Enter your email address and we'll send you a link to "
                      'reset your password if your account exists.',
                      style: sim.text.sm.copyWith(color: c.textSecondary),
                    ),
                  ),
                  Semantics(
                    container: true,
                    identifier: 'auth.login.forgotModal.email',
                    child: SimChipModalField.input(
                      title: 'Email',
                      controller: _email,
                      placeholder: 'you@example.com',
                      required: true,
                      email: true,
                      enabled: !forgot.submitting,
                      onChanged: cubit.forgotEmailChanged,
                    ),
                  ),
                  if (forgot.statusType == ForgotStatusType.success)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        forgot.message,
                        style: sim.text.sm.copyWith(color: c.textSecondary),
                      ),
                    ),
                  Semantics(
                    container: true,
                    identifier: 'auth.login.forgotModal.error',
                    child: SimChipModalError(
                      forgot.statusType == ForgotStatusType.error
                          ? forgot.message
                          : null,
                    ),
                  ),
                ],
              ),
              _ForgotFooter(
                submitting: forgot.submitting,
                canSend: forgot.canSend,
                onCancel: cubit.closeForgot,
                onSend: cubit.sendReset,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ForgotFooter extends StatelessWidget {
  const _ForgotFooter({
    required this.submitting,
    required this.canSend,
    required this.onCancel,
    required this.onSend,
  });

  final bool submitting;
  final bool canSend;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    SimChipModalScope.maybeOf(context)?.setPrimary(onSend, enabled: canSend);
    return Semantics(
      container: true,
      identifier: 'auth.login.forgotModal.footer',
      child: SimChipModalFooterShell(
        children: <Widget>[
          Semantics(
            container: true,
            identifier: 'auth.login.forgotModal.cancel',
            child: SimChip(
              label: 'Cancel',
              enabled: !submitting,
              onPressed: onCancel,
            ),
          ),
          Semantics(
            container: true,
            identifier: 'auth.login.forgotModal.submit',
            child: SimChip(
              label: submitting ? 'Sending…' : 'Send Reset Link',
              variant: SimChipVariant.primary,
              enabled: canSend,
              onPressed: onSend,
            ),
          ),
        ],
      ),
    );
  }
}
