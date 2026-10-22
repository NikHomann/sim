// Failure modes of the error-envelope mapping (ApiClientError.fromResponse):
// 1. an internal `{error, requestId}` body yields the message and request id;
// 2. a validation `{error, details:[{path,message}]}` body exposes the
//    issues with their paths, matched by suffix;
// 3. a v2 `{error:{code,message,details}}` body yields the nested code,
//    message and issues;
// 4. a Better Auth `{code, message}` body yields the code;
// 5. `message` wins over `error` when both are present;
// 6. a non-JSON body keeps the text and falls back to the status message;
// 7. a 429 with `Retry-After` in seconds and in HTTP-date form parses;
// 8. rate-limit headers are surfaced on any status;
// 9. 499 and 413 are recognised.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

void main() {
  test('internal envelope: message and requestId', () {
    final error = ApiClientError.fromResponse(
      status: 500,
      body: {'error': 'Internal server error', 'requestId': 'req-1'},
    );
    expect(error.message, 'Internal server error');
    expect(error.requestId, 'req-1');
    expect(error.code, isNull);
    expect(error.isValidationError, isFalse);
  });

  test('validation envelope: issues with paths matched by suffix', () {
    final error = ApiClientError.fromResponse(
      status: 400,
      body: {
        'error': 'Invalid request',
        'details': [
          {
            'path': ['updates', 'name'],
            'message': 'Name is required',
          },
          {'path': 'bad', 'message': 'dropped'},
          {'path': <Object>[], 'message': ''},
        ],
      },
    );
    expect(error.isValidationError, isTrue);
    expect(error.details, hasLength(1));
    expect(error.findIssue(['name'])?.message, 'Name is required');
    expect(error.findIssue(['updates', 'name']), isNotNull);
    expect(error.findIssue(['other']), isNull);
  });

  test('v2 envelope: nested code, message and details', () {
    final error = ApiClientError.fromResponse(
      status: 400,
      body: {
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Bad input',
          'details': [
            {
              'path': ['limit'],
              'message': 'too large',
            },
          ],
        },
      },
    );
    expect(error.code, 'VALIDATION_ERROR');
    expect(error.message, 'Bad input');
    expect(error.findIssue(['limit'])?.message, 'too large');
  });

  test('Better Auth envelope: top-level code', () {
    final error = ApiClientError.fromResponse(
      status: 403,
      body: {'code': 'EMAIL_NOT_VERIFIED', 'message': 'Email not verified'},
    );
    expect(error.code, 'EMAIL_NOT_VERIFIED');
    expect(error.message, 'Email not verified');
  });

  test('message wins over error', () {
    final error = ApiClientError.fromResponse(
      status: 400,
      body: {'error': 'from error', 'message': 'from message'},
    );
    expect(error.message, 'from message');
  });

  test('non-JSON body keeps the text and uses the status fallback', () {
    final error = ApiClientError.fromResponse(
      status: 401,
      body: 'Unauthorized',
      rawBody: 'Unauthorized',
    );
    expect(error.message, 'Request failed with 401');
    expect(error.body, 'Unauthorized');
    expect(error.rawBody, 'Unauthorized');
  });

  test('429 parses Retry-After in seconds and as an HTTP date', () {
    final seconds = ApiClientError.fromResponse(
      status: 429,
      body: {'error': 'Rate limited'},
      headers: {
        'retry-after': ['2'],
      },
    );
    expect(seconds.isRateLimited, isTrue);
    expect(seconds.retryAfter, const Duration(seconds: 2));

    final now = DateTime.utc(2026, 10, 21, 12);
    final dated = ApiClientError.fromResponse(
      status: 429,
      body: null,
      headers: {
        'Retry-After': ['Wed, 21 Oct 2026 12:00:05 GMT'],
      },
      now: () => now,
    );
    expect(dated.retryAfter, const Duration(seconds: 5));

    final garbage = ApiClientError.fromResponse(
      status: 429,
      body: null,
      headers: {
        'retry-after': ['soon'],
      },
    );
    expect(garbage.retryAfter, isNull);
  });

  test('rate-limit headers are surfaced', () {
    final error = ApiClientError.fromResponse(
      status: 200,
      body: null,
      headers: {
        'x-ratelimit-limit': ['30'],
        'x-ratelimit-remaining': ['0'],
        'x-ratelimit-reset': ['1760000000'],
      },
    );
    expect(error.rateLimit?.limit, 30);
    expect(error.rateLimit?.remaining, 0);
    expect(error.rateLimit?.reset, '1760000000');
    expect(error.rateLimit?.retryAfter, isNull);
  });

  test('499 and 413 are recognised', () {
    expect(
      ApiClientError.fromResponse(
        status: 499,
        body: null,
      ).isClientClosedRequest,
      isTrue,
    );
    expect(
      ApiClientError.fromResponse(status: 413, body: null).isPayloadTooLarge,
      isTrue,
    );
  });
}
