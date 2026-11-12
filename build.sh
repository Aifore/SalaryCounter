#!/bin/bash
# 构建 SalaryCounter.app（需要 macOS 13+ 与 Xcode 或 Command Line Tools）
set -euo pipefail
cd "$(dirname "$0")"

echo "▶ 编译 release 版本…"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="build/SalaryCounter.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/SalaryCounter" "$APP/Contents/MacOS/SalaryCounter"
cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "▶ 本地签名（ad-hoc）…"
codesign --force --deep --sign - "$APP"

echo "✅ 完成：${APP}"
echo "   运行：open \"$APP\""
echo "   安装：cp -R \"$APP\" /Applications/"
