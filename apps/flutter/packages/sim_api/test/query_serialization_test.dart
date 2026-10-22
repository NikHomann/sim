// Failure modes of the request serialisation (replacePathParams/appendQuery):
// 1. a missing required path param throws instead of leaving `[id]` in the URL;
// 2. a catch-all `[...path]` joins list items with `/`, each encoded;
// 3. an optional catch-all `[[...rest]]` without a value disappears;
// 4. null and empty query values are skipped entirely;
// 5. a scalar list repeats the key, skipping empty items;
// 6. a list containing objects is one JSON-string param (the tagFilters bug);
// 7. an object value is one JSON-string param;
// 8. booleans and numbers stringify; a path that already has `?` gets `&`;
// 9. encoding matches URLSearchParams: space -> `+`, `~` percent-encoded,
//    `*-._` untouched, UTF-8 percent-encoded.

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_api/sim_api.dart';

void main() {
  test('a missing required path param throws', () {
    expect(
      () => replacePathParams('/api/workflows/[id]', {'other': 'x'}),
      throwsA(isA<MissingRouteParamError>()),
    );
    expect(
      replacePathParams('/api/workflows/[id]/state', {'id': 'a b'}),
      '/api/workflows/a%20b/state',
    );
  });

  test('a catch-all joins list items with / and encodes each', () {
    expect(
      replacePathParams('/api/files/serve/[...path]', {
        'path': ['dir', 'a b.txt'],
      }),
      '/api/files/serve/dir/a%20b.txt',
    );
  });

  test('an optional catch-all without a value disappears', () {
    expect(replacePathParams('/api/x/[[...rest]]', {}), '/api/x/');
  });

  test('null and empty query values are skipped', () {
    expect(
      appendQuery('/api/logs', {'a': null, 'b': '', 'c': 'x'}),
      '/api/logs?c=x',
    );
    expect(appendQuery('/api/logs', {'a': null}), '/api/logs');
  });

  test('a scalar list repeats the key and skips empty items', () {
    expect(
      appendQuery('/p', {
        'ids': ['1', '', null, '2'],
      }),
      '/p?ids=1&ids=2',
    );
  });

  test('a list containing objects is one JSON-string param', () {
    expect(
      appendQuery('/p', {
        'sort': [
          {'field': 'name', 'dir': 'asc'},
        ],
      }),
      '/p?sort=%5B%7B%22field%22%3A%22name%22%2C%22dir%22%3A%22asc%22%7D%5D',
    );
  });

  test('an object value is one JSON-string param', () {
    expect(
      appendQuery('/p', {
        'filter': {'a': 1},
      }),
      '/p?filter=%7B%22a%22%3A1%7D',
    );
  });

  test('booleans and numbers stringify; existing ? gets &', () {
    expect(
      appendQuery('/p?x=1', {'includeTotal': true, 'limit': 100}),
      '/p?x=1&includeTotal=true&limit=100',
    );
  });

  test('encoding matches URLSearchParams', () {
    expect(
      encodeFormComponent('a b~c*d-e_f.g/h?i=j&k'),
      'a+b%7Ec*d-e_f.g%2Fh%3Fi%3Dj%26k',
    );
    expect(encodeFormComponent('é'), '%C3%A9');
  });
}
