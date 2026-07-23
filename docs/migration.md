# Data Migration Guide

WeSafeChat 使用 `schemaVersion`（整数）管理 UserDefaults 数据结构升级。启动时 `Migration.runWith(defaults)` 按版本号逐步执行迁移。

## 原理

```
schemaVersion = 0（key 不存在） → 初始状态，运行所有迁移
schemaVersion = 1               → 已迁移到 v0.4.0
schemaVersion = N               → 已迁移到对应的数据结构版本
```

**注意**：`schemaVersion` 只在数据结构需要迁移时才递增，不与发布版本号绑定。

## 如何添加新的迁移步骤

1. 在 `src/logic/Migration.swift` 的 `runWith` 中添加新分支：

```swift
if version < 2 {
    migrateToV2(defaults)
}
```

2. 添加对应的 private static 方法：

```swift
private static func migrateToV2(_ defaults: UserDefaults) {
    // 数据迁移逻辑
    defaults.set(2, forKey: "schemaVersion")
}
```

3. 每步迁移末尾必须将 `schemaVersion` 设为当前版本号。

## 版本历史

### v1（v0.4.0）

- `isSafing` → `focusLossEnabled`（总开关拆分为无焦点隐藏开关）
- `delaySeconds` → `focusLossDelaySeconds` + `idleDelaySeconds`（共用延时拆分为两个独立延时）
- 迁移后删除旧 key，设置 `schemaVersion = 1`
