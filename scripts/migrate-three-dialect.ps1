# Empty-DB migrate smoke — three-dialect policy runner (W2)
#
# SQLite: always executed (required green).
# MySQL / PostgreSQL: only when DATABASE URL env is set; never touches production
# by default (empty/temp DB only).
#
# Usage:
#   pwsh -File scripts/migrate-three-dialect.ps1
#   $env:MIGRATE_MYSQL_URL = 'mysql://user:pass@tcp(127.0.0.1:3306)/th_migrate_empty'
#   $env:MIGRATE_PG_URL    = 'postgres://user:pass@127.0.0.1:5432/th_migrate_empty?sslmode=disable'
#   pwsh -File scripts/migrate-three-dialect.ps1
#
# Exit:
#   0 — SQLite green; optional dialects green or correctly SKIPPED
#   1 — SQLite failed, or an opted-in dialect failed

[CmdletBinding()]
param(
  [string]$MigrationsPath = "",
  [switch]$RequireMySQL,
  [switch]$RequirePostgres
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path.TrimEnd("\")
if ([string]::IsNullOrWhiteSpace($MigrationsPath)) {
  $MigrationsPath = Join-Path $repoRoot "migrations\main"
}
$MigrationsPath = (Resolve-Path $MigrationsPath).Path

function Invoke-Dialect {
  param(
    [string]$Name,
    [string]$DatabaseURL,
    [bool]$Required
  )

  if ([string]::IsNullOrWhiteSpace($DatabaseURL)) {
    if ($Required) {
      Write-Host "FAIL $Name required but URL env empty"
      return 1
    }
    Write-Host "SKIP $Name (no URL env — see docs/ops/migrate-three-dialect-strategy.md)"
    return 0
  }

  Write-Host "==> $Name up on empty target"
  Write-Host "    database: $DatabaseURL"
  Push-Location $repoRoot
  try {
    # Capture go stdout so it does not pollute PowerShell function return values.
    $upOut = & go run ./cmd/dbmigrate -path $MigrationsPath -database $DatabaseURL up 2>&1 | Out-String
    $upCode = $LASTEXITCODE
    if ($upOut.Trim()) { Write-Host $upOut.TrimEnd() }
    if ($upCode -ne 0) {
      Write-Host "FAIL $Name up exit=$upCode"
      return 1
    }
    $verOut = & go run ./cmd/dbmigrate -path $MigrationsPath -database $DatabaseURL version 2>&1 | Out-String
    $verCode = $LASTEXITCODE
    if ($verCode -ne 0) {
      Write-Host "FAIL $Name version exit=$verCode"
      if ($verOut.Trim()) { Write-Host $verOut.TrimEnd() }
      return 1
    }
    $ver = $verOut.Trim()
    Write-Host "    version=$ver"
    if ($ver -notmatch '^1(\s|$)') {
      Write-Host "WARN $Name version expected 1, got: $ver"
    }
    Write-Host "PASS $Name"
    return 0
  } finally {
    Pop-Location
  }
}

Write-Host "migrations: $MigrationsPath"
Write-Host "repo:       $repoRoot"

$tmpDir = Join-Path $repoRoot ".tmp"
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
$sqliteFile = Join-Path $tmpDir ("migrate-w2-sqlite-{0}.db" -f (Get-Date -Format "yyyyMMddHHmmss"))
if (Test-Path $sqliteFile) { Remove-Item -Force $sqliteFile }
$sqliteURL = "sqlite://" + (($sqliteFile -replace '\\', '/'))

$failed = 0

$rc = Invoke-Dialect -Name "sqlite" -DatabaseURL $sqliteURL -Required $true
if ($rc -ne 0) { $failed++ }

$mysqlURL = $env:MIGRATE_MYSQL_URL
$pgURL = $env:MIGRATE_PG_URL
# Do NOT auto-pick SQL_DSN — production safety. Explicit MIGRATE_*_URL only.

$rc = Invoke-Dialect -Name "mysql" -DatabaseURL $mysqlURL -Required ([bool]$RequireMySQL)
if ($rc -ne 0) { $failed++ }

$rc = Invoke-Dialect -Name "postgres" -DatabaseURL $pgURL -Required ([bool]$RequirePostgres)
if ($rc -ne 0) { $failed++ }

if ($failed -gt 0) {
  Write-Host "FAIL migrate-three-dialect ($failed dialect error(s))"
  exit 1
}

Write-Host "PASS migrate-three-dialect (sqlite required green; others optional/skip)"
exit 0
