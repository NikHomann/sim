# Brings the Flutter test stack up: upstream local compose + docker-compose.flutter.yml.
#
#   tools/stack/up.ps1                       # build images as needed, wait for health
#   tools/stack/up.ps1 -Build                # force a rebuild (Next app, realtime, Flutter bundle)
#   tools/stack/up.ps1 -NoMail               # no-verification profile (docker-compose.flutter.nomail.yml)
#   tools/stack/up.ps1 -StaticWeb apps/flutter/build/web   # serve a host build instead of the image
#   tools/stack/up.ps1 -BaseCompose <path> -Project upstream
#
# -Project defaults to `upstream`, the name the running base stack uses, so the overlay re-creates
# the base services in place (same volumes, same network) instead of starting a second copy.

[CmdletBinding()]
param(
  [string] $BaseCompose,
  [string] $Project = 'upstream',
  [switch] $NoMail,
  [string] $StaticWeb,
  [switch] $Build,
  [switch] $NoWait,
  [int] $TimeoutSec = 900
)

. (Join-Path $PSScriptRoot 'common.ps1')

$repoRoot = Get-SimRepoRoot
$base = Resolve-SimBaseCompose -BaseCompose $BaseCompose -RepoRoot $repoRoot

if ($StaticWeb) {
  $resolved = Resolve-Path $StaticWeb -ErrorAction SilentlyContinue
  if (-not $resolved -or -not (Test-Path (Join-Path $resolved 'index.html'))) {
    throw "-StaticWeb must point at a 'flutter build web --base-href /app/' output directory (index.html missing): $StaticWeb"
  }
  $env:SIM_FLUTTER_WEB_DIR = $resolved.Path
}

$compose = Get-SimComposeArgs -Project $Project -RepoRoot $repoRoot -BaseCompose $base -NoMail:$NoMail -StaticWeb $StaticWeb
$up = @('up', '-d', '--remove-orphans')
if ($StaticWeb) { $up += '--no-build' } elseif ($Build) { $up += '--build' }

Invoke-SimDocker -Arguments ($compose + $up)

if (-not $NoWait) {
  & (Join-Path $PSScriptRoot 'wait.ps1') -BaseCompose $base -Project $Project -NoMail:$NoMail -StaticWeb $StaticWeb -TimeoutSec $TimeoutSec
  exit $LASTEXITCODE
}
