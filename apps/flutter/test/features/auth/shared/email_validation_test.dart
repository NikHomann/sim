// Failure modes:
// - a blank value is "required", not "invalid format"
// - syntax failures, a missing domain, a disposable domain, consecutive
//   dots / an over-long local part and a dotless domain each produce the
//   upstream reason, checked in the upstream order
// - the value is normalised (trimmed, lower-cased) before validation so
//   " Ada@Example.COM " passes
// - addresses over 254 characters fail the syntax gate
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_app/features/auth/shared/email_validation.dart';

void main() {
  test('required beats format', () {
    expect(validateEmailField(''), ['Email is required.']);
    expect(validateEmailField('   '), ['Email is required.']);
  });

  test('reasons in upstream order', () {
    expect(quickValidateEmailReason('nope'), 'Invalid email format');
    expect(
      quickValidateEmailReason('a@mailinator.com'),
      'Disposable email addresses are not allowed',
    );
    expect(
      quickValidateEmailReason('a..b@example.com'),
      'Email contains suspicious patterns',
    );
    expect(
      quickValidateEmailReason('${'a' * 65}@example.com'),
      'Email contains suspicious patterns',
    );
    expect(quickValidateEmailReason('a@localhost'), 'Invalid domain format');
    expect(quickValidateEmailReason('ada@example.com'), isNull);
  });

  test('normalises before validating', () {
    expect(validateEmailField(' Ada@Example.COM '), isEmpty);
    expect(normalizeEmail(' Ada@Example.COM '), 'ada@example.com');
  });

  test('length cap', () {
    expect(isValidEmailSyntax('${'a' * 250}@b.co'), isFalse);
    expect(isValidEmailSyntax('a@b.co'), isTrue);
  });
}
