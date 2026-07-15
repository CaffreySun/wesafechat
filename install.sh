#!/bin/bash
set -e

# Tri-state: unset=ask, true=yes, false=no
INSTALL_MODE=""   # ""=ask, "yes"=auto-install, "no"=skip-install
RUN_MODE=""       # ""=ask, "yes"=auto-run,    "no"=skip-run

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install)    INSTALL_MODE="yes" ;;
        --no-install) INSTALL_MODE="no" ;;
        --run)        RUN_MODE="yes" ;;
        --no-run)     RUN_MODE="no" ;;
        *)
            echo "用法: bash install.sh [--install|--no-install] [--run|--no-run]"
            echo "  --install     自动安装到 /Applications，不询可"
            echo "  --no-install  跳过安装，不询可"
            echo "  --run         安装后自动运行，不询可"
            echo "  --no-run      安装后不运行，不询可"
            echo "  (不传参则全部交互询问)"
            exit 1
            ;;
    esac
    shift
done

BUILD_DIR="build"
APP_NAME="WeSafeChat"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents/MacOS"

if pgrep -x "$APP_NAME" &> /dev/null; then
    echo "==> 终止正在运行的 ${APP_NAME}..."
    pkill -x "$APP_NAME" || true
    sleep 0.5
fi

echo "==> 清理旧构建..."
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS"

echo "==> 编译 ${APP_NAME}..."
swiftc main.swift -o "${CONTENTS}/${APP_NAME}" \
  -framework Cocoa -framework ServiceManagement

echo "==> 复制 Info.plist..."
cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"

echo "==> 生成应用图标..."
ICONSET="${BUILD_DIR}/AppIcon.iconset"
mkdir -p "$ICONSET"
sips -z 16 16   logo.png --out "${ICONSET}/icon_16x16.png"
sips -z 32 32   logo.png --out "${ICONSET}/icon_16x16@2x.png"
sips -z 32 32   logo.png --out "${ICONSET}/icon_32x32.png"
sips -z 64 64   logo.png --out "${ICONSET}/icon_32x32@2x.png"
sips -z 128 128 logo.png --out "${ICONSET}/icon_128x128.png"
sips -z 256 256 logo.png --out "${ICONSET}/icon_128x128@2x.png"
sips -z 256 256 logo.png --out "${ICONSET}/icon_256x256.png"
sips -z 512 512 logo.png --out "${ICONSET}/icon_256x256@2x.png"
sips -z 512 512 logo.png --out "${ICONSET}/icon_512x512.png"
sips -z 1024 1024 logo.png --out "${ICONSET}/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "AppIcon.icns"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
cp AppIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET" AppIcon.icns

echo "==> 构建完成: ${APP_BUNDLE}"

INSTALL_TARGET="/Applications/${APP_NAME}.app"
INSTALLED=false

# ── install phase ──
resolve_install() {
    case "$INSTALL_MODE" in
        yes)
            if [ -d "$INSTALL_TARGET" ]; then
                rm -rf "$INSTALL_TARGET"
            fi
            cp -R "$APP_BUNDLE" /Applications/
            echo "==> 已安装到 ${INSTALL_TARGET}"
            INSTALLED=true
            ;;
        no)
            echo "==> 跳过安装"
            ;;
        *)
            echo ""
            read -r -p "是否安装到 /Applications 目录？(y/n) " install_choice < /dev/tty
            if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
                if [ -d "$INSTALL_TARGET" ]; then
                    rm -rf "$INSTALL_TARGET"
                fi
                cp -R "$APP_BUNDLE" /Applications/
                echo "==> 已安装到 ${INSTALL_TARGET}"
                INSTALLED=true
            fi
            ;;
    esac
}

resolve_install

# ── run phase ──
if $INSTALLED; then
    case "$RUN_MODE" in
        yes)
            open "$INSTALL_TARGET"
            echo "==> 已启动"
            ;;
        no)
            ;;
        *)
            echo ""
            read -r -p "是否立即运行？(y/n) " run_choice < /dev/tty
            if [[ "$run_choice" == "y" || "$run_choice" == "Y" ]]; then
                open "$INSTALL_TARGET"
                echo "==> 已启动"
            fi
            ;;
    esac
fi

echo "==> 完成"
