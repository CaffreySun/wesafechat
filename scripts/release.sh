#!/bin/bash
set -e

VERSION="${1:?用法: bash scripts/release.sh <version>}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

ZIP_NAME="WeSafeChat-v${VERSION}.app.zip"
BUILD_DIR="build"

echo "==> 构建 ${VERSION}..."
bash install.sh --no-install --output "$BUILD_DIR"

echo "==> 打包 ${ZIP_NAME}..."
cd "$BUILD_DIR"
zip -rq "../${ZIP_NAME}" "WeSafeChat.app"
cd ..

SHA256=$(shasum -a 256 "$ZIP_NAME" | awk '{print $1}')
echo "==> 完成: ${ZIP_NAME}"
echo "    SHA256: ${SHA256}"
