#!/bin/bash
set -e

APP_NAME="WeSafeChat"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents/MacOS"

echo "==> 清理旧构建..."
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS"

echo "==> 编译 ${APP_NAME}..."
swiftc main.swift -o "${CONTENTS}/${APP_NAME}" \
  -framework Cocoa -framework ServiceManagement

echo "==> 复制 Info.plist..."
cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"

echo "==> 构建完成: ${APP_BUNDLE}"

echo ""
read -p "是否安装到 /Applications 目录？(y/n) " install_choice
if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
    if [ -d "/Applications/${APP_BUNDLE}" ]; then
        rm -rf "/Applications/${APP_BUNDLE}"
    fi
    cp -R "$APP_BUNDLE" /Applications/
    echo "==> 已安装到 /Applications/${APP_BUNDLE}"

    echo ""
    read -p "是否立即运行？(y/n) " run_choice
    if [[ "$run_choice" == "y" || "$run_choice" == "Y" ]]; then
        open "/Applications/${APP_BUNDLE}"
        echo "==> 已启动"
    fi
fi

echo "==> 完成"
