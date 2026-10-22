import 'package:flutter/widgets.dart';
import 'package:sim_design/sim_design.dart';

/// Port of `auth-text-link.tsx`: the inline text affordance —
/// `--text-secondary`, hover `--text-primary` + underline, disabled at 50%.
/// [mutedBase] is the SSO/support-footer treatment (`--text-muted` at rest);
/// [hoverBody] hovers to `--text-body` (support footer).
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({
    required this.label,
    required this.onPressed,
    super.key,
    this.identifier,
    this.style,
    this.isLink = false,
    this.enabled = true,
    this.mutedBase = false,
    this.hoverBody = false,
    this.restColor,
  });

  final String label;
  final VoidCallback onPressed;
  final String? identifier;

  /// Base style (size, line height); defaults to the ambient text style.
  final TextStyle? style;
  final bool isLink;
  final bool enabled;
  final bool mutedBase;
  final bool hoverBody;

  /// Overrides the rest colour (the SSO "Sign up" link is `--text-primary`).
  final Color? restColor;

  @override
  Widget build(BuildContext context) {
    final c = SimTheme.of(context).colors;
    final base = style ?? DefaultTextStyle.of(context).style;
    final rest = restColor ?? (mutedBase ? c.textMuted : c.textSecondary);
    final hover = hoverBody ? c.textBody : c.textPrimary;
    final link = SimPressable(
      onPressed: onPressed,
      enabled: enabled,
      isLink: isLink,
      semanticsLabel: label,
      hitTestBehavior: HitTestBehavior.translucent,
      builder: (context, state) => Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AnimatedDefaultTextStyle(
          duration: SimMotion.of(SimMotion.colors),
          style: base.copyWith(
            color: state.hovered && enabled ? hover : rest,
            decoration: state.hovered && enabled
                ? TextDecoration.underline
                : TextDecoration.none,
            decorationColor: hover,
          ),
          child: Text(label),
        ),
      ),
    );
    if (identifier == null) return link;
    return Semantics(container: true, identifier: identifier, child: link);
  }
}

/// Port of `auth-form-message.tsx`: form-level copy in `--text-error` or
/// `--brand-accent`, 12px lines on a 4px gap, left or centred.
class AuthFormMessage extends StatelessWidget {
  const AuthFormMessage({
    required this.lines,
    required this.identifier,
    super.key,
    this.error = true,
    this.center = false,
  });

  final List<String> lines;
  final String identifier;
  final bool error;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return Semantics(
      container: true,
      identifier: identifier,
      liveRegion: true,
      child: Column(
        crossAxisAlignment: center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.stretch,
        spacing: 4,
        children: <Widget>[
          for (final line in lines)
            Text(
              line,
              textAlign: center ? TextAlign.center : TextAlign.start,
              style: sim.text.caption.copyWith(
                color: error ? c.textError : c.brandAccent,
              ),
            ),
        ],
      ),
    );
  }
}

/// Port of `auth-divider.tsx`: a one-line box with the 1px `--border` rule
/// at mid-height and the 14px `--text-muted` label knocked out on `--bg`
/// with 16px side padding.
class AuthDivider extends StatelessWidget {
  const AuthDivider({required this.label, required this.identifier, super.key});

  final String label;
  final String identifier;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return Semantics(
      container: true,
      identifier: identifier,
      child: SizedBox(
        height: 20,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              top: 10,
              child: Container(height: 1, color: c.border),
            ),
            Container(
              color: c.bg,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                label,
                style: sim.text.sm.copyWith(color: c.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Port of `auth-nav-prompt.tsx`: optional 14px muted lead text and a 30px
/// bordered `ChipLink` on a 4px gap, centred.
class AuthNavPrompt extends StatelessWidget {
  const AuthNavPrompt({
    required this.href,
    required this.linkLabel,
    required this.identifier,
    required this.linkIdentifier,
    required this.onPressed,
    super.key,
    this.prompt,
  });

  final String href;
  final String linkLabel;

  /// Parity id of the row; [linkIdentifier] is the chip's.
  final String identifier;
  final String linkIdentifier;
  final VoidCallback onPressed;
  final String? prompt;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    return Semantics(
      container: true,
      identifier: identifier,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 4,
        children: <Widget>[
          if (prompt != null)
            Flexible(
              child: Text(
                prompt!,
                style: sim.text.sm.copyWith(color: c.textMuted),
              ),
            ),
          Semantics(
            container: true,
            identifier: linkIdentifier,
            value: href,
            child: SimChip(
              label: linkLabel,
              triggerBorder: true,
              isLink: true,
              onPressed: onPressed,
            ),
          ),
        ],
      ),
    );
  }
}

/// Port of `auth-legal-footer.tsx`: "By {action}, you agree to our Terms of
/// Service and Privacy Policy" at 12px / 19.5px in `--text-muted`, the links
/// opening in a new tab.
class AuthLegalFooter extends StatelessWidget {
  const AuthLegalFooter({
    required this.action,
    required this.identifier,
    required this.onOpen,
    super.key,
  });

  /// The gerund ("signing in", "creating an account").
  final String action;
  final String identifier;

  /// Opens `/terms` or `/privacy` in a new tab.
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final style = sim.text
        .style(12, height: 1.625)
        .copyWith(color: c.textMuted);
    final linkStyle = inlineContentStyle(style);
    return Semantics(
      container: true,
      identifier: identifier,
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(text: 'By $action, you agree to our '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: AuthTextLink(
                label: 'Terms of Service',
                identifier: '$identifier.terms',
                style: linkStyle,
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
                identifier: '$identifier.privacy',
                style: linkStyle,
                isLink: true,
                onPressed: () => onOpen('/privacy'),
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }
}

/// Port of `support-footer.tsx` (`position='static'`): "Need help? Contact
/// support" at 12px / 19.5px in `--text-muted` with 32px bottom padding.
class SupportFooter extends StatelessWidget {
  const SupportFooter({required this.onContact, super.key});

  /// Opens `mailto:<brandConfig.supportEmail>`.
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final sim = SimTheme.of(context);
    final c = sim.colors;
    final style = sim.text
        .style(12, height: 1.625)
        .copyWith(color: c.textMuted);
    return Semantics(
      container: true,
      identifier: 'auth.shell.supportFooter',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Text.rich(
          TextSpan(
            children: <InlineSpan>[
              const TextSpan(text: 'Need help? '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: AuthTextLink(
                  label: 'Contact support',
                  style: style,
                  isLink: true,
                  mutedBase: true,
                  hoverBody: true,
                  onPressed: onContact,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: style,
        ),
      ),
    );
  }
}

/// [style] without its line height: an inline `<a>` inside a paragraph is as
/// tall as the font's content area (12px Inter → 15px), not the paragraph's
/// `leading-relaxed` line, so a link in a [WidgetSpan] measures like the DOM
/// box the parity capture compares against.
TextStyle inlineContentStyle(TextStyle style) => TextStyle(
  color: style.color,
  fontFamily: style.fontFamily,
  fontFamilyFallback: style.fontFamilyFallback,
  fontSize: style.fontSize,
  fontWeight: style.fontWeight,
  fontVariations: style.fontVariations,
  letterSpacing: style.letterSpacing,
);
