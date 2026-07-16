#!/bin/bash
set -e

LINK_MODE=""      # ""=skip, "yes"=create symlink

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install)    INSTALL_MODE="yes" ;;
        --no-install) INSTALL_MODE="no" ;;
        --run)        RUN_MODE="yes" ;;
        --no-run)     RUN_MODE="no" ;;
        --link)       LINK_MODE="yes" ;;
        --output)
            shift
            if [[ -z "${1:-}" ]]; then
                echo "错误: --output 需要指定目录" >&2
                exit 1
            fi
            BUILD_DIR="$1"
            # 尝试创建目录以检查权限
            mkdir -p "$BUILD_DIR" 2>/dev/null || {
                echo "错误: 无法创建输出目录 $BUILD_DIR" >&2
                exit 1
            }
            if [[ ! -w "$BUILD_DIR" ]]; then
                echo "错误: 输出目录不可写: $BUILD_DIR" >&2
                exit 1
            fi
            ;;
        *)
            echo "用法: bash install.sh [--install|--no-install] [--run|--no-run] [--output <dir>] [--link]"
            echo "  --install     自动安装到 /Applications，不询可"
            echo "  --no-install  跳过安装，不询可"
            echo "  --run         安装后自动运行，不询可"
            echo "  --no-run      安装后不运行，不询可"
            echo "  --output      指定 .app 输出目录 (默认: build)"
            echo "  --link        创建软链接到 /Applications"
            echo "  (不传参则全部交互询问)"
            exit 1
            ;;
    esac
    shift
done

BUILD_DIR="${BUILD_DIR:-build}"
APP_NAME="WeSafeChat"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents/MacOS"

kill_running() {
    if pgrep -x "$APP_NAME" &> /dev/null; then
        echo "==> 终止正在运行的 ${APP_NAME}..."
        pkill -x "$APP_NAME" || true
        sleep 0.5
    fi
}

echo "==> 清理旧构建..."
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS"

echo "==> 编译 ${APP_NAME}..."
swiftc main.swift src/*.swift -o "${CONTENTS}/${APP_NAME}" \
  -framework Cocoa -framework ServiceManagement

echo "==> 复制 Info.plist..."
BUILD_VERSION=$(date +%y%m%d%H%M)
cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_VERSION}" "${APP_BUNDLE}/Contents/Info.plist"
echo "    CFBundleVersion = ${BUILD_VERSION}"

echo "==> 生成应用图标..."
ICONSET="${BUILD_DIR}/AppIcon.iconset"
mkdir -p "$ICONSET"
sips -z 16 16   resources/logo.png --out "${ICONSET}/icon_16x16.png"
sips -z 32 32   resources/logo.png --out "${ICONSET}/icon_16x16@2x.png"
sips -z 32 32   resources/logo.png --out "${ICONSET}/icon_32x32.png"
sips -z 64 64   resources/logo.png --out "${ICONSET}/icon_32x32@2x.png"
sips -z 128 128 resources/logo.png --out "${ICONSET}/icon_128x128.png"
sips -z 256 256 resources/logo.png --out "${ICONSET}/icon_128x128@2x.png"
sips -z 256 256 resources/logo.png --out "${ICONSET}/icon_256x256.png"
sips -z 512 512 resources/logo.png --out "${ICONSET}/icon_256x256@2x.png"
sips -z 512 512 resources/logo.png --out "${ICONSET}/icon_512x512.png"
sips -z 1024 1024 resources/logo.png --out "${ICONSET}/icon_512x512@2x.png"
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
            kill_running
            open "$INSTALL_TARGET"
            echo "==> 已启动"
            ;;
        no)
            ;;
        *)
            echo ""
            read -r -p "是否立即运行？(y/n) " run_choice < /dev/tty
            if [[ "$run_choice" == "y" || "$run_choice" == "Y" ]]; then
                kill_running
                open "$INSTALL_TARGET"
                echo "==> 已启动"
            fi
            ;;
    esac
fi


# ── link phase ──
link_target="/Applications/${APP_NAME}.app"
if [[ "$LINK_MODE" == "yes" ]]; then
    if [[ -e "$link_target" || -L "$link_target" ]]; then
        rm -rf "$link_target"
    fi
    ln -sf "$APP_BUNDLE" "$link_target"
    echo "==> 已链接到 ${link_target}"
fi

echo "==> 完成"
