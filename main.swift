import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    let APP_NAME = "WeChat"
    let BUNDLE_ID = "com.tencent.xinWeChat"
    let defaults = UserDefaults.standard
    var delaySeconds: TimeInterval = 5.0

    var statusItem: NSStatusItem!
    var closeTimer: Timer?
    var idleCheckTimer: Timer?
    var isSafing = false
    var isHidden = false

    let safeMenuItem = NSMenuItem(title: "启动", action: #selector(toggleSafeMode), keyEquivalent: "")
    let autoLaunchMenuItem = NSMenuItem(title: "开机自启", action: #selector(toggleAutoLaunch), keyEquivalent: "")
    let delayMenu = NSMenu()
    let delayItems: [NSMenuItem] = (1...10).map { i in
        NSMenuItem(title: "\(i) 秒", action: #selector(setDelay(_:)), keyEquivalent: "")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        delaySeconds = TimeInterval(defaults.integer(forKey: "delaySeconds").then { $0 == 0 ? 5 : $0 })
        let savedMonitoring = defaults.bool(forKey: "isSafing")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "WeChat Monitor")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        let menu = NSMenu()
        safeMenuItem.target = self
        autoLaunchMenuItem.target = self
        autoLaunchMenuItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

        let delaySubmenuItem = NSMenuItem(title: "安全延迟", action: nil, keyEquivalent: "")
        for (index, item) in delayItems.enumerated() {
            item.target = self
            item.tag = index + 1
            if item.tag == Int(delaySeconds) { item.state = .on }
            delayMenu.addItem(item)
        }
        delaySubmenuItem.submenu = delayMenu

        menu.addItem(safeMenuItem)
        menu.addItem(autoLaunchMenuItem)
        menu.addItem(delaySubmenuItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu

        if savedMonitoring {
            toggleSafeMode()
        }
    }

    @objc func toggleSafeMode() {
        isSafing.toggle()
        defaults.set(isSafing, forKey: "isSafing")
        if isSafing {
            safeMenuItem.title = "停止"
            statusItem.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Monitoring")
            statusItem.button?.image?.size = NSSize(width: 18, height: 18)
            isHidden = false
            startObserving()
            checkAndHandleFocusChange()
        } else {
            safeMenuItem.title = "启动"
            statusItem.button?.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "WeChat Monitor")
            statusItem.button?.image?.size = NSSize(width: 18, height: 18)
            cancelCloseTimer()
            stopObserving()
        }
    }

    @objc func setDelay(_ sender: NSMenuItem) {
        delaySeconds = TimeInterval(sender.tag)
        defaults.set(sender.tag, forKey: "delaySeconds")
        for item in delayItems {
            item.state = (item.tag == sender.tag) ? .on : .off
        }
        if closeTimer != nil {
            startCloseTimer()
        }
    }

    @objc func toggleAutoLaunch() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                autoLaunchMenuItem.state = .off
            } else {
                try service.register()
                autoLaunchMenuItem.state = .on
            }
        } catch {
            print("开机自启设置失败: \(error)")
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    func startObserving() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(appActivated), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appDeactivated), name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
        startIdleCheck()
    }

    func stopObserving() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        stopIdleCheck()
    }

    @objc func appActivated(_ notification: Notification) {
        guard isSafing else { return }
        checkAndHandleFocusChange()
    }

    @objc func appDeactivated(_ notification: Notification) {
        guard isSafing else { return }
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           app.bundleIdentifier == BUNDLE_ID {
            checkAndHandleFocusChange()
        }
    }

    func isWeChatFrontmost() -> Bool {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier == BUNDLE_ID
    }

    func checkAndHandleFocusChange() {
        if isWeChatFrontmost() {
            if isHidden { isHidden = false }
            cancelCloseTimer()
        } else {
            if closeTimer == nil && !isHidden {
                startCloseTimer()
            }
        }
    }

    func startCloseTimer() {
        cancelCloseTimer()
        closeTimer = Timer.scheduledTimer(withTimeInterval: delaySeconds, repeats: false) { [weak self] _ in
            guard let self, self.isSafing else { return }
            if !self.isWeChatFrontmost() {
                self.hideWeChat()
            } else {
                self.isHidden = false
            }
            self.closeTimer = nil
        }
        RunLoop.current.add(closeTimer!, forMode: .common)
    }

    func cancelCloseTimer() {
        if let timer = closeTimer {
            timer.invalidate()
            closeTimer = nil
        }
    }

    // MARK: - Idle Detection

    func systemIdleTime() -> TimeInterval {
        let eventTypes: [CGEventType] = [
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged,
            .keyDown, .keyUp, .flagsChanged,
            .scrollWheel,
        ]
        var minIdle = TimeInterval.greatestFiniteMagnitude
        for type in eventTypes {
            let idle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: type)
            if idle < minIdle { minIdle = idle }
        }
        return minIdle
    }

    func startIdleCheck() {
        stopIdleCheck()
        idleCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.isSafing else { return }
            guard self.isWeChatFrontmost(), !self.isHidden else { return }
            if self.systemIdleTime() >= self.delaySeconds {
                self.hideWeChat()
            }
        }
        RunLoop.current.add(idleCheckTimer!, forMode: .common)
    }

    func stopIdleCheck() {
        idleCheckTimer?.invalidate()
        idleCheckTimer = nil
    }

    func hideWeChat() {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: BUNDLE_ID)
        for app in apps { app.hide() }
        isHidden = true
        if !apps.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isHidden = false
            }
        }
    }
}

extension Int {
    func then(_ transform: (Int) -> Int) -> Int {
        transform(self)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
