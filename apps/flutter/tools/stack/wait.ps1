# Waits until simstudio, realtime, caddy and mailpit answer from the host, then prints `compose ps`.
# Exit code 1 on timeout, listing what is still unhealthy.
#
#   tools/stack/wait.ps1 [-TimeoutSec 900] [-NoMail] [-SkipCaddy]

[CmdletBinding()]
param(
  [string] $BaseCompose,
  [string] $Project = 'upstream',
  [switch] $NoMail,
  [string] $StaticWeb,
  [switch] $SkipCaddy,
  [switch] $SkipMailpit,
  [int] $TimeoutSec = 900,
  [int] $IntervalSec = 5
)

. (Join-Path $PSScriptRoot 'common.ps1')

function Test-SimHttp {
  param([string] $Url, [int[]] $Accept)
  try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 10 -ErrorAction Stop
    return $Accept -contains [int]$response.StatusCode
  } catch [System.Net.WebException] {
    $resp = $_.Exception.Response
    if ($resp -ne $null) { return $Accept -contains [int]$resp.StatusCode }
    return $false
  } catch {
    return $false
  }
}

$ok2xx3xx = 200..399
$checks = [ordered]@{
  'simstudio http://localhost:3000/'          = { Test-SimHttp 'http://localhost:3000/' $ok2xx3xx }
  'realtime  http://localhost:3002/health'    = { Test-SimHttp 'http://localhost:3002/health' @(200) }
}
if (-not $SkipCaddy) {
  $checks['caddy     http://localhost:3001/app/'] = { Test-SimHttp 'http://localhost:3001/app/' @(200) }
  $checks['caddy     http://localhost:3001/api/auth/get-session (proxied)'] = { Test-SimHttp 'http://localhost:3001/api/auth/get-session' @(200) }
}
if (-not $SkipMailpit) {
  $checks['mailpit   http://localhost:8025/api/v1/info'] = { Test-SimHttp 'http://localhost:8025/api/v1/info' @(200) }
}

$deadline = (Get-Date).AddSeconds($TimeoutSec)
$pending = [System.Collections.Generic.List[string]]::new()
$checks.Keys | ForEach-Object { $pending.Add($_) }

while ($pending.Count -gt 0) {
  foreach ($name in @($pending)) {
    if (& $checks[$name]) {
      Write-Host "ready    $name"
      $pending.Remove($name) | Out-Null
    }
  }
  if ($pending.Count -eq 0) { break }
  if ((Get-Date) -gt $deadline) {
    Write-Host "TIMEOUT after ${TimeoutSec}s; still waiting for:"
    $pending | ForEach-Object { Write-Host "  $_" }
    exit 1
  }
  Start-Sleep -Seconds $IntervalSec
}

try {
  $repoRoot = Get-SimRepoRoot
  $base = Resolve-SimBaseCompose -BaseCompose $BaseCompose -RepoRoot $repoRoot
  $compose = Get-SimComposeArgs -Project $Project -RepoRoot $repoRoot -BaseCompose $base -NoMail:$NoMail -StaticWeb $StaticWeb
  & docker @($compose + @('ps'))
} catch {
  Write-Host "compose ps skipped: $($_.Exception.Message)"
}
exit 0
