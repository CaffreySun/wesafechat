import Foundation

var passed = 0
var failed = 0

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String,
                                file: String = #file, line: Int = #line) {
    if actual == expected {
        passed += 1
    } else {
        failed += 1
        print("FAIL: \(message)")
        print("  expected: \(expected)")
        print("  actual:   \(actual)")
        print("  (\(file):\(line))")
    }
}

func assertTrue(_ condition: Bool, _ message: String,
                file: String = #file, line: Int = #line) {
    if condition {
        passed += 1
    } else {
        failed += 1
        print("FAIL: \(message) (\(file):\(line))")
    }
}

func newCore(focusLossEnabled: Bool = true,
             idleDetectionEnabled: Bool = true,
             focusLossDelay: TimeInterval = 3,
             idleDelay: TimeInterval = 5) -> Core {
    Core(focusLossEnabled: focusLossEnabled,
         idleDetectionEnabled: idleDetectionEnabled,
         focusLossDelay: focusLossDelay,
         idleDelay: idleDelay)
}

// MARK: - Focus Loss

func testLoseFocusStartsTimer() {
    let core = newCore()
    assertEqual(core.handle(.focusChanged(isFrontmost: false)),
                [.startCloseTimer(delay: 3)],
                "lose focus should start close timer")
}

func testLoseFocusWhileDisabled() {
    let core = newCore(focusLossEnabled: false)
    assertEqual(core.handle(.focusChanged(isFrontmost: false)),
                [],
                "lose focus while disabled should do nothing")
}

func testLoseFocusWhileHidden() {
    let core = newCore()
    _ = core.handle(.focusChanged(isFrontmost: false))
    _ = core.handle(.closeTimerFired(isFrontmost: false))
    assertEqual(core.handle(.focusChanged(isFrontmost: false)),
                [],
                "lose focus while hidden (debounce) should do nothing")
}

func testRegainFocusCancelsTimer() {
    let core = newCore()
    _ = core.handle(.focusChanged(isFrontmost: false))
    assertEqual(core.handle(.focusChanged(isFrontmost: true)),
                [.cancelCloseTimer],
                "regain focus should cancel timer")
}

func testRegainFocusClearsHidden() {
    let core = newCore()
    _ = core.handle(.focusChanged(isFrontmost: false))
    _ = core.handle(.closeTimerFired(isFrontmost: false))
    assertTrue(core.isHidden, "isHidden should be true after hide")
    _ = core.handle(.focusChanged(isFrontmost: true))
    assertTrue(!core.isHidden, "isHidden should be false after regain focus")
}

func testTimerFiresAndHides() {
    let core = newCore()
    _ = core.handle(.focusChanged(isFrontmost: false))
    assertEqual(core.handle(.closeTimerFired(isFrontmost: false)),
                [.hideWeChat, .scheduleHiddenReset],
                "timer fire when not frontmost should hide")
}

func testTimerFiredWhenFrontmost() {
    let core = newCore()
    _ = core.handle(.focusChanged(isFrontmost: false))
    assertEqual(core.handle(.closeTimerFired(isFrontmost: true)),
                [],
                "timer fire when frontmost should do nothing")
}

func testTimerFiredWhileDisabled() {
    let core = newCore(focusLossEnabled: false)
    assertEqual(core.handle(.closeTimerFired(isFrontmost: false)),
                [],
                "timer fire while disabled should do nothing")
}

// MARK: - Idle Detection

func testIdleExceedsThreshold() {
    let core = newCore(focusLossEnabled: false)
    assertEqual(core.handle(.idleCheckTick(isFrontmost: true, idleTime: 7)),
                [.hideWeChat, .scheduleHiddenReset],
                "idle >= threshold should hide")
}

func testIdleBelowThreshold() {
    let core = newCore(focusLossEnabled: false)
    assertEqual(core.handle(.idleCheckTick(isFrontmost: true, idleTime: 3)),
                [],
                "idle < threshold should do nothing")
}

func testIdleExactlyAtThreshold() {
    let core = newCore(focusLossEnabled: false)
    assertEqual(core.handle(.idleCheckTick(isFrontmost: true, idleTime: 5)),
                [.hideWeChat, .scheduleHiddenReset],
                "idle == threshold should hide")
}

func testIdleWhenNotFrontmost() {
    let core = newCore(focusLossEnabled: false)
    assertEqual(core.handle(.idleCheckTick(isFrontmost: false, idleTime: 10)),
                [],
                "idle when not frontmost should do nothing")
}

func testIdleWhenHidden() {
    let core = newCore(focusLossEnabled: false)
    _ = core.handle(.idleCheckTick(isFrontmost: true, idleTime: 7))
    assertEqual(core.handle(.idleCheckTick(isFrontmost: true, idleTime: 10)),
                [],
                "idle when already hidden should do nothing")
}

func testIdleWhileDisabled() {
    let core = newCore(focusLossEnabled: false, idleDetectionEnabled: false)
    assertEqual(core.handle(.idleCheckTick(isFrontmost: true, idleTime: 10)),
                [],
                "idle while disabled should do nothing")
}

// MARK: - Config Toggles

func testEnableFocusLoss() {
    let core = newCore(focusLossEnabled: false)
    assertEqual(core.setFocusLossEnabled(true),
                [.persistSettings, .updateStatusIcon],
                "enable focus loss should persist and update icon")
}

func testDisableFocusLoss() {
    let core = newCore()
    assertEqual(core.setFocusLossEnabled(false),
                [.cancelCloseTimer, .persistSettings, .updateStatusIcon],
                "disable focus loss should cancel timer, persist, update icon")
}

func testDisableFocusLossWhileTimerActive() {
    let core = newCore()
    _ = core.handle(.focusChanged(isFrontmost: false))
    assertTrue(core.focusLossEnabled, "should be enabled before disable")
    let actions = core.setFocusLossEnabled(false)
    assertTrue(actions.contains(.cancelCloseTimer),
               "disable while timer active should cancel timer")
}

func testEnableIdleDetection() {
    let core = newCore(focusLossEnabled: false, idleDetectionEnabled: false)
    assertEqual(core.setIdleDetectionEnabled(true),
                [.startIdleCheck, .persistSettings, .updateStatusIcon],
                "enable idle should start check, persist, update icon")
}

func testDisableIdleDetection() {
    let core = newCore(focusLossEnabled: false)
    assertEqual(core.setIdleDetectionEnabled(false),
                [.stopIdleCheck, .persistSettings, .updateStatusIcon],
                "disable idle should stop check, persist, update icon")
}

// MARK: - Delay Changes

func testSetFocusLossDelayWhileTimerActive() {
    let core = newCore()
    _ = core.handle(.focusChanged(isFrontmost: false))
    assertEqual(core.setFocusLossDelay(7),
                [.cancelCloseTimer, .startCloseTimer(delay: 7), .persistSettings],
                "changing delay while timer active should restart timer")
}

func testSetFocusLossDelayWhileTimerInactive() {
    let core = newCore()
    assertEqual(core.setFocusLossDelay(7),
                [.persistSettings],
                "changing delay while timer inactive should only persist")
}

func testSetIdleDelay() {
    let core = newCore(focusLossEnabled: false)
    assertEqual(core.setIdleDelay(10),
                [.persistSettings],
                "changing idle delay should persist")
}

// MARK: - resetHidden

func testResetHidden() {
    let core = newCore(focusLossEnabled: false)
    _ = core.handle(.idleCheckTick(isFrontmost: true, idleTime: 7))
    assertTrue(core.isHidden, "should be hidden after idle hide")
    core.resetHidden()
    assertTrue(!core.isHidden, "resetHidden should clear isHidden")
}

// MARK: - Interaction: idle hides, close timer becomes stale

func testIdleHidesThenCloseTimerFires() {
    let core = newCore()
    _ = core.handle(.focusChanged(isFrontmost: false))
    _ = core.handle(.idleCheckTick(isFrontmost: true, idleTime: 7))
    assertEqual(core.handle(.closeTimerFired(isFrontmost: false)),
                [],
                "close timer after idle hide should be no-op")
}

// MARK: - Runner

func runCoreTests() {
    testLoseFocusStartsTimer()
    testLoseFocusWhileDisabled()
    testLoseFocusWhileHidden()
    testRegainFocusCancelsTimer()
    testRegainFocusClearsHidden()
    testTimerFiresAndHides()
    testTimerFiredWhenFrontmost()
    testTimerFiredWhileDisabled()
    testIdleExceedsThreshold()
    testIdleBelowThreshold()
    testIdleExactlyAtThreshold()
    testIdleWhenNotFrontmost()
    testIdleWhenHidden()
    testIdleWhileDisabled()
    testEnableFocusLoss()
    testDisableFocusLoss()
    testDisableFocusLossWhileTimerActive()
    testEnableIdleDetection()
    testDisableIdleDetection()
    testSetFocusLossDelayWhileTimerActive()
    testSetFocusLossDelayWhileTimerInactive()
    testSetIdleDelay()
    testResetHidden()
    testIdleHidesThenCloseTimerFires()
}
