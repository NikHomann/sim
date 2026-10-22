// Failure modes of UploadSession / UploadSessionClient:
// 1. a `put` transfer sends the whole file once with exactly the signed
//    headers; a `multipart` transfer sends one PUT per part with at most 3
//    in flight;
// 2. a transient part failure (5xx) is retried and then succeeds;
// 3. a non-transient failure (403, e.g. an expired signed URL) aborts the
//    session and is rethrown without completing;
// 4. exhausted retries abort and rethrow;
// 5. a create-only conflict (409/412) on a retried PUT counts as uploaded;
// 6. a part count that does not match the file size aborts before any PUT;
// 7. a part-URL batch missing a part aborts;
// 8. cancelling mid-upload aborts and raises ApiCancelledError;
// 9. progress ends at 100 % and never goes backwards;
// 10. a failing `complete` (409) propagates without a second abort, and a
//     missing upload-token (401) propagates from the control plane;
// 11. the control-plane calls carry the `upload-token` header and the
//     create response is decoded into a transfer.

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

import 'support/fake_server.dart';

class RecordedPut {
  RecordedPut(this.url, this.headers, this.bytes);

  final String url;
  final Map<String, String> headers;
  final Uint8List bytes;
}

class FakeTransport implements UploadTransport {
  final List<RecordedPut> puts = [];
  final List<int> statuses = [];
  int inFlight = 0;
  int maxInFlight = 0;
  Completer<void>? gate;

  @override
  Future<UploadPutResult> put({
    required String url,
    required Map<String, String> headers,
    required Uint8List bytes,
    required Duration timeout,
    CancelToken? cancelToken,
    void Function(int sent)? onProgress,
  }) async {
    inFlight += 1;
    maxInFlight = max(maxInFlight, inFlight);
    try {
      final pending = gate?.future;
      if (pending != null) await pending;
      if (cancelToken?.isCancelled ?? false) {
        throw const ApiCancelledError('aborted');
      }
      puts.add(RecordedPut(url, headers, bytes));
      onProgress?.call(bytes.length ~/ 2);
      onProgress?.call(bytes.length);
      final status = statuses.isEmpty ? 200 : statuses.removeAt(0);
      return UploadPutResult(status: status);
    } finally {
      inFlight -= 1;
    }
  }
}

void main() {
  final bytes = Uint8List.fromList(List.generate(10, (i) => i));
  late FakeTransport transport;
  late List<String> calls;

  setUp(() {
    transport = FakeTransport();
    calls = [];
  });

  UploadSession<String> session(
    UploadTransfer transfer, {
    Future<List<UploadPartUrl>> Function(List<int>)? getPartUrls,
    Future<String> Function()? complete,
    CancelToken? cancelToken,
  }) => UploadSession<String>(
    source: BytesUploadSource(name: 'f.bin', bytes: bytes),
    transfer: transfer,
    transport: transport,
    cancelToken: cancelToken,
    delay: (_) async {},
    random: Random(1),
    getPartUrls:
        getPartUrls ??
        (numbers) async => [
          for (final n in numbers)
            UploadPartUrl(
              partNumber: n,
              url: 'https://s3/part/$n',
              headers: {'p': '$n'},
            ),
        ],
    complete:
        complete ??
        () async {
          calls.add('complete');
          return 'done';
        },
    abort: () async => calls.add('abort'),
  );

  const put = PutUploadTransfer(
    url: 'https://s3/put',
    headers: {'x-amz-meta': '1'},
  );
  const multipart = MultipartUploadTransfer(partSize: 4, partCount: 3);

  test(
    'put sends once with the signed headers; multipart one PUT per part, 3 in flight',
    () async {
      expect(await session(put).run(), 'done');
      expect(transport.puts.single.url, 'https://s3/put');
      expect(transport.puts.single.headers, {'x-amz-meta': '1'});
      expect(transport.puts.single.bytes, bytes);
      expect(calls, ['complete']);

      transport = FakeTransport()..gate = Completer<void>();
      final run = session(multipart).run();
      await Future<void>.delayed(Duration.zero);
      expect(transport.inFlight, 3);
      transport.gate!.complete();
      await run;
      expect(transport.maxInFlight, 3);
      expect(transport.puts.map((p) => p.url), [
        'https://s3/part/1',
        'https://s3/part/2',
        'https://s3/part/3',
      ]);
      expect(transport.puts.map((p) => p.bytes.length), [4, 4, 2]);
      expect(transport.puts.last.headers, {'p': '3'});
    },
  );

  test('a transient part failure is retried', () async {
    transport.statuses.addAll([503, 200, 200, 200]);
    expect(await session(multipart).run(), 'done');
    expect(transport.puts, hasLength(4));
    expect(calls, ['complete']);
  });

  test('a non-transient failure aborts without completing', () async {
    transport.statuses.add(403);
    await expectLater(
      session(put).run(),
      throwsA(
        isA<UploadSessionTransportError>().having(
          (e) => e.status,
          'status',
          403,
        ),
      ),
    );
    expect(transport.puts, hasLength(1));
    expect(calls, ['abort']);
  });

  test('exhausted retries abort', () async {
    transport.statuses.addAll([500, 500, 500, 500, 500]);
    await expectLater(
      session(put).run(),
      throwsA(isA<UploadSessionTransportError>()),
    );
    expect(transport.puts, hasLength(4));
    expect(calls, ['abort']);
  });

  test('a create-only conflict on a retried PUT counts as uploaded', () async {
    transport.statuses.addAll([500, 412]);
    expect(await session(put).run(), 'done');
    expect(calls, ['complete']);
    transport = FakeTransport()..statuses.add(409);
    await expectLater(
      session(put).run(),
      throwsA(isA<UploadSessionTransportError>()),
    );
  });

  test('a part count mismatch aborts before any PUT', () async {
    await expectLater(
      session(const MultipartUploadTransfer(partSize: 4, partCount: 2)).run(),
      throwsA(isA<UploadSessionMismatchError>()),
    );
    expect(transport.puts, isEmpty);
    expect(calls, ['abort']);
  });

  test('a part-URL batch missing a part aborts', () async {
    await expectLater(
      session(
        multipart,
        getPartUrls: (numbers) async => [
          for (final n in numbers.skip(1))
            UploadPartUrl(partNumber: n, url: 'u$n', headers: {}),
        ],
      ).run(),
      throwsA(isA<UploadSessionMismatchError>()),
    );
    expect(calls, ['abort']);
  });

  test('cancelling mid-upload aborts and raises ApiCancelledError', () async {
    transport.gate = Completer<void>();
    final token = CancelToken();
    final run = session(multipart, cancelToken: token).run();
    await Future<void>.delayed(Duration.zero);
    token.cancel();
    transport.gate!.complete();
    await expectLater(run, throwsA(isA<ApiCancelledError>()));
    expect(calls, ['abort']);
  });

  test('progress ends at 100 and never goes backwards', () async {
    final upload = session(multipart);
    final percents = <int>[];
    upload.progress.listen((p) => percents.add(p.percent));
    await upload.run();
    expect(percents.last, 100);
    for (var i = 1; i < percents.length; i++) {
      expect(percents[i], greaterThanOrEqualTo(percents[i - 1]));
    }
  });

  test('a failing complete propagates without a second abort', () async {
    await expectLater(
      session(
        put,
        complete: () async => throw ApiClientError(
          status: 409,
          message: 'Upload already completed',
        ),
      ).run(),
      throwsA(isA<ApiClientError>().having((e) => e.status, 'status', 409)),
    );
    expect(calls, isEmpty);
  });

  group('control plane', () {
    late FakeServer server;
    late UploadSessionClient client;

    setUp(() async {
      server = await FakeServer.start();
      client = UploadSessionClient(
        SimHttpClient(baseUrl: server.url),
        transport: transport,
      );
    });

    tearDown(() => server.close());

    test('calls carry upload-token and the create response decodes', () async {
      server.handler = (request, body) async {
        switch (request.uri.path) {
          case '/api/files/uploads':
            await FakeServer.json(request, 200, {
              'data': {
                'session': {'id': 'up1', 'status': 'uploading'},
                'uploadToken': 'tok',
                'transfer': {
                  'method': 'multipart',
                  'partSize': 4,
                  'partCount': 3,
                },
              },
            });
          case '/api/files/uploads/up1/parts':
            final numbers = (request.uri.path, body);
            expect(numbers.$2, contains('partNumbers'));
            await FakeServer.json(request, 200, {
              'data': {
                'parts': [
                  for (final n in [1, 2, 3])
                    {
                      'partNumber': n,
                      'url': 'https://s3/$n',
                      'headers': <String, String>{},
                    },
                ],
              },
            });
          case '/api/files/uploads/up1/complete':
            await FakeServer.json(request, 200, {
              'data': {'id': 'up1', 'status': 'completed'},
            });
          default:
            await FakeServer.json(request, 404, {'error': 'nope'});
        }
      };
      final result = await client.upload(
        body: {
          'purpose': 'workspace_file',
          'name': 'f.bin',
          'contentType': 'x',
          'size': 10,
        },
        source: BytesUploadSource(name: 'f.bin', bytes: bytes),
      );
      expect(result['status'], 'completed');
      final parts = server.requests.firstWhere(
        (r) => r.path.endsWith('/parts'),
      );
      expect(parts.headers['upload-token'], 'tok');
      final complete = server.requests.last;
      expect(complete.headers['upload-token'], 'tok');
      expect(transport.puts, hasLength(3));
    });

    test(
      'a missing upload-token (401) from the control plane propagates and aborts',
      () async {
        server.handler = (request, body) async {
          switch (request.uri.path) {
            case '/api/files/uploads':
              await FakeServer.json(request, 200, {
                'data': {
                  'session': {'id': 'up1'},
                  'uploadToken': 'tok',
                  'transfer': {
                    'method': 'multipart',
                    'partSize': 4,
                    'partCount': 3,
                  },
                },
              });
            case '/api/files/uploads/up1/parts':
              await FakeServer.json(request, 401, {
                'error': 'upload-token header is required',
              });
            default:
              await FakeServer.json(request, 200, {
                'data': <String, Object?>{},
              });
          }
        };
        await expectLater(
          client.upload(
            body: {'purpose': 'workspace_file'},
            source: BytesUploadSource(name: 'f.bin', bytes: bytes),
          ),
          throwsA(isA<ApiClientError>().having((e) => e.status, 'status', 401)),
        );
        expect(server.requests.last.method, 'DELETE');
        expect(server.requests.last.path, '/api/files/uploads/up1');
      },
    );
  });
}
