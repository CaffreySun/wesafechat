# Changelog

All notable changes to WeSafeChat.


## [0.3.4] - 2026-07-16

### Changed
- 「关于」窗口改用系统原生 About 面板，右上角关闭按钮
- CFBundleVersion 改为构建时自动生成（yyMMddHHmm 格式）

### Added
- About 面板增加 MIT License 可点击链接
- 内容居中对齐

### Fixed
- 修复 About 面板链接无法点击的 cursor 冲突问题

## [0.3.3] - 2026-07-15

### Added
- 「关于」菜单项，点击显示应用信息窗口，含可点击的 GitHub 链接

### Removed
- Homebrew Cask 中已废弃的 Gatekeeper 绕过提示（postflight 已自动去除隔离属性）

## [0.3.2] - 2025-07-14

### Changed
- 重构：拆分 AppDelegate 到独立源文件 `src/AppDelegate.swift`

### Added
- GitHub Actions 自动发版工作流
- README 增加 Homebrew 安装说明

## [0.3.1] - 2025-07-13

### Added
- `scripts/release.sh` 构建打包脚本
- `.gitignore` 忽略构建产物

## [0.2.4] - 2025-07-12

### Fixed
- 修复 `install.sh` 中缺失的 `*)` case 标签

[0.3.4]: https://github.com/CaffreySun/wesafechat/compare/v0.3.3...v0.3.4
[0.3.3]: https://github.com/CaffreySun/wesafechat/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/CaffreySun/wesafechat/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/CaffreySun/wesafechat/compare/v0.3.0...v0.3.1
[0.2.4]: https://github.com/CaffreySun/wesafechat/compare/v0.2.3...v0.2.4
