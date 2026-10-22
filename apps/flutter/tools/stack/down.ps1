# Stops the Flutter test stack. -Volumes also drops the named volumes (the test database).
#
#   tools/stack/down.ps1
#   tools/stack/down.ps1 -Volumes

[CmdletBinding()]
param(
  [string] $BaseCompose,
  [string] $Project = 'upstream',
  [switch] $NoMail,
  [string] $StaticWeb,
  [switch] $Volumes
)

. (Join-Path $PSScriptRoot 'common.ps1')

$repoRoot = Get-SimRepoRoot
$base = Resolve-SimBaseCompose -BaseCompose $BaseCompose -RepoRoot $repoRoot
$compose = Get-SimComposeArgs -Project $Project -RepoRoot $repoRoot -BaseCompose $base -NoMail:$NoMail -StaticWeb $StaticWeb

$down = @('down', '--remove-orphans')
if ($Volumes) { $down += '-v' }

Invoke-SimDocker -Arguments ($compose + $down)
