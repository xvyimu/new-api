# Phase1 WP-S: apply migrations/main via cmd/dbmigrate (pure-Go SQLite; no CGO).
# Prefer this over the external migrate CLI on Windows.

[CmdletBinding()]
param(
  [ValidateSet("up", "down", "version", "force")]
  [string]$Direction = "up",
  [string]$DatabaseURL = "",
  [string]$MigrationsPath = "",
  [int]$Steps = 0,
  [int]$ForceVersion = 0
)

$ErrorActionPreference = "Stop"

function Assert-ExitCode([string]$Step) {
  if ($LASTEXITCODE -ne 0) {
    throw "$Step failed with exit code $LASTEXITCODE"
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path.TrimEnd("\")
if ([string]::IsNullOrWhiteSpace($MigrationsPath)) {
  $MigrationsPath = Join-Path $repoRoot "migrations\main"
}
$MigrationsPath = (Resolve-Path $MigrationsPath).Path

if ([string]::IsNullOrWhiteSpace($DatabaseURL)) {
  if (-not [string]::IsNullOrWhiteSpace($env:MIGRATE_DATABASE_URL)) {
    $DatabaseURL = $env:MIGRATE_DATABASE_URL
  } elseif (-not [string]::IsNullOrWhiteSpace($env:SQL_DSN) -and $env:SQL_DSN -match '://') {
    $DatabaseURL = $env:SQL_DSN
  } else {
    $tmpDir = Join-Path $repoRoot ".tmp"
    New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
    $dbFile = Join-Path $tmpDir "migrate-demo.db"
    if (Test-Path $dbFile) { Remove-Item -Force $dbFile }
    $DatabaseURL = "sqlite://" + (($dbFile -replace '\\', '/'))
  }
}

Write-Host "migrations: $MigrationsPath"
Write-Host "database:   $DatabaseURL"
Write-Host "direction:  $Direction"

Push-Location $repoRoot
try {
  switch ($Direction) {
    "up" {
      if ($Steps -gt 0) {
        go run ./cmd/dbmigrate -path $MigrationsPath -database $DatabaseURL up $Steps
      } else {
        go run ./cmd/dbmigrate -path $MigrationsPath -database $DatabaseURL up
      }
      Assert-ExitCode "dbmigrate up"
    }
    "down" {
      $n = if ($Steps -gt 0) { $Steps } else { 1 }
      go run ./cmd/dbmigrate -path $MigrationsPath -database $DatabaseURL down $n
      Assert-ExitCode "dbmigrate down"
    }
    "version" {
      go run ./cmd/dbmigrate -path $MigrationsPath -database $DatabaseURL version
      Assert-ExitCode "dbmigrate version"
    }
    "force" {
      go run ./cmd/dbmigrate -path $MigrationsPath -database $DatabaseURL force $ForceVersion
      Assert-ExitCode "dbmigrate force"
    }
  }
} finally {
  Pop-Location
}

Write-Host "db-migrate: ok"
