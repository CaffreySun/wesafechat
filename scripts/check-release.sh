#!/bin/bash
set -e

# Pre-release validation: checks that Info.plist, CHANGELOG, and git state
# are ready for the given version tag.
#
# Usage: bash scripts/check-release.sh <version>
# Example: bash scripts/check-release.sh 0.3.4

VERSION="${1:?用法: bash scripts/check-release.sh <version>}"
errors=0

echo "==> 检查 v${VERSION} 发版就绪状态..."

# 1. Info.plist CFBundleShortVersionString matches version
plist_ver=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist 2>/dev/null)
if [ "$plist_ver" != "$VERSION" ]; then
    echo "  ❌ Info.plist CFBundleShortVersionString ($plist_ver) != $VERSION"
    errors=$((errors + 1))
else
    echo "  ✓ CFBundleShortVersionString = $VERSION"
fi

# 2. Info.plist CFBundleVersion matches version
bundle_ver=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info.plist 2>/dev/null)
if [ "$bundle_ver" != "$VERSION" ]; then
    echo "  ❌ Info.plist CFBundleVersion ($bundle_ver) != $VERSION"
    errors=$((errors + 1))
else
    echo "  ✓ CFBundleVersion = $VERSION"
fi

# 3. CHANGELOG.md has a section for this version
if awk "/^## \[$VERSION\]/{found=1} END{exit found ? 0 : 1}" CHANGELOG.md; then
    echo "  ✓ CHANGELOG.md has ## [$VERSION] section"
else
    echo "  ❌ CHANGELOG.md missing section: ## [$VERSION]"
    errors=$((errors + 1))
fi

# 4. No uncommitted changes
if [ -z "$(git status --porcelain)" ]; then
    echo "  ✓ Working tree is clean"
else
    echo "  ❌ Uncommitted changes present"
    errors=$((errors + 1))
fi

echo
if [ $errors -gt 0 ]; then
    echo "❌ $errors check(s) failed. Fix them before tagging."
    exit 1
fi

echo "✅ 所有检查通过，可以打 tag: git tag v${VERSION} && git push origin v${VERSION}"
