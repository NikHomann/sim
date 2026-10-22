# Builds the extraction image from the monorepo and runs the export script with
# apps/flutter/generated bind-mounted as its output directory. bun is not on the
# host (docs/port/TOOLCHAIN.md), so this is the only way to run the script.
#
#   .\apps\flutter\tools\extract\run.ps1            # build + run
#   .\apps\flutter\tools\extract\run.ps1 -NoBuild   # reuse the last image
param(
  [switch]$NoBuild,
  [string]$Tag = 'sim-flutter-extract',
  [string]$OutDir
)
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
if (-not $OutDir) { $OutDir = Join-Path $repo 'apps\flutter\generated' }
$commit = (& git -C $repo rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or -not $commit) { throw 'git rev-parse HEAD failed' }

$env:DOCKER_BUILDKIT = '1'
# docker writes its progress to stderr; under 'Stop' Windows PowerShell would
# turn the first such line into a terminating NativeCommandError.
$ErrorActionPreference = 'Continue'
if (-not $NoBuild) {
  Write-Host "== building $Tag from $repo"
  & docker build -f (Join-Path $repo 'apps\flutter\tools\extract\Dockerfile') -t $Tag $repo
  if ($LASTEXITCODE -ne 0) { throw "docker build failed ($LASTEXITCODE)" }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$mount = "$((Resolve-Path $OutDir).Path):/out"
Write-Host "== running $Tag (commit $commit) -> $OutDir"
& docker run --rm -e "UPSTREAM_COMMIT=$commit" -e 'FLUTTER_PORT_OUT=/out' -v $mount $Tag
if ($LASTEXITCODE -ne 0) { throw "export script failed ($LASTEXITCODE)" }
Write-Host "== done: $(Get-Content (Join-Path $OutDir 'manifest.json') -Raw | ConvertFrom-Json | Select-Object -ExpandProperty counts | ConvertTo-Json -Compress)"
