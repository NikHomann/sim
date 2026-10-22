/// Port of `apps/sim/lib/messaging/email/validation.ts` (`quickValidateEmail`)
/// and `packages/utils/src/string.ts` (`normalizeEmail`, `isValidEmailSyntax`).
library;

/// Trims and lower-cases for comparison and storage.
String normalizeEmail(String email) => email.trim().toLowerCase();

final RegExp _emailSyntax = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
);

/// Format-only syntax check capped at 254 characters.
bool isValidEmailSyntax(String email) =>
    email.length <= 254 && _emailSyntax.hasMatch(email);

const Set<String> _disposableDomains = <String>{
  '10minutemail.com',
  '10minutemail.net',
  'catchmail.io',
  'dispostable.com',
  'emailondeck.com',
  'fakemailgenerator.com',
  'getnada.com',
  'guerrillamail.com',
  'guerrillamailblock.com',
  'mail.gw',
  'mailinator.com',
  'oakon.com',
  'pokemail.net',
  'salt.email',
  'sharebot.net',
  'sharklasers.com',
  'spam4.me',
  'temp-mail.org',
  'tempail.com',
  'tempmail.org',
  'tempr.email',
  'temporary-mail.net',
  'throwaway.email',
  'yopmail.com',
};

String? _domainOf(String email) {
  final at = email.indexOf('@');
  if (at < 0) return null;
  final domain = email.substring(at + 1);
  return domain.isEmpty ? null : domain.toLowerCase();
}

bool _hasInvalidPatterns(String email) {
  if (email.contains('..')) return true;
  final local = email.split('@').first;
  return local.length > 64;
}

/// `quickValidateEmail`: the reason the client shows, or `null` when valid.
String? quickValidateEmailReason(String email) {
  if (!isValidEmailSyntax(email)) return 'Invalid email format';
  final domain = _domainOf(email);
  if (domain == null) return 'Missing domain';
  if (_disposableDomains.contains(domain)) {
    return 'Disposable email addresses are not allowed';
  }
  if (_hasInvalidPatterns(email)) return 'Email contains suspicious patterns';
  final domainOk =
      domain.contains('.') && !domain.startsWith('.') && !domain.endsWith('.');
  if (!domainOk) return 'Invalid domain format';
  return null;
}

/// `validateEmailField` as the auth forms define it: required, then the
/// quick validation of the normalised value.
List<String> validateEmailField(String value) {
  if (value.trim().isEmpty) return const <String>['Email is required.'];
  final reason = quickValidateEmailReason(normalizeEmail(value));
  return reason == null ? const <String>[] : <String>[reason];
}
