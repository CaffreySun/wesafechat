# 架构设计

## 目标

AI 独立完成 TDD 全流程，人只做最终验收。

## 手段

把副作用推到边界，核心只做输入→输出的纯计算。

## 副作用的种类与隔离方式

| 类别 | 例子 | 隔离手段 |
|---|---|---|
| 读取系统状态 | 当前前台 app、系统空闲时间、网络状态、地理位置 | 核心不读，外层读完后作为参数传入 |
| 执行系统操作 | 隐藏窗口、发送通知、播放声音、写入文件 | 核心不执行，返回指令让外层执行 |
| 延时/定时 | NSTimer、DispatchQueue.asyncAfter、sleep | 核心不和定时器打交道，时间作为参数传入，需要延时时返回指令 |
| 持久化 | UserDefaults、Keychain、数据库读写 | 核心不写，返回指令让外层写 |
| 系统通知解析 | NSWorkspace 通知、NSNotification、KVO | 解析逻辑抽成纯函数，入参为通知对象或字典，出参为业务值 |
| UI 装配 | NSMenu、NSStatusBar、UIView、HTML | 声明式代码不包含分支逻辑，不值得隔离 |
| 单行系统调用 | SMAppService.register、exit | 无分支逻辑，不值得隔离 |

值不值得隔离，取决于该代码中是否包含分支或条件判断：包含 if/else、guard、switch → 必须隔离；纯粹是单行调用或声明式装配 → 不必隔离。

## 核心形态

```
输入：事件 + 当前时间 + 外部读好的状态
  ↓
核心（状态机，纯计算，无副作用）
  ↓
输出：[Action] —— 向外层发出的动作指令
```

测试即断言：给什么输入，期望什么输出。无需 spy，无需 mock。输出是可比较的值，不是副作用。

## 本项目实现

### Event — 所有触发决策的外部信号

```swift
enum Event {
    case focusChanged(isFrontmost: Bool)
    case idleCheckTick(isFrontmost: Bool, idleTime: TimeInterval)
    case closeTimerFired(isFrontmost: Bool)
}
```

### Action — 核心需要外层执行的操作

```swift
enum Action: Equatable {
    case hideWeChat
    case startCloseTimer(delay: TimeInterval)
    case cancelCloseTimer
    case startIdleCheck
    case stopIdleCheck
    case scheduleHiddenReset
    case persistSettings
    case updateStatusIcon
}
```

### Core — 状态机

```swift
class Core {
    init(focusLossEnabled:, idleDetectionEnabled:, focusLossDelay:, idleDelay:)
    func setFocusLossEnabled(_: Bool) -> [Action]
    func setIdleDetectionEnabled(_: Bool) -> [Action]
    func setFocusLossDelay(_: TimeInterval) -> [Action]
    func setIdleDelay(_: TimeInterval) -> [Action]
    func handle(_: Event) -> [Action]
    func resetHidden()
}
```

### 文件结构

```
src/
  logic/
    Core.swift          纯逻辑，不依赖 Cocoa（100% 覆盖率）
    Migration.swift      UserDefaults 迁移（100% 覆盖率）
  AppDelegate.swift      薄壳，翻译事件 + 执行 Action
tests/
  TestCore.swift         断言 Core 输出
  TestMigration.swift     断言迁移结果
scripts/
  test.sh                swiftc 编译 + 运行测试 + 覆盖率检查
```

### 测试写法

```swift
let core = Core(focusLossEnabled: true, idleDetectionEnabled: true, ...)
assert(core.handle(.focusChanged(isFrontmost: false)) == [.startCloseTimer(delay: 3)])
```

## 添加新功能的流程

1. 在 `Core` 中添加配置属性 + 判断逻辑（纯计算，不碰系统 API）
2. 在 `TestCore` 中写测试：构造不同的 Event 输入 → 断言 `handle` 返回的 Action 列表
3. 运行 `bash scripts/test.sh` 确认通过
4. 在 `AppDelegate` 中注入真实系统数据（如读取时间、读取前台 app）
5. 给新逻辑加上菜单入口（如果需要用户配置）
