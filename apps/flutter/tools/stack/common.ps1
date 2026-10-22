# Shared helpers for the Flutter test-stack scripts (dot-sourced by up.ps1, down.ps1, wait.ps1).
#
# The stack is the upstream local compose file plus docker-compose.flutter.yml
# (docs/port/04-test-plan.md section 2). Docker Compose 2.15 cannot parse the base file's
# `env_file: - path: .env / required: false` mapping, so the base is rewritten into the string
# form once and the copy is passed with `-f`, with `--project-directory` kept at the repo root so
# relative paths and the `.env` still resolve there.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SimRepoRoot {
  # tools/stack -> tools -> flutter -> apps -> repo root
  return (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
}

function Get-SimDefaultBaseCompose {
  # The copy the currently running stack was started from, when it exists.
  $scratch = Join-Path $env:LOCALAPPDATA 'Temp\claude\C--Dev-deutz-sim\6ee4a102-5a2d-43d3-b69b-5a93d3be791b\scratchpad\compose.local.yml'
  if (Test-Path $scratch) { return $scratch }
  return (Join-Path $env:TEMP 'sim-compose.local.yml')
}

function ConvertTo-SimStringEnvFile {
  # Rewrites the mapping-form `env_file` entries of docker-compose.local.yml into the string form
  # Compose 2.15 understands and writes the result to $Destination.
  param(
    [Parameter(Mandatory)] [string] $Source,
    [Parameter(Mandatory)] [string] $Destination
  )
  $text = Get-Content -Raw -Encoding UTF8 $Source
  $pattern = '(?m)^(\s*)-\s*path:\s*(\S+)\r?\n\s*required:\s*(true|false)\s*$'
  $rewritten = [regex]::Replace($text, $pattern, { param($m) "$($m.Groups[1].Value)- $($m.Groups[2].Value)" })
  [IO.File]::WriteAllText($Destination, $rewritten, (New-Object System.Text.UTF8Encoding $false))
  return $Destination
}

function Resolve-SimBaseCompose {
  param([string] $BaseCompose, [string] $RepoRoot)
  if ($BaseCompose -and (Test-Path $BaseCompose)) { return (Resolve-Path $BaseCompose).Path }
  if ($BaseCompose) { throw "Base compose file not found: $BaseCompose" }
  $default = Get-SimDefaultBaseCompose
  if (Test-Path $default) { return $default }
  Write-Host "Rewriting docker-compose.local.yml env_file mapping into $default"
  return (ConvertTo-SimStringEnvFile -Source (Join-Path $RepoRoot 'docker-compose.local.yml') -Destination $default)
}

function Get-SimComposeArgs {
  # Returns the `docker compose ...` argument prefix: project name, project directory and files.
  param(
    [Parameter(Mandatory)] [string] $Project,
    [Parameter(Mandatory)] [string] $RepoRoot,
    [Parameter(Mandatory)] [string] $BaseCompose,
    [switch] $NoMail,
    [string] $StaticWeb
  )
  $files = @($BaseCompose, (Join-Path $RepoRoot 'docker-compose.flutter.yml'))
  if ($NoMail) { $files += (Join-Path $RepoRoot 'docker-compose.flutter.nomail.yml') }
  if ($StaticWeb) { $files += (Join-Path $PSScriptRoot 'compose.static.yml') }
  $args = @('compose', '-p', $Project, '--project-directory', $RepoRoot)
  foreach ($f in $files) { $args += @('-f', $f) }
  return $args
}

function Invoke-SimDocker {
  param([Parameter(Mandatory)] [string[]] $Arguments)
  Write-Host "> docker $($Arguments -join ' ')"
  & docker @Arguments
  if ($LASTEXITCODE -ne 0) { throw "docker exited with $LASTEXITCODE" }
}
