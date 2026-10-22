# L0 gate for the Flutter port (docs/port/04-test-plan.md section 5).
# Runs from apps/flutter. Native tools report through exit codes, not stderr,
# so PowerShell's error preference stays 'Continue' and every step checks
# $LASTEXITCODE explicitly.
$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..')

# Dart-only packages use `dart`; Flutter packages and the app use `flutter`.
$dartPackages = @('packages/sim_workflow', 'tools/seed', 'tools/gen')
$flutterPackages = @('packages/sim_design', 'packages/sim_api', 'packages/sim_canvas', 'packages/sim_canvas/example', '.')

function Step($label, [scriptblock]$body) {
  Write-Host "== $label"
  & $body
  if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: $label"; exit 1 }
}

function FormatPaths {
  @('lib', 'bin', 'src', 'main.dart', 'test', 'test_contract', 'integration_test') | Where-Object { Test-Path $_ }
}

foreach ($p in $dartPackages) {
  Push-Location $p
  Step "$p : pub get" { dart pub get }
  Step "$p : format" { $paths = FormatPaths; if ($paths) { dart format --set-exit-if-changed @paths } }
  Step "$p : analyze" { dart analyze --fatal-infos }
  if (Test-Path test) { Step "$p : test" { dart test --test-randomize-ordering-seed random } }
  Pop-Location
}

foreach ($p in $flutterPackages) {
  Push-Location $p
  Step "$p : pub get" { flutter pub get }
  Step "$p : format" { $paths = FormatPaths; if ($paths) { dart format --set-exit-if-changed @paths } }
  Step "$p : analyze" { flutter analyze --fatal-infos }
  # The JSON report (build/test-report.json in each package) names the failing
  # test and the shuffle seed when an order-dependent test flakes.
  if (Test-Path test) { Step "$p : test" { flutter test --test-randomize-ordering-seed random --exclude-tags contract,e2e --file-reporter json:build/test-report.json } }
  Pop-Location
}

# App-level tools that are plain Dart scripts (not packages of their own).
Step "tools : format" { dart format --set-exit-if-changed tools/check_generated.dart }

if (Test-Path tools/check_generated.dart) {
  Step "check_generated" { dart run tools/check_generated.dart }
}

Write-Host "L0 gate passed"
