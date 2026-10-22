# tools/gen

Dart generators for the Flutter port. Run from `apps/flutter`:

```sh
# Everything: generated/dart/*.g.dart, generated/icons_vec, and the suggestion catalog
dart run tools/gen/main.dart

# Only lib/features/home/hero/suggestion_catalog.g.dart
dart run tools/gen/main.dart --catalog-only [--catalog-out <file>] [--upstream <repo root>]
```

The suggestion catalog (`src/suggestion_catalog.dart`) reads
`generated/blocks.json` (`$meta.templates`) plus two upstream sources outside
`apps/flutter`: `packages/deployment-config/src/integration-metadata.ts` (the
`JSON.parse('...')` literal) and `apps/sim/lib/oauth/oauth.ts` (the
`OAUTH_PROVIDERS` service entries). `--upstream` defaults to the repo root two
levels above `apps/flutter`. Output is passed through `dart format`.

`dart run tools/check_generated.dart` regenerates both into temp locations and
fails if the committed files are stale.
