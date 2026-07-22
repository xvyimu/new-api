# T-TH-003 · web-console /logs live smoke (API layer)
# Does NOT cut over production; no DELETE; secrets only via env.
#
# Auth (pick one):
#   A) Access token (admin or user console token):
#        $env:TH_ACCESS_TOKEN = '<users.access_token>'
#        $env:TH_USER_ID = '1'   # New-Api-User
#   B) Password login (session cookie + New-Api-User from login body):
#        $env:TH_E2E_USER = '...'
#        $env:TH_E2E_PASS = '...'
#
# Optional:
#   $env:TH_API_BASE = 'http://127.0.0.1:3000'
#
# Exit codes:
#   0 pass
#   1 auth failed / logs not parseable
#   2 unexpected HTTP / success:false on authorized path
#   3 backend unreachable
#   4 missing credentials (status still checked; report blocked-auth)

param(
  [string]$ApiBase = $(if ($env:TH_API_BASE) { $env:TH_API_BASE } else { 'http://127.0.0.1:3000' })
)

$ErrorActionPreference = 'Stop'
$ApiBase = $ApiBase.TrimEnd('/')

function Write-Step([string]$msg) { Write-Host "==> $msg" }
function Write-Ok([string]$msg) { Write-Host "OK  $msg" }
function Write-Warn([string]$msg) { Write-Host "WARN $msg" }
function Write-Fail([string]$msg) { Write-Host "FAIL $msg" }

function Invoke-Json {
  param(
    [string]$Method = 'GET',
    [Parameter(Mandatory)][string]$Url,
    [hashtable]$Headers = @{},
    [string]$Body = $null,
    $WebSession = $null
  )
  $params = @{
    Uri             = $Url
    Method          = $Method
    Headers         = $Headers
    UseBasicParsing = $true
    TimeoutSec      = 20
  }
  if ($WebSession) { $params.WebSession = $WebSession }
  if ($null -ne $Body) {
    $params.Body = $Body
    $params.ContentType = 'application/json; charset=utf-8'
  }
  # PS7+: SkipHttpErrorCheck keeps 4xx body; PS5 may throw — catch below.
  try {
    if ((Get-Command Invoke-WebRequest).Parameters.ContainsKey('SkipHttpErrorCheck')) {
      $params.SkipHttpErrorCheck = $true
    }
    $resp = Invoke-WebRequest @params
  } catch {
    $r = $_.Exception.Response
    if (-not $r) { throw }
    $reader = New-Object System.IO.StreamReader($r.GetResponseStream())
    $text = $reader.ReadToEnd()
    return [pscustomobject]@{
      StatusCode = [int]$r.StatusCode
      Content    = $text
      Json       = $(try { $text | ConvertFrom-Json } catch { $null })
    }
  }
  $content = $resp.Content
  return [pscustomobject]@{
    StatusCode = [int]$resp.StatusCode
    Content    = $content
    Json       = $(try { $content | ConvertFrom-Json } catch { $null })
  }
}

function Assert-LogListShape {
  param($Json, [string]$Label)
  if (-not $Json) { throw "${Label}: empty JSON" }
  if ($Json.success -ne $true) {
    throw "${Label}: success!=true message=$($Json.message)"
  }
  $data = $Json.data
  if (-not $data) { throw "${Label}: missing data" }
  $items = $data.items
  if ($null -eq $items) { throw "${Label}: missing data.items" }
  if (-not ($items -is [System.Array] -or $items.GetType().Name -eq 'Object[]')) {
    # single-element may deserialize as non-array in edge cases
    if ($items -isnot [System.Collections.IEnumerable] -or $items -is [string]) {
      throw "${Label}: data.items not list-like"
    }
  }
  $count = @($items).Count
  $total = $data.total
  Write-Ok "$Label items=$count total=$total page=$($data.page) page_size=$($data.page_size)"
  if ($count -gt 0) {
    $first = @($items)[0]
    $need = @('id', 'type', 'created_at')
    foreach ($k in $need) {
      if (-not ($first.PSObject.Properties.Name -contains $k)) {
        throw "${Label}: item missing field $k"
      }
    }
    Write-Ok ("${Label} sample id={0} type={1} model={2} user={3}" -f `
        $first.id, $first.type, $first.model_name, $first.username)
  }
}

# --- 1) health / status ---
Write-Step "GET $ApiBase/api/status"
try {
  $st = Invoke-Json -Url "$ApiBase/api/status"
} catch {
  Write-Fail "backend unreachable: $_"
  exit 3
}
if ($st.StatusCode -ne 200 -or $st.Json.success -ne $true) {
  Write-Fail "status HTTP $($st.StatusCode) body=$($st.Content.Substring(0, [Math]::Min(200, $st.Content.Length)))"
  exit 3
}
$ver = $st.Json.data.version
$setup = $st.Json.data.setup
Write-Ok "status version=$ver setup=$setup"

Write-Step "GET $ApiBase/healthz"
$hz = Invoke-Json -Url "$ApiBase/healthz"
if ($hz.StatusCode -ne 200) {
  Write-Fail "healthz HTTP $($hz.StatusCode)"
  exit 3
}
Write-Ok "healthz 200"

# --- 2) unauth must not list ---
Write-Step "GET /api/log/ unauthenticated (expect 401 or success:false)"
$unauth = Invoke-Json -Url "$ApiBase/api/log/?p=1&page_size=1"
if ($unauth.StatusCode -eq 200 -and $unauth.Json.success -eq $true) {
  Write-Fail "unauth log list unexpectedly succeeded"
  exit 2
}
Write-Ok "unauth blocked HTTP=$($unauth.StatusCode) success=$($unauth.Json.success)"

# --- 3) credentials ---
$token = $env:TH_ACCESS_TOKEN
if (-not $token) { $token = $env:TH_SMOKE_TOKEN }
$uid = $env:TH_USER_ID
if (-not $uid) { $uid = $env:TH_SMOKE_USER_ID }
$user = $env:TH_E2E_USER
if (-not $user) { $user = $env:TH_SMOKE_USER }
$pass = $env:TH_E2E_PASS
if (-not $pass) { $pass = $env:TH_SMOKE_PASS }

$headers = @{}
$sess = $null
$authMode = $null

if ($token) {
  if (-not $uid) {
    Write-Fail "TH_ACCESS_TOKEN set but TH_USER_ID missing (New-Api-User required)"
    exit 4
  }
  $headers = @{
    Authorization   = $token
    'New-Api-User'  = "$uid"
  }
  $authMode = "access_token+New-Api-User($uid)"
  Write-Step "auth mode: $authMode"
} elseif ($user -and $pass) {
  Write-Step "POST /api/user/login as $user"
  $body = @{ username = $user; password = $pass } | ConvertTo-Json
  $login = Invoke-WebRequest -Uri "$ApiBase/api/user/login" -Method POST -Body $body `
    -ContentType 'application/json; charset=utf-8' -SessionVariable sess `
    -UseBasicParsing -TimeoutSec 15
  $lj = $login.Content | ConvertFrom-Json
  if (-not $lj.success) {
    Write-Fail "login failed: $($login.Content)"
    exit 1
  }
  $uid = $lj.data.id
  if (-not $uid) {
    Write-Fail "login missing data.id"
    exit 1
  }
  $headers = @{ 'New-Api-User' = "$uid" }
  $authMode = "session+New-Api-User($uid) role=$($lj.data.role)"
  Write-Ok "login $authMode"
} else {
  Write-Warn "no TH_ACCESS_TOKEN/TH_USER_ID and no TH_E2E_USER/TH_E2E_PASS — auth steps blocked"
  Write-Host "RESULT blocked-auth (status OK; provide credentials to complete logs smoke)"
  exit 4
}

# --- 4) self probe ---
Write-Step "GET /api/user/self"
$self = Invoke-Json -Url "$ApiBase/api/user/self" -Headers $headers -WebSession $sess
if ($self.StatusCode -ne 200 -or $self.Json.success -ne $true) {
  Write-Fail "self failed HTTP=$($self.StatusCode) body=$($self.Content.Substring(0, [Math]::Min(240, $self.Content.Length)))"
  exit 1
}
$role = $self.Json.data.role
Write-Ok "self username=$($self.Json.data.username) role=$role id=$($self.Json.data.id)"

# --- 5) admin list ---
Write-Step "GET /api/log/?p=1&page_size=5"
$adminLogs = Invoke-Json -Url "$ApiBase/api/log/?p=1&page_size=5" -Headers $headers -WebSession $sess
$adminOk = $false
if ($adminLogs.StatusCode -eq 200 -and $adminLogs.Json.success -eq $true) {
  try {
    Assert-LogListShape -Json $adminLogs.Json -Label 'admin /api/log/'
    $adminOk = $true
  } catch {
    Write-Fail "$_"
    exit 2
  }
} else {
  Write-Warn "admin list not OK HTTP=$($adminLogs.StatusCode) success=$($adminLogs.Json.success) msg=$($adminLogs.Json.message)"
  # Prefer-admin fallback shape used by web-console listLogs:
  # HTTP 200 + success:false (or 401/403) → try /self
  if ($adminLogs.StatusCode -in 401, 403 -or ($adminLogs.StatusCode -eq 200 -and $adminLogs.Json.success -eq $false)) {
    Write-Ok "admin path failure shape matches listLogs fallback trigger"
  } else {
    Write-Fail "admin path unexpected failure shape"
    exit 2
  }
}

# --- 6) self list ---
Write-Step "GET /api/log/self?p=1&page_size=5"
$selfLogs = Invoke-Json -Url "$ApiBase/api/log/self?p=1&page_size=5" -Headers $headers -WebSession $sess
if ($selfLogs.StatusCode -ne 200 -or $selfLogs.Json.success -ne $true) {
  Write-Fail "self logs failed HTTP=$($selfLogs.StatusCode) body=$($selfLogs.Content.Substring(0, [Math]::Min(240, $selfLogs.Content.Length)))"
  exit 1
}
try {
  Assert-LogListShape -Json $selfLogs.Json -Label 'user /api/log/self'
} catch {
  Write-Fail "$_"
  exit 2
}

# --- 7) type filter (consume=2) ---
Write-Step "GET /api/log/?type=2&p=1&page_size=2 (if admin path works)"
if ($adminOk) {
  $typed = Invoke-Json -Url "$ApiBase/api/log/?p=1&page_size=2&type=2" -Headers $headers -WebSession $sess
  if ($typed.StatusCode -eq 200 -and $typed.Json.success -eq $true) {
    Assert-LogListShape -Json $typed.Json -Label 'admin type=2'
  } else {
    Write-Warn "type filter skip/fail HTTP=$($typed.StatusCode)"
  }
}

Write-Step "PASS smoke-logs auth=$authMode adminList=$adminOk"
exit 0
