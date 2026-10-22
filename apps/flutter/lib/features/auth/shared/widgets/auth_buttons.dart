import 'package:flutter/widgets.dart';
import 'package:sim_app/features/auth/shared/brand_icons.dart';
import 'package:sim_app/features/auth/shared/widgets/auth_field.dart';
import 'package:sim_design/sim_design.dart';

/// Chrome of a 36px auth chip (`Chip` + `AUTH_BUTTON_CLASS`).
enum AuthChipStyle {
  /// `variant='primary'`: `--text-primary` fill, `--text-inverse` label.
  primary,

  /// Default chip + `border border-[var(--border)]` (social buttons, invite
  /// secondary actions).
  bordered,

  /// Default chip + `border border-[var(--border-1)]` (SSO outline; the same
  /// colour as [bordered] since `--border-1` aliases `--border`).
  outline,

  /// `variant='border'`: transparent with the shadow ring (Deny).
  ring,
}

/// A full-width 36px chip: the primary submit, the social buttons, the SSO
/// chip and the invite actions all share it. Label centred (icon + label
/// cluster centred, 6px gap); loading swaps in a 16px spinner and the loading
/// label on an 8px gap; disabled at 60% opacity.
class AuthChipButton extends StatelessWidget {
  const AuthChipButton({
    required this.label,
    required this.identifier,
    super.key,
    this.onPressed,
    this.style = AuthChipStyle.bordered,
    this.leading,
    this.loading = false,
    this.loadingLabel,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final String identifier;
  final VoidCallback? onPressed;
  final AuthChipStyle style;
  final Widget? leading;
  final bool loading;
  final String? loadingLabel;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final interactive = enabled && !loading;
    return Semantics(
      container: true,
      identifier: identifier,
      child: SimPressable(
        onPressed: onPressed,
        enabled: interactive,
        focusNode: focusNode,
        autofocus: autofocus,
        semanticsLabel: loading ? (loadingLabel ?? label) : label,
        builder: (context, state) {
          final paint = resolveChipPaint(
            c,
            variant: switch (style) {
              AuthChipStyle.primary => SimChipVariant.primary,
              AuthChipStyle.bordered ||
              AuthChipStyle.outline => SimChipVariant.base,
              AuthChipStyle.ring => SimChipVariant.border,
            },
            hovered: state.hovered,
            focused: state.focused,
            triggerBorder:
                style == AuthChipStyle.bordered ||
                style == AuthChipStyle.outline,
          );
          final labelStyle = sim.text.sm.copyWith(color: paint.text);
          return Opacity(
            opacity: interactive ? 1 : SimChipChrome.disabledOpacity,
            child: AnimatedContainer(
              duration: SimMotion.of(SimMotion.colors),
              height: authControlHeight,
              padding: const EdgeInsets.symmetric(
                horizontal: SimChipChrome.paddingX,
              ),
              decoration: BoxDecoration(
                color: paint.fill,
                border: paint.border,
                borderRadius: BorderRadius.circular(SimChipChrome.radius),
                boxShadow: paint.shadows,
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: paint.icon,
                  size: SimChipChrome.contentIconSize,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: loading ? 8 : SimChipChrome.gap,
                  children: <Widget>[
                    if (loading)
                      SimSpinner(
                        size: SimChipChrome.contentIconSize,
                        color: paint.text,
                      )
                    else
                      ?leading,
                    Flexible(
                      child: Text(
                        loading ? (loadingLabel ?? label) : label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: labelStyle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Port of `auth-submit-button.tsx`: the full-width primary action with the
/// shared in-flight spinner.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    required this.label,
    required this.loadingLabel,
    required this.identifier,
    super.key,
    this.onPressed,
    this.loading = false,
    this.enabled = true,
    this.focusNode,
  });

  final String label;
  final String loadingLabel;
  final String identifier;
  final VoidCallback? onPressed;
  final bool loading;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => AuthChipButton(
    label: label,
    loadingLabel: loadingLabel,
    identifier: identifier,
    onPressed: onPressed,
    loading: loading,
    enabled: enabled,
    style: AuthChipStyle.primary,
    focusNode: focusNode,
  );
}

/// `SocialSignInProvider` order: Google, Microsoft, GitHub.
enum SocialProvider { google, microsoft, github }

extension SocialProviderLabel on SocialProvider {
  String get label => switch (this) {
    SocialProvider.google => 'Google',
    SocialProvider.microsoft => 'Microsoft',
    SocialProvider.github => 'GitHub',
  };

  /// The `provider` value of `POST /api/auth/sign-in/social`.
  String get id => name;
}

/// Port of `social-login-buttons.tsx`: the available providers in fixed order
/// as bordered chips with 16px brand icons on a 12px gap; the one in flight
/// reads "Connecting…" and all three disable meanwhile. [trailing] renders
/// after the providers inside the same grid (the SSO chip).
class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({
    required this.identifier,
    required this.onPressed,
    super.key,
    this.googleAvailable = false,
    this.microsoftAvailable = false,
    this.githubAvailable = false,
    this.inFlight,
    this.trailing,
  });

  final String identifier;
  final ValueChanged<SocialProvider> onPressed;
  final bool googleAvailable;
  final bool microsoftAvailable;
  final bool githubAvailable;
  final SocialProvider? inFlight;
  final Widget? trailing;

  bool _available(SocialProvider provider) => switch (provider) {
    SocialProvider.google => googleAvailable,
    SocialProvider.microsoft => microsoftAvailable,
    SocialProvider.github => githubAvailable,
  };

  @override
  Widget build(BuildContext context) {
    final providers = SocialProvider.values.where(_available).toList();
    if (providers.isEmpty && trailing == null) return const SizedBox.shrink();
    return Semantics(
      container: true,
      identifier: '$identifier.social',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: <Widget>[
          for (final provider in providers)
            AuthChipButton(
              identifier: '$identifier.social.${provider.id}',
              label: inFlight == provider ? 'Connecting…' : provider.label,
              enabled: inFlight == null,
              onPressed: () => onPressed(provider),
              leading: switch (provider) {
                SocialProvider.google => const GoogleIcon(),
                SocialProvider.microsoft => const MicrosoftIcon(),
                SocialProvider.github => const GithubIcon(),
              },
            ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Port of `sso-login-button.tsx`: "Sign in with SSO" as a primary chip (the
/// SSO-only layout) or an outline chip inside the social grid.
class SsoLoginButton extends StatelessWidget {
  const SsoLoginButton({
    required this.identifier,
    required this.onPressed,
    super.key,
    this.primary = false,
  });

  final String identifier;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) => AuthChipButton(
    identifier: identifier,
    label: 'Sign in with SSO',
    style: primary ? AuthChipStyle.primary : AuthChipStyle.outline,
    onPressed: onPressed,
  );
}
