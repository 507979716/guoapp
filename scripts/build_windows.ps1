$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot
if (-not $env:GOPROXY) { $env:GOPROXY = "https://goproxy.cn,direct" }
if (-not $env:GOSUMDB) { $env:GOSUMDB = "off" }
python scripts/build_native.py --platform windows
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter pub get --enforce-lockfile
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
flutter build windows --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python scripts/package_release.py --platform windows
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
