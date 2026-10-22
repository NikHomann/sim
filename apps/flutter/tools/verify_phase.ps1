# Full phase verification, run sequentially so the load of one step cannot
# make another flaky (docs/port/04-test-plan.md §5):
#   1. L0 gate (tools/ci.ps1)
#   2. profile web build + structural parity capture/compare (tools/parity)
#   3. L5 e2e smoke flow via flutter drive (UI sign-in)
# Prerequisites: the reference stack on :3000/:3002 with seeded data, the dev
# proxy on :3005 forwarding /app/* to :8088 (FLUTTER_PORT=8088, no prefix
# strip), chromedriver on :4444, and $env:SIM_SEED_PATH pointing at seed.json.
# Writes build/verify/summary.txt.
param(
  [string]$Phase = 'phase-1',
  [string]$Email = 'flutter-e2e@example.com',
  [string]$Password = 'Flutter-e2e-Passw0rd!'
)
$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..')
New-Item -ItemType Directory -Force build/verify | Out-Null
$summary = @()

& ./tools/ci.ps1 *> build/verify/gate.log
$summary += "gate: exit $LASTEXITCODE (build/verify/gate.log)"

# Own output folder: `flutter drive` below compiles the e2e bundle into
# build/web, which must never be what the parity capture serves.
flutter build web --profile --base-href /app/ -t lib/main_web.dart --no-web-resources-cdn --output (Join-Path (Get-Location) 'build/web_parity') *> build/verify/build.log
$summary += "profile build: exit $LASTEXITCODE"

# The parity capture serves the profile build itself: a static server on
# :8090 behind a second proxy on :3006 (both stopped afterwards).
$static = Start-Process node -ArgumentList 'tools/serve_static.mjs','build/web_parity','8090' -PassThru -WindowStyle Hidden
$env:PROXY_PORT = '3006'; $env:FLUTTER_PORT = '8090'; $env:FLUTTER_STRIP_PREFIX = '1'
$proxy = Start-Process node -ArgumentList 'tools/dev_proxy.mjs' -PassThru -WindowStyle Hidden
Remove-Item Env:PROXY_PORT, Env:FLUTTER_PORT, Env:FLUTTER_STRIP_PREFIX
Start-Sleep -Seconds 3
Push-Location tools/parity
# Node writes the override: Windows PowerShell 5.1's Set-Content -Encoding utf8
# adds a BOM, which JSON.parse rejects.
node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync('screens.json','utf8'));c.flutterOrigin='http://localhost:3006';fs.writeFileSync('screens.verify.json',JSON.stringify(c,null,2))"
node capture.mjs --config screens.verify.json *> ../../build/verify/parity-capture.log
node compare.mjs --config screens.verify.json *> ../../build/verify/parity-compare.log
$summary += "parity: exit $LASTEXITCODE (build/verify/parity-compare.log)"
$summary += (Get-Content ../../build/verify/parity-compare.log | Select-String -Pattern '^(PASS|FAIL)' | ForEach-Object { "  $_" })
Remove-Item screens.verify.json
Pop-Location
Stop-Process -Id $static.Id, $proxy.Id -ErrorAction SilentlyContinue

$env:E2E_REPORT_PATH = 'build/verify/e2e-smoke.json'
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/phase1_smoke_test.dart -d web-server --profile --web-port 8088 --web-launch-url http://localhost:3005/app/login --browser-dimension 1440x900@1 --chrome-binary "C:\Program Files\Google\Chrome\Application\chrome.exe" --driver-port 4444 --dart-define=SIM_E2E=true --dart-define=SIM_E2E_SIGN_IN=ui "--dart-define=SIM_E2E_EMAIL=$Email" "--dart-define=SIM_E2E_PASSWORD=$Password" *> build/verify/e2e.log
$summary += "e2e: exit $LASTEXITCODE (build/verify/e2e-smoke.json)"

$summary | Set-Content -Encoding utf8 build/verify/summary.txt
$summary
