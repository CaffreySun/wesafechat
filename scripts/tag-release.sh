#!/bin/bash
set -e

# Tag and push a release after validation.
#
# Usage: bash scripts/tag-release.sh <version>
# Example: bash scripts/tag-release.sh 0.3.4

VERSION="${1:?用法: bash scripts/tag-release.sh <version>}"

echo "==> 发版前检查..."
bash scripts/check-release.sh "$VERSION"

echo
echo "==> 打 tag v${VERSION} 并推送..."
git tag "v${VERSION}"
git push origin "v${VERSION}"

echo
echo "==> v${VERSION} 已推送，CI 发版中..."
echo "    https://github.com/CaffreySun/wesafechat/actions"
