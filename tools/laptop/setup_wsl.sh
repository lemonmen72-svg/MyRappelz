#!/usr/bin/env bash
# Настройка ноутбука Максима как исполнителя GitHub Actions (метка laptop) внутри WSL2 Ubuntu.
# Запускает tools/laptop/install.ps1 (из Windows, от root): повторный запуск безопасен — сделанное пропускается.
#   setup_wsl.sh --token <ключ исполнителя> [--adb </mnt/c/.../adb.exe>]
# Код выхода 3 — systemd ещё не работает: install.ps1 перезапускает WSL и вызывает скрипт снова.
set -euo pipefail

REPO_URL="https://github.com/lemonmen72-svg/MyRappelz"
USER_NAME="runner"
HOME_DIR="/home/$USER_NAME"
RUNNER_DIR="$HOME_DIR/actions-runner"
SDK="/opt/android-sdk"
TOKEN=""
WIN_ADB=""
while [ $# -gt 0 ]; do
	case "$1" in
		--token) TOKEN="$2"; shift 2 ;;
		--adb) WIN_ADB="$2"; shift 2 ;;
		*) echo "неизвестный параметр $1"; exit 2 ;;
	esac
done
[ "$(id -u)" = "0" ] || { echo "нужен root (install.ps1 запускает так сам)"; exit 2; }

say() { echo; echo "=== $* ==="; }

# 1. systemd — служба исполнителя стартует сама вместе с WSL
if ! grep -q "^systemd=true" /etc/wsl.conf 2>/dev/null; then
	say "Включаю systemd в WSL"
	printf '[boot]\nsystemd=true\n' > /etc/wsl.conf
fi
if [ "$(ps -p 1 -o comm= | tr -d ' ')" != "systemd" ]; then
	echo "systemd ещё не запущен — нужен перезапуск WSL"
	exit 3
fi

# 2. Пакеты (как на серверах GitHub: python3, unzip, zstd, Java 17, xvfb — для скриншотов, если понадобятся)
say "Пакеты Ubuntu"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git curl ca-certificates unzip zip zstd xz-utils jq rsync python3 python3-yaml \
	openjdk-17-jdk-headless xvfb libgl1-mesa-dri libfontconfig1 sudo >/dev/null
JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"

# 3. Пользователь исполнителя (GitHub не запускает исполнитель от root); sudo без пароля — шаги CI ставят пакеты
if ! id "$USER_NAME" >/dev/null 2>&1; then
	say "Пользователь $USER_NAME"
	useradd -m -s /bin/bash "$USER_NAME"
fi
echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-runner
chmod 440 /etc/sudoers.d/90-runner

# 4. Android SDK для сборки APK (платформа 34, build-tools 34.0.0, NDK 23.2 — как в android-apk.yml)
if [ ! -x "$SDK/cmdline-tools/latest/bin/sdkmanager" ]; then
	say "Android SDK (≈ 3 ГБ, несколько минут)"
	mkdir -p "$SDK/cmdline-tools"
	curl -fsSL -o /tmp/cmdtools.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
	rm -rf "$SDK/cmdline-tools/latest" /tmp/cmdline-tools
	unzip -q /tmp/cmdtools.zip -d /tmp
	mv /tmp/cmdline-tools "$SDK/cmdline-tools/latest"
	rm -f /tmp/cmdtools.zip
fi
if [ ! -d "$SDK/ndk/23.2.8568313" ]; then
	yes | JAVA_HOME="$JAVA_HOME" "$SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK" --licenses >/dev/null || true
	JAVA_HOME="$JAVA_HOME" "$SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK" \
		"platform-tools" "platforms;android-34" "build-tools;34.0.0" "ndk;23.2.8568313" >/dev/null
fi
chown -R "$USER_NAME:$USER_NAME" "$SDK"

# 5. Исполнитель GitHub Actions
if [ ! -f "$RUNNER_DIR/.runner" ]; then
	[ -n "$TOKEN" ] || { echo "нужен ключ исполнителя (--token)"; exit 2; }
	say "Исполнитель GitHub Actions"
	VER=$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name | sed 's/^v//')
	mkdir -p "$RUNNER_DIR"
	curl -fsSL -o /tmp/runner.tgz "https://github.com/actions/runner/releases/download/v${VER}/actions-runner-linux-x64-${VER}.tar.gz"
	tar xzf /tmp/runner.tgz -C "$RUNNER_DIR"
	rm -f /tmp/runner.tgz
	"$RUNNER_DIR/bin/installdependencies.sh" >/dev/null
	chown -R "$USER_NAME:$USER_NAME" "$RUNNER_DIR"
	sudo -u "$USER_NAME" bash -c "cd '$RUNNER_DIR' && ./config.sh --unattended --url '$REPO_URL' --token '$TOKEN' \
		--name 'laptop-$(hostname)' --labels laptop --work _work --replace"
fi

# Переменные для шагов сборки (исполнитель читает .env при старте)
cat > "$RUNNER_DIR/.env" <<ENV
LANG=C.UTF-8
ANDROID_HOME=$SDK
ANDROID_SDK_ROOT=$SDK
JAVA_HOME=$JAVA_HOME
WIN_ADB=$WIN_ADB
ENV
chown "$USER_NAME:$USER_NAME" "$RUNNER_DIR/.env"

# 6. Служба (systemd): стартует вместе с WSL, перезапускается при сбое
cd "$RUNNER_DIR"
if ! ls /etc/systemd/system/actions.runner.*.service >/dev/null 2>&1; then
	say "Служба исполнителя"
	./svc.sh install "$USER_NAME"
fi
./svc.sh start || true
sleep 3
./svc.sh status | head -n 12 || true
say "Готово: исполнитель laptop-$(hostname) работает"
