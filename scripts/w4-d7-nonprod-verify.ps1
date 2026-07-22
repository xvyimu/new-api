# W4 · D7 non-production cutover verify pack (orchestrator)
# Does NOT flip production FRONTEND_MODE. Does NOT migrate live DBs.
#
# Usage:
#   pwsh -NoProfile -File scripts/w4-d7-nonprod-verify.ps1
#   pwsh -NoProfile -File scripts/w4-d7-nonprod-verify.ps1 -SkipConsoleBuild -SkipBackendBuild
#
# Env (non-prod only — never commit secrets):
#   TH_API_BASE   default http://127.0.0.1:3000
#   TH_E2E_USER   required for login + channels RO (no silent default green)
#   TH_E2E_PASS   required for login + channels RO
#
# Exit codes (no fake green):
#   0  all selected steps green (incl. login + channels RO when not -SkipAuth)
#   1  login failed (wrong/missing credentials or setup incomplete)
#   2  self/session failed after login
#   3  backend unreachable (healthz)
#   4  channels RO failed (auth, shape, or secret key present on list)
#   5  contract validator or local build step failed
#   6  /api/status failed
#  10  credentials not set — auth steps blocked (actionable fail; not pass)
#
# Docs: docs/ops/w4-d7-nonprod-verify.md · docs/ops/w2-cutover-e2e-credentials.md

param(
  [string]$ApiBase = $(if ($env:TH_API_BASE) { $env:TH_API_BASE } else { 'http://127.0.0.1:3000' }),
  [switch]$SkipAuth,
  [switch]$SkipConsoleBuild,
  [switch]$SkipBackendBuild,
  [switch]$SkipContract
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $Root 'go.mod'))) {
  $Root = (Get-Location).Path
}

function Write-Step([string]$msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Pass([string]$msg) { Write-Host "PASS  $msg" -ForegroundColor Green }
function Write-Fail([string]$msg) { Write-Host "FAIL  $msg" -ForegroundColor Red }
function Write-Block([string]$msg) { Write-Host "BLOCK $msg" -ForegroundColor Yellow }
function Write-Info([string]$msg) { Write-Host "INFO  $msg" }

$ApiBase = $ApiBase.TrimEnd('/')
$results = [System.Collections.Generic.List[string]]::new()
$exitCode = 0

function Set-Exit([int]$code) {
  if ($script:exitCode -eq 0 -or $code -gt $script:exitCode) {
    # Prefer sticky first fatal auth/backend codes; still allow upgrade from 0
  }
  if ($script:exitCode -eq 0) { $script:exitCode = $code }
  elseif ($code -in 1, 2, 3, 4, 6 -and $script:exitCode -eq 10) { $script:exitCode = $code }
  elseif ($code -in 1, 2, 3, 4, 6 -and $script:exitCode -eq 5) { $script:exitCode = $code }
}

Write-Host ""
Write-Host "W4 D7 nonprod verify  ApiBase=$ApiBase"
Write-Host "D7 FLIP: NOT EXECUTED (this script never changes production FRONTEND_MODE)"
Write-Host ""

# --- 1. healthz ---
Write-Step "GET $ApiBase/healthz"
try {
  $hz = Invoke-WebRequest -Uri "$ApiBase/healthz" -UseBasicParsing -TimeoutSec 5
  if ($hz.StatusCode -ne 200) { throw "status $($hz.StatusCode)" }
  Write-Pass "healthz HTTP 200"
  $results.Add('healthz=0')
} catch {
  Write-Fail "backend unreachable: $_"
  Write-Info "Fix: start non-prod API on $ApiBase (or set TH_API_BASE). See web-console/E2E.md"
  $results.Add('healthz=3')
  Write-Host ""
  Write-Host "SUMMARY exit=3  $($results -join ' ')"
  exit 3
}

# --- 2. /api/status ---
Write-Step "GET $ApiBase/api/status"
try {
  $st = Invoke-WebRequest -Uri "$ApiBase/api/status" -UseBasicParsing -TimeoutSec 10
  if ($st.StatusCode -ne 200) { throw "status $($st.StatusCode)" }
  if ($st.Content -notmatch '\{') { throw 'non-json body' }
  Write-Pass "/api/status HTTP 200"
  $results.Add('status=0')
} catch {
  Write-Fail "/api/status: $_"
  $results.Add('status=6')
  Set-Exit 6
}

# --- 3. OpenAPI contract ---
if (-not $SkipContract) {
  Write-Step "python scripts/validate-console-contract.py"
  $py = Join-Path $Root 'scripts/validate-console-contract.py'
  if (-not (Test-Path $py)) {
    Write-Fail "missing $py"
    $results.Add('contract=5')
    Set-Exit 5
  } else {
    & python $py
    $c = $LASTEXITCODE
    if ($c -eq 0) {
      Write-Pass "console-subset contract"
      $results.Add('contract=0')
    } else {
      Write-Fail "contract validator exit $c"
      $results.Add("contract=$c")
      Set-Exit 5
    }
  }
} else {
  Write-Info "skip contract (-SkipContract)"
  $results.Add('contract=skip')
}

# --- 4–5. login + channels RO ---
$userSet = [bool]$env:TH_E2E_USER
$passSet = [bool]$env:TH_E2E_PASS
$credsOk = $userSet -and $passSet

if ($SkipAuth) {
  Write-Info "skip auth/channels (-SkipAuth) — NOT sufficient for G2/G3 green"
  $results.Add('login=skip')
  $results.Add('channels=skip')
  if ($exitCode -eq 0) { Set-Exit 10 }
} elseif (-not $credsOk) {
  Write-Block "TH_E2E_USER / TH_E2E_PASS not both set — login + channels RO blocked"
  Write-Info "Actionable:"
  Write-Info "  1. Non-prod only — see docs/ops/w2-cutover-e2e-credentials.md"
  Write-Info "  2. `$env:TH_E2E_USER = '<non-prod-admin>'"
  Write-Info "  3. `$env:TH_E2E_PASS = '<non-prod-secret>'   # never commit"
  Write-Info "  4. Re-run: pwsh -NoProfile -File scripts/w4-d7-nonprod-verify.ps1"
  Write-Info "Default root/123456 is NOT auto-accepted here (avoids false green on shared DBs)."
  $results.Add('login=10')
  $results.Add('channels=10')
  Set-Exit 10
} else {
  $user = $env:TH_E2E_USER
  $pass = $env:TH_E2E_PASS
  Write-Step "POST /api/user/login as $user (session + New-Api-User)"
  $body = @{ username = $user; password = $pass } | ConvertTo-Json
  $sess = $null
  $uid = $null
  try {
    $login = Invoke-WebRequest -Uri "$ApiBase/api/user/login" -Method POST -Body $body `
      -ContentType 'application/json; charset=utf-8' -SessionVariable sess -UseBasicParsing -TimeoutSec 10
    $loginJson = $login.Content | ConvertFrom-Json
    if (-not $loginJson.success) {
      Write-Fail "login rejected: $($login.Content)"
      Write-Info "Fix: mint non-prod admin — docs/ops/w2-cutover-e2e-credentials.md (not production)"
      $results.Add('login=1')
      $results.Add('channels=skip')
      Set-Exit 1
    } else {
      $uid = $loginJson.data.id
      if (-not $uid) {
        Write-Fail "login response missing data.id"
        $results.Add('login=1')
        $results.Add('channels=skip')
        Set-Exit 1
      } else {
        Write-Pass "login id=$uid role=$($loginJson.data.role)"
        $results.Add('login=0')

        Write-Step "GET /api/user/self"
        try {
          $self = Invoke-WebRequest -Uri "$ApiBase/api/user/self" -WebSession $sess `
            -Headers @{ 'New-Api-User' = "$uid" } -UseBasicParsing -TimeoutSec 10
          $selfJson = $self.Content | ConvertFrom-Json
          if (-not $selfJson.success) { throw "self payload: $($self.Content)" }
          Write-Pass "self username=$($selfJson.data.username)"
        } catch {
          Write-Fail "self: $_"
          $results.Add('self=2')
          $results.Add('channels=skip')
          Set-Exit 2
        }

        if ($exitCode -ne 2) {
          Write-Step "GET /api/channel/ (channels RO · keys must be absent)"
          try {
            $ch = Invoke-WebRequest -Uri "$ApiBase/api/channel/" -WebSession $sess `
              -Headers @{ 'New-Api-User' = "$uid" } -UseBasicParsing -TimeoutSec 15
            if ($ch.StatusCode -ne 200) { throw "HTTP $($ch.StatusCode)" }
            $chJson = $ch.Content | ConvertFrom-Json
            if ($null -eq $chJson.success) { throw 'missing success field' }
            if (-not $chJson.success) { throw "success=false: $($ch.Content.Substring(0, [Math]::Min(200, $ch.Content.Length)))" }

            # Secret key must not appear as a non-empty value on list items
            $raw = $ch.Content
            $keyLeak = $false
            if ($chJson.data -and $chJson.data.items) {
              foreach ($item in $chJson.data.items) {
                if ($null -ne $item.key -and "$($item.key)".Length -gt 0) {
                  $keyLeak = $true
                  break
                }
              }
            } elseif ($chJson.data -is [System.Array]) {
              foreach ($item in $chJson.data) {
                if ($null -ne $item.key -and "$($item.key)".Length -gt 0) {
                  $keyLeak = $true
                  break
                }
              }
            }
            # Heuristic: "key":"<nonempty>" in list payload (not just schema docs)
            if ($raw -match '"key"\s*:\s*"[^"]+"') {
              $keyLeak = $true
            }

            if ($keyLeak) {
              Write-Fail "channels list appears to include key material"
              $results.Add('channels=4')
              Set-Exit 4
            } else {
              Write-Pass "channels RO (no key material detected on list)"
              $results.Add('channels=0')
            }
          } catch {
            Write-Fail "channels RO: $_"
            Write-Info "Need AdminAuth + ChannelRead on the e2e user; contract: getChannelsList in console-subset.yaml"
            $results.Add('channels=4')
            Set-Exit 4
          }
        }
      }
    }
  } catch {
    Write-Fail "login request: $_"
    Write-Info "Fix: docs/ops/w2-cutover-e2e-credentials.md · TH_E2E_* on non-prod only"
    $results.Add('login=1')
    $results.Add('channels=skip')
    Set-Exit 1
  }
}

# --- 6. web-console build ---
if (-not $SkipConsoleBuild) {
  Write-Step "web-console pnpm build (quality gate subset)"
  $wc = Join-Path $Root 'web-console'
  if (-not (Test-Path (Join-Path $wc 'package.json'))) {
    Write-Fail "web-console/ missing"
    $results.Add('console_build=5')
    Set-Exit 5
  } else {
    Push-Location $wc
    try {
      if (-not (Test-Path 'node_modules')) {
        Write-Info "pnpm install --frozen-lockfile"
        & pnpm install --frozen-lockfile
        if ($LASTEXITCODE -ne 0) { throw "pnpm install exit $LASTEXITCODE" }
      }
      & pnpm run build
      if ($LASTEXITCODE -ne 0) { throw "pnpm build exit $LASTEXITCODE" }
      Write-Pass "web-console build"
      $results.Add('console_build=0')
    } catch {
      Write-Fail "web-console build: $_"
      $results.Add('console_build=5')
      Set-Exit 5
    } finally {
      Pop-Location
    }
  }
} else {
  Write-Info "skip web-console build (-SkipConsoleBuild)"
  $results.Add('console_build=skip')
}

# --- 7. backend frontend_external (optional heavy) ---
if (-not $SkipBackendBuild) {
  Write-Step "go build -tags frontend_external"
  $out = Join-Path $Root 'new-api-backend-w4-verify.exe'
  try {
    Push-Location $Root
    & go build -trimpath -buildvcs=true -tags frontend_external -o $out .
    if ($LASTEXITCODE -ne 0) { throw "go build exit $LASTEXITCODE" }
    Write-Pass "frontend_external binary"
    $results.Add('backend_build=0')
    if (Test-Path $out) { Remove-Item -Force $out -ErrorAction SilentlyContinue }
  } catch {
    Write-Fail "go build frontend_external: $_"
    $results.Add('backend_build=5')
    Set-Exit 5
  } finally {
    Pop-Location
  }
} else {
  Write-Info "skip backend build (-SkipBackendBuild)"
  $results.Add('backend_build=skip')
}

Write-Host ""
Write-Host "SUMMARY exit=$exitCode  $($results -join ' ')"
if ($exitCode -eq 0) {
  Write-Host "All selected steps green — still NOT a production D7 flip." -ForegroundColor Green
} elseif ($exitCode -eq 10) {
  Write-Host "Blocked on credentials or -SkipAuth — G2/G3 not green. See w2-cutover-e2e-credentials.md" -ForegroundColor Yellow
} else {
  Write-Host "One or more steps failed — fix before requesting D7 human gate." -ForegroundColor Red
}
Write-Host "D7 FLIP: NOT EXECUTED"
exit $exitCode
