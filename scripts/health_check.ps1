param(
  [string]$NodeUrl = "http://localhost:8090/health",
  [string]$DartUrl = "http://localhost:8081/health",
  [string]$MysqlHost = "127.0.0.1",
  [int]$MysqlPort = 3306
)

$ErrorActionPreference = "Stop"

function Write-Status {
  param(
    [string]$Name,
    [bool]$Ok,
    [string]$Detail
  )
  $state = if ($Ok) { "OK" } else { "FAIL" }
  Write-Host ("[{0}] {1} - {2}" -f $state, $Name, $Detail)
}

function Test-TcpPort {
  param(
    [string]$HostName,
    [int]$Port
  )

  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $iar = $client.BeginConnect($HostName, $Port, $null, $null)
    $ok = $iar.AsyncWaitHandle.WaitOne(1200, $false)
    if (-not $ok) {
      return $false
    }
    $client.EndConnect($iar)
    return $true
  } catch {
    return $false
  } finally {
    $client.Close()
  }
}

$failed = 0

# MySQL
$mysqlOk = Test-TcpPort -HostName $MysqlHost -Port $MysqlPort
Write-Status -Name "MySQL" -Ok $mysqlOk -Detail "${MysqlHost}:${MysqlPort}"
if (-not $mysqlOk) { $failed++ }

# Node API
try {
  $nodeResponse = Invoke-RestMethod -Method Get -Uri $NodeUrl -TimeoutSec 3
  $nodeOk = $nodeResponse.ok -eq $true
  Write-Status -Name "Node API" -Ok $nodeOk -Detail $NodeUrl
  if (-not $nodeOk) { $failed++ }
} catch {
  Write-Status -Name "Node API" -Ok $false -Detail $NodeUrl
  $failed++
}

# Dart OTP API
try {
  $dartResponse = Invoke-RestMethod -Method Get -Uri $DartUrl -TimeoutSec 3
  $dartOk = $dartResponse.ok -eq $true
  Write-Status -Name "Dart OTP API" -Ok $dartOk -Detail $DartUrl
  if (-not $dartOk) { $failed++ }
} catch {
  Write-Status -Name "Dart OTP API" -Ok $false -Detail $DartUrl
  $failed++
}

# Flutter tool
try {
  $null = flutter --version
  Write-Status -Name "Flutter SDK" -Ok $true -Detail "flutter --version"
} catch {
  Write-Status -Name "Flutter SDK" -Ok $false -Detail "No disponible en PATH"
  $failed++
}

if ($failed -gt 0) {
  Write-Host ""
  Write-Host "Resultado: $failed chequeos fallaron."
  exit 1
}

Write-Host ""
Write-Host "Resultado: todo OK. Ya puedes probar login/registro/reset."
