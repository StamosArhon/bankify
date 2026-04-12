[CmdletBinding()]
param(
  [string]$AvdName,
  [string]$DeviceId,
  [switch]$SkipEmulatorLaunch,
  [switch]$NoPubGet,
  [string]$FlutterPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-Executable {
  param(
    [Parameter(Mandatory = $true)]
    [string]$CommandName,
    [string[]]$FallbackPaths = @()
  )

  foreach ($path in $FallbackPaths) {
    if ($path -and (Test-Path $path)) {
      return $path
    }
  }

  $command = Get-Command $CommandName -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
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

function Get-FlutterFallbackPaths {
  param(
    [string]$RequiredVersion,
    [string]$ConfiguredFlutterPath
  )

  $fallbackPaths = @()

  if ($ConfiguredFlutterPath) {
    if (-not (Test-Path $ConfiguredFlutterPath)) {
      throw "The configured Flutter path '$ConfiguredFlutterPath' does not exist."
    }
    $fallbackPaths += $ConfiguredFlutterPath
  }

  if ($env:FLUTTER_ROOT) {
    $fallbackPaths += Join-Path $env:FLUTTER_ROOT "bin\flutter.bat"
  }

  $pathFlutter = Get-Command flutter -ErrorAction SilentlyContinue
  if ($pathFlutter -and $RequiredVersion) {
    $pathFlutterBin = Split-Path -Parent $pathFlutter.Source
    $pathFlutterRoot = Split-Path -Parent $pathFlutterBin
    $pathFlutterParent = Split-Path -Parent $pathFlutterRoot
    $fallbackPaths += Join-Path $pathFlutterParent "flutter-$RequiredVersion\bin\flutter.bat"
  }

  return @(
    $fallbackPaths |
      Where-Object { $_ } |
      Select-Object -Unique
  )
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
$flutterFallbackPaths = Get-FlutterFallbackPaths `
  -RequiredVersion $requiredFlutterVersion `
  -ConfiguredFlutterPath $FlutterPath
$flutterPath = Resolve-Executable `
  -CommandName "flutter" `
  -FallbackPaths $flutterFallbackPaths
$adbPath = Resolve-Executable -CommandName "adb" -FallbackPaths @(
  $(if ($sdkRoot) { Join-Path $sdkRoot "platform-tools\adb.exe" })
)
$emulatorPath = Resolve-Executable -CommandName "emulator" -FallbackPaths @(
  $(if ($sdkRoot) { Join-Path $sdkRoot "emulator\emulator.exe" })
)

if (-not $flutterPath) {
  throw "Flutter was not found. Install Flutter $requiredFlutterVersion, set FLUTTER_ROOT, or pass -FlutterPath with the SDK's flutter.bat path."
}

if (-not $adbPath) {
  throw "adb was not found. Install Android Studio + Android SDK Platform Tools, or add adb to PATH."
}

$flutterVersion = $null
$dartVersion = $null
if ($requiredFlutterVersion) {
  try {
    $versionInfo = & $flutterPath --version --machine | ConvertFrom-Json
    $flutterVersion = $versionInfo.frameworkVersion
    $dartVersion = $versionInfo.dartSdkVersion
    if ($flutterVersion -ne $requiredFlutterVersion) {
      throw "This repo requires Flutter $requiredFlutterVersion, but PATH currently resolves to Flutter $flutterVersion (Dart $dartVersion). Install or switch to Flutter $requiredFlutterVersion, then rerun this script."
    }
  } catch {
    if ($_.Exception.Message -like "This repo requires Flutter*") {
      throw
    }

    Write-Warning "Could not verify the local Flutter version automatically."
  }
}

Push-Location $projectRoot
try {
  Write-Host "Using Flutter executable '$flutterPath'." -ForegroundColor Green

  if (-not $NoPubGet) {
    Write-Host "Running flutter pub get..." -ForegroundColor Cyan
    & $flutterPath pub get
    if ($LASTEXITCODE -ne 0) {
      if ($requiredFlutterVersion -and $flutterVersion) {
        throw "flutter pub get failed while using Flutter $flutterVersion. Confirm that Flutter $requiredFlutterVersion is active and rerun the script."
      }

      throw "flutter pub get failed. Fix the dependency/toolchain error above, then rerun the script."
    }
  }

  $runningDevices = @(Get-RunningAndroidDevices -AdbPath $adbPath)
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
      $runningDevices = @(Get-RunningAndroidDevices -AdbPath $adbPath)
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
  if ($LASTEXITCODE -ne 0) {
    throw "flutter run failed. Fix the build/runtime error above, then rerun the script."
  }
} finally {
  Pop-Location
}
