$ErrorActionPreference = 'Stop'

function Test-CleanRepo {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Name
  )

  Push-Location $Path
  try {
    $status = git status --porcelain
    if ($LASTEXITCODE -ne 0) {
      throw "No se pudo leer estado git de $Name"
    }

    if ($status) {
      Write-Host "[BLOCKED] $Name tiene cambios sin commit:" -ForegroundColor Red
      git status --short | Out-Host
      return $false
    }

    Write-Host "[OK] $Name limpio" -ForegroundColor Green
    return $true
  }
  finally {
    Pop-Location
  }
}

$root = Split-Path -Parent $PSScriptRoot
$appOk = Test-CleanRepo -Path $root -Name 'APP'
$backendOk = Test-CleanRepo -Path (Join-Path $root 'backend') -Name 'BACKEND'

if (-not ($appOk -and $backendOk)) {
  Write-Host "\nDeploy bloqueado: limpia/guarda cambios antes de desplegar." -ForegroundColor Red
  exit 1
}

Write-Host "\nSafe to deploy: ambos repos limpios." -ForegroundColor Green
exit 0
