# WeSafeChat

macOS 菜单栏工具，在你切换到其他应用时自动隐藏微信，保护聊天隐私。

## 功能

- 当微信失去焦点时，延迟 N 秒自动隐藏
- 菜单栏状态图标，一键开关
- 支持开机自启
- 可配置隐藏延迟（1–10 秒）

## 构建与运行

```bash
bash install.sh
```

脚本会自动编译、打包 `.app` bundle 并生成应用图标，产物输出到 `build/WeSafeChat.app`。

构建完成后脚本会询问是否安装到 `/Applications` 并运行。
