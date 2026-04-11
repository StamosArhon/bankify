[CmdletBinding()]
param(
  [string]$AvdName,
  [string]$DeviceId,
  [switch]$SkipEmulatorLaunch,
  [switch]$NoPubGet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-Executable {
  param(
    [Parameter(Mandatory = $true)]
    [string]$CommandName,
    [string[]]$FallbackPaths = @()
  )

  $command = Get-Command $CommandName -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  foreach ($path in $FallbackPaths) {
    if ($path -and (Test-Path $path)) {
      return $path
    }
  }

  return $null
}

function Get-AndroidSdkRoot {
  $candidates = @(
    $env:ANDROID_SDK_ROOT,
    $env:ANDROID_HOME,
    (Join-Path $env:LOCALAPPDATA "Android\Sdk")
  ) | Where-Object { $_ }

  foreach ($candidate in $candidates) {
    if (Test-Path $candidate) {
      return $candidate
    }
  }

  return $null
}

function Get-RequiredFlutterVersion {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PubspecPath
  )

  $pubspec = Get-Content $PubspecPath -Raw
  $match = [regex]::Match(
    $pubspec,
    "(?ms)^environment:\s*.*?^\s*flutter:\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$"
  )
  if ($match.Success) {
    return $match.Groups[1].Value
  }

  return $null
}

function Get-RunningAndroidDevices {
  param(
    [Parameter(Mandatory = $true)]
    [string]$AdbPath
  )

  $lines = & $AdbPath devices
  return @(
    $lines |
      Select-Object -Skip 1 |
      Where-Object { $_ -match "\sdevice$" } |
      ForEach-Object { ($_ -split "\s+")[0] }
  )
}

function Wait-ForAndroidBoot {
  param(
    [Parameter(Mandatory = $true)]
    [string]$AdbPath,
    [Parameter(Mandatory = $true)]
    [string]$TargetDevice
  )

  & $AdbPath -s $TargetDevice wait-for-device | Out-Null
  for ($attempt = 0; $attempt -lt 180; $attempt++) {
    $bootCompleted = (& $AdbPath -s $TargetDevice shell getprop sys.boot_completed 2>$null).Trim()
    if ($bootCompleted -eq "1") {
      return
    }
    Start-Sleep -Seconds 2
  }

  throw "Android emulator '$TargetDevice' did not finish booting in time."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $projectRoot "pubspec.yaml"
$requiredFlutterVersion = Get-RequiredFlutterVersion -PubspecPath $pubspecPath

$sdkRoot = Get-AndroidSdkRoot
$flutterPath = Resolve-Executable -CommandName "flutter" -FallbackPaths @()
$adbPath = Resolve-Executable -CommandName "adb" -FallbackPaths @(
  $(if ($sdkRoot) { Join-Path $sdkRoot "platform-tools\adb.exe" })
)
$emulatorPath = Resolve-Executable -CommandName "emulator" -FallbackPaths @(
  $(if ($sdkRoot) { Join-Path $sdkRoot "emulator\emulator.exe" })
)

if (-not $flutterPath) {
  throw "Flutter was not found in PATH. Install Flutter $requiredFlutterVersion and make sure 'flutter' is available."
}

if (-not $adbPath) {
  throw "adb was not found. Install Android Studio + Android SDK Platform Tools, or add adb to PATH."
}

if ($requiredFlutterVersion) {
  try {
    $flutterVersion = (& $flutterPath --version --machine | ConvertFrom-Json).frameworkVersion
    if ($flutterVersion -ne $requiredFlutterVersion) {
      Write-Warning "This repo expects Flutter $requiredFlutterVersion, but PATH currently resolves to Flutter $flutterVersion."
    }
  } catch {
    Write-Warning "Could not verify the local Flutter version automatically."
  }
}

Push-Location $projectRoot
try {
  if (-not $NoPubGet) {
    Write-Host "Running flutter pub get..." -ForegroundColor Cyan
    & $flutterPath pub get
  }

  $runningDevices = Get-RunningAndroidDevices -AdbPath $adbPath
  $targetDevice = $DeviceId

  if (-not $targetDevice -and $runningDevices.Count -gt 0) {
    $targetDevice = $runningDevices[0]
  }

  if (-not $targetDevice -and -not $SkipEmulatorLaunch) {
    if (-not $emulatorPath) {
      throw "No running Android device was found and the emulator binary is unavailable. Install the Android Emulator or add it to PATH."
    }

    if (-not $AvdName) {
      $availableAvds = @(& $emulatorPath -list-avds)
      if (-not $availableAvds -or $availableAvds.Count -eq 0) {
        throw "No Android Virtual Devices were found. Create one in Android Studio Device Manager first."
      }
      $AvdName = $availableAvds[0]
      Write-Host "No -AvdName provided. Using first available AVD: $AvdName" -ForegroundColor Yellow
    }

    Write-Host "Launching Android emulator '$AvdName'..." -ForegroundColor Cyan
    Start-Process -FilePath $emulatorPath -ArgumentList "-avd", $AvdName | Out-Null

    for ($attempt = 0; $attempt -lt 30; $attempt++) {
      Start-Sleep -Seconds 2
      $runningDevices = Get-RunningAndroidDevices -AdbPath $adbPath
      if ($runningDevices.Count -gt 0) {
        $targetDevice = $runningDevices[0]
        break
      }
    }

    if (-not $targetDevice) {
      throw "The Android emulator did not appear in adb devices."
    }

    Write-Host "Waiting for emulator '$targetDevice' to finish booting..." -ForegroundColor Cyan
    Wait-ForAndroidBoot -AdbPath $adbPath -TargetDevice $targetDevice
  }

  if (-not $targetDevice) {
    throw "No Android device/emulator is available. Start one manually or run this script without -SkipEmulatorLaunch."
  }

  Write-Host "Using Android device '$targetDevice'." -ForegroundColor Green
  Write-Host "Starting Flutter with hot reload enabled. Use 'r' for hot reload and 'R' for hot restart." -ForegroundColor Green
  & $flutterPath run -d $targetDevice
} finally {
  Pop-Location
}
