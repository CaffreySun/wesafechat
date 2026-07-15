# WeSafeChat

macOS 菜单栏工具，在你切换到其他应用时自动隐藏微信，保护聊天隐私。

## 功能

- 当微信失去焦点时，延迟 N 秒自动隐藏
- 菜单栏状态图标，一键开关
- 支持开机自启
- 可配置隐藏延迟（1–10 秒）

## 构建

```bash
swiftc -o WeSafeChat main.swift
```

## 运行

```bash
./WeSafeChat
```

或双击 `WeSafeChat.app`。
