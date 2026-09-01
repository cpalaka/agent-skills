# Bootstrap the Chunk library on a new Windows machine.
#
# Prereq: this repository is already cloned. The clone may live anywhere - the script takes the
# location from its own path, so run it from wherever you put the clone:
#
#     powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
#
# It creates two directory junctions into this clone's chunks\ directory, one per host:
#
#     %USERPROFILE%\.claude\chunks   so Claude Code's @~/.claude/chunks/<name>.md imports resolve
#     %USERPROFILE%\.codex\chunks    so a Codex AGENTS.md read directive for ~/.codex/chunks/<name>.md
#                                    resolves (Codex does not expand @-imports; it is pointed at the
#                                    files explicitly)
#
# A junction needs no admin rights. Idempotent: a junction already pointing at this clone is left
# alone. Anything else in the way is reported and left alone - clearing it is your call. Each host
# is attempted independently, so a failure on one still reports the state of the other; that is why
# every failure path here is a non-terminating Write-Error rather than a throw under
# $ErrorActionPreference = 'Stop'.
$ErrorActionPreference = 'Stop'

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Chunks  = Join-Path $RepoDir 'chunks'

if (-not (Test-Path $Chunks)) {
  Write-Error "chunks\ not found at $Chunks - run this from the clone." -ErrorAction Continue
  exit 1
}

function New-ChunkLink {
  param([string]$Link)

  try {
    New-Item -ItemType Directory -Force -Path (Split-Path $Link) | Out-Null

    if (Test-Path $Link) {
      $item = Get-Item $Link -Force
      if ($item.LinkType -eq 'Junction' -and ($item.Target -contains $Chunks)) {
        Write-Host "ok: $Link already junctioned -> $Chunks"
        return $true
      }
      Write-Error "$Link exists and is not a junction to $Chunks. Remove it and re-run." -ErrorAction Continue
      return $false
    }

    New-Item -ItemType Junction -Path $Link -Target $Chunks | Out-Null
    Write-Host "junctioned $Link -> $Chunks"
    return $true
  }
  catch {
    Write-Error "could not link ${Link}: $($_.Exception.Message)" -ErrorAction Continue
    return $false
  }
}

$ok = $true
if (-not (New-ChunkLink (Join-Path $env:USERPROFILE '.claude\chunks'))) { $ok = $false }
if (-not (New-ChunkLink (Join-Path $env:USERPROFILE '.codex\chunks')))  { $ok = $false }
if (-not $ok) { exit 1 }

Write-Host ""
Write-Host "Claude Code: the imports are external includes, so each consuming project asks for approval"
Write-Host "once on first launch; approve, then restart the session so they load."
Write-Host "Codex: no approval - its AGENTS.md names the files and reads them directly."
