#!/bin/bash
set -e

BUILD_DIR="build"
APP_NAME="WeSafeChat"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents/MacOS"

echo "==> 清理旧构建..."
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS"

echo "==> 编译 ${APP_NAME}..."
swiftc main.swift -o "${CONTENTS}/${APP_NAME}" \
  -framework Cocoa -framework ServiceManagement

echo "==> 复制 Info.plist..."
cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"

echo "==> 生成应用图标..."
ICONSET="AppIcon.iconset"
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

echo ""
read -p "是否安装到 /Applications 目录？(y/n) " install_choice
if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
    INSTALL_TARGET="/Applications/${APP_NAME}.app"
    if [ -d "$INSTALL_TARGET" ]; then
        rm -rf "$INSTALL_TARGET"
    fi
    cp -R "$APP_BUNDLE" /Applications/
    echo "==> 已安装到 ${INSTALL_TARGET}"

    echo ""
    read -p "是否立即运行？(y/n) " run_choice
    if [[ "$run_choice" == "y" || "$run_choice" == "Y" ]]; then
        open "$INSTALL_TARGET"
        echo "==> 已启动"
    fi
fi

echo "==> 完成"
