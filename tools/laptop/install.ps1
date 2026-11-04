# Dark Pact: ноутбук Максима — исполнитель GitHub Actions (автотесты и сборка APK сами, без команд).
# Запуск один раз (PowerShell от имени администратора, из папки репозитория):
#   powershell -ExecutionPolicy Bypass -File tools\laptop\install.ps1
# Повторный запуск безопасен. Если попросит перезагрузку — перезагрузите ПК и запустите снова.
$ErrorActionPreference = "Stop"
$Distro = "Ubuntu-24.04"

function Say($t) { Write-Host ""; Write-Host "=== $t ===" -ForegroundColor Cyan }

# Администратор
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
	[Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { Write-Host "Запустите PowerShell от имени администратора." -ForegroundColor Red; exit 1 }

# 1. WSL2
Say "Проверка WSL"
$wslOk = $true
try { wsl.exe --status *> $null; if ($LASTEXITCODE -ne 0) { $wslOk = $false } } catch { $wslOk = $false }
if (-not $wslOk) {
	Say "Устанавливаю WSL (нужна перезагрузка)"
	wsl.exe --install --no-distribution
	Write-Host "Перезагрузите компьютер и запустите этот скрипт ещё раз." -ForegroundColor Yellow
	exit 0
}
wsl.exe --set-default-version 2 | Out-Null

# 2. Ubuntu без вопросов (пользователь root; исполнитель потом работает от своего пользователя runner)
$have = (wsl.exe -l -q) -replace "`0", "" | Where-Object { $_.Trim() -eq $Distro }
if (-not $have) {
	Say "Устанавливаю $Distro"
	wsl.exe --install -d $Distro --no-launch
	$launcher = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\ubuntu2404.exe"
	if (Test-Path $launcher) { & $launcher install --root } else { wsl.exe -d $Distro -u root -- true }
	if ($LASTEXITCODE -ne 0) {
		Write-Host "Ubuntu не установилась. Если просили перезагрузку — перезагрузите ПК и запустите снова." -ForegroundColor Yellow
		exit 1
	}
}

# 3. WSL не засыпает (иначе исполнитель «пропадает», пока ноутбук включён)
$cfg = Join-Path $env:USERPROFILE ".wslconfig"
if (Test-Path $cfg) { Copy-Item $cfg "$cfg.bak" -Force }
@"
[wsl2]
memory=16GB
processors=4
vmIdleTimeout=-1

[general]
instanceIdleTimeout=-1
"@ | Set-Content -Path $cfg -Encoding ASCII

# 4. Ключ исполнителя: GitHub → репозиторий → Settings → Actions → Runners → New self-hosted runner → Linux,
#    строка ./config.sh … --token XXXX — скопируйте XXXX (действует час)
$runnerDone = (wsl.exe -d $Distro -u root -- bash -c "test -f /home/runner/actions-runner/.runner && echo yes") -eq "yes"
$token = ""
if (-not $runnerDone) {
	Write-Host ""
	Write-Host "Откройте https://github.com/lemonmen72-svg/MyRappelz/settings/actions/runners/new?arch=x64&os=linux"
	Write-Host "и скопируйте ключ из строки «./config.sh --url ... --token КЛЮЧ»."
	$token = Read-Host "Вставьте ключ"
	if (-not $token) { Write-Host "Ключ не введён." -ForegroundColor Red; exit 1 }
}

# 5. adb из Android Studio — APK сам ставится на подключённый телефон
$adbWin = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
$adbWsl = ""
if (Test-Path $adbWin) { $adbWsl = (wsl.exe -d $Distro -u root -- wslpath -a ($adbWin -replace "\\", "/")).Trim() }
else { Write-Host "adb Android Studio не найден — установка APK на телефон будет пропускаться." -ForegroundColor Yellow }

# 6. Настройка внутри Ubuntu (systemd, Android SDK, исполнитель, служба)
$script = (wsl.exe -d $Distro -u root -- wslpath -a ((Join-Path $PSScriptRoot "setup_wsl.sh") -replace "\\", "/")).Trim()
for ($i = 0; $i -lt 2; $i++) {
	Say "Настройка Ubuntu (первый раз — 10–20 минут)"
	$wslArgs = @("-d", $Distro, "-u", "root", "--", "bash", $script)
	if ($token) { $wslArgs += @("--token", $token) }
	if ($adbWsl) { $wslArgs += @("--adb", $adbWsl) }
	& wsl.exe @wslArgs
	if ($LASTEXITCODE -eq 3) { Say "Перезапуск WSL (systemd)"; wsl.exe --shutdown; Start-Sleep 5; continue }
	if ($LASTEXITCODE -ne 0) { Write-Host "Ошибка настройки (код $LASTEXITCODE)." -ForegroundColor Red; exit 1 }
	break
}

# 7. Автозапуск при входе в Windows: WSL поднимается скрыто, служба исполнителя стартует сама
$startup = [Environment]::GetFolderPath("Startup")
$vbs = Join-Path $startup "dark_pact_runner.vbs"
"CreateObject(""WScript.Shell"").Run ""wsl.exe -d $Distro -u root --exec /bin/sleep infinity"", 0, False" |
	Set-Content -Path $vbs -Encoding ASCII
Start-Process wscript.exe $vbs

Say "Готово"
Write-Host "Исполнитель «laptop» установлен и запускается сам при входе в Windows."
Write-Host "Напишите Claude: «исполнитель установлен» — он переключит проверки и сборку на ноутбук."
