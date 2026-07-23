import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    let BUNDLE_ID = "com.tencent.xinWeChat"
    let defaults = UserDefaults.standard

    var statusItem: NSStatusItem!
    var closeTimer: Timer?
    var idleCheckTimer: Timer?

    let focusLossMenuItem = NSMenuItem(title: "无焦点隐藏", action: #selector(toggleFocusLoss), keyEquivalent: "")
    let idleDetectionMenuItem = NSMenuItem(title: "无操作隐藏", action: #selector(toggleIdleDetection), keyEquivalent: "")
    let autoLaunchMenuItem = NSMenuItem(title: "开机自启", action: #selector(toggleAutoLaunch), keyEquivalent: "")
    let focusLossDelayMenu = NSMenu()
    let focusLossDelayItems: [NSMenuItem] = (1...10).map { i in
        NSMenuItem(title: "\(i) 秒", action: #selector(setFocusLossDelay(_:)), keyEquivalent: "")
    }
    let idleDelayMenu = NSMenu()
    let idleDelayItems: [NSMenuItem] = (1...10).map { i in
        NSMenuItem(title: "\(i) 秒", action: #selector(setIdleDelay(_:)), keyEquivalent: "")
    }
    let aboutMenuItem = NSMenuItem(title: "关于", action: #selector(showAbout), keyEquivalent: "")

    var core: Core!

    func applicationDidFinishLaunching(_ notification: Notification) {
        Migration.runWith(defaults)

        let focusLossEnabled = defaults.bool(forKey: "focusLossEnabled")
        let fdl = defaults.integer(forKey: "focusLossDelaySeconds")
        let loadedIdle = defaults.object(forKey: "idleDetectionEnabled")
        let idleDetectionEnabled = (loadedIdle as? Bool) ?? true
        let idl = defaults.integer(forKey: "idleDelaySeconds")
        core = Core(
            focusLossEnabled: focusLossEnabled,
            idleDetectionEnabled: idleDetectionEnabled,
            focusLossDelay: TimeInterval(fdl > 0 ? fdl : 3),
            idleDelay: TimeInterval(idl > 0 ? idl : 5)
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "WeChat Monitor")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        buildMenu()
        setupObservers()

        if core.focusLossEnabled {
            checkAndHandleFocusChange()
        }
        startIdleTimer()
        syncUI()
    }

    // MARK: - Menu

    func buildMenu() {
        let menu = NSMenu()

        focusLossMenuItem.target = self
        focusLossMenuItem.toolTip = "微信失去焦点时自动隐藏"
        let focusLossDelaySubmenu = NSMenuItem(title: "无焦点隐藏延时", action: nil, keyEquivalent: "")
        focusLossDelaySubmenu.toolTip = "失去焦点后等待时间"
        for (index, item) in focusLossDelayItems.enumerated() {
            item.target = self
            item.tag = index + 1
            focusLossDelayMenu.addItem(item)
        }
        focusLossDelaySubmenu.submenu = focusLossDelayMenu

        idleDetectionMenuItem.target = self
        idleDetectionMenuItem.toolTip = "微信有焦点但无操作时自动隐藏"
        let idleDelaySubmenu = NSMenuItem(title: "无操作隐藏延时", action: nil, keyEquivalent: "")
        idleDelaySubmenu.toolTip = "无操作后等待时间"
        for (index, item) in idleDelayItems.enumerated() {
            item.target = self
            item.tag = index + 1
            idleDelayMenu.addItem(item)
        }
        idleDelaySubmenu.submenu = idleDelayMenu

        autoLaunchMenuItem.target = self
        autoLaunchMenuItem.toolTip = "登录时自动启动 WeSafeChat"

        menu.addItem(focusLossMenuItem)
        menu.addItem(focusLossDelaySubmenu)
        menu.addItem(idleDetectionMenuItem)
        menu.addItem(idleDelaySubmenu)
        menu.addItem(NSMenuItem.separator())
        aboutMenuItem.target = self
        aboutMenuItem.toolTip = "关于 WeSafeChat"
        menu.addItem(aboutMenuItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.toolTip = "退出 WeSafeChat"
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    // MARK: - UI Sync

    func syncUI() {
        focusLossMenuItem.state = core.focusLossEnabled ? .on : .off
        idleDetectionMenuItem.state = core.idleDetectionEnabled ? .on : .off
        for item in focusLossDelayItems {
            item.state = (item.tag == Int(core.focusLossDelay)) ? .on : .off
        }
        for item in idleDelayItems {
            item.state = (item.tag == Int(core.idleDelay)) ? .on : .off
        }
        autoLaunchMenuItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    // MARK: - Action Executor

    func execute(_ actions: [Action]) {
        for action in actions {
            switch action {
            case .hideWeChat:
                let apps = NSRunningApplication.runningApplications(withBundleIdentifier: BUNDLE_ID)
                let found = !apps.isEmpty
                for app in apps { app.hide() }
                if !found {
                    core.resetHidden()
                }
            case .startCloseTimer(let delay):
                cancelCloseTimer()
                closeTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    let frontmost = self.isWeChatFrontmost()
                    let result = self.core.handle(.closeTimerFired(isFrontmost: frontmost))
                    self.closeTimer = nil
                    self.execute(result)
                    self.syncUI()
                }
                if let timer = closeTimer {
                    RunLoop.current.add(timer, forMode: .common)
                }
            case .cancelCloseTimer:
                cancelCloseTimer()
            case .startIdleCheck:
                startIdleTimer()
            case .stopIdleCheck:
                stopIdleTimer()
            case .scheduleHiddenReset:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.core.resetHidden()
                }
            case .persistSettings:
                defaults.set(core.focusLossEnabled, forKey: "focusLossEnabled")
                defaults.set(Int(core.focusLossDelay), forKey: "focusLossDelaySeconds")
                defaults.set(core.idleDetectionEnabled, forKey: "idleDetectionEnabled")
                defaults.set(Int(core.idleDelay), forKey: "idleDelaySeconds")
            case .updateStatusIcon:
                if core.focusLossEnabled || core.idleDetectionEnabled {
                    statusItem.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Monitoring")
                    statusItem.button?.image?.size = NSSize(width: 18, height: 18)
                } else {
                    statusItem.button?.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "WeChat Monitor")
                    statusItem.button?.image?.size = NSSize(width: 18, height: 18)
                }
            }
        }
    }

    // MARK: - Observers

    func setupObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(appActivated), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appDeactivated), name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
    }

    @objc func appActivated(_ notification: Notification) {
        let frontmost = isWeChatFrontmost()
        let result = core.handle(.focusChanged(isFrontmost: frontmost))
        execute(result)
        syncUI()
    }

    @objc func appDeactivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == BUNDLE_ID else { return }
        let result = core.handle(.focusChanged(isFrontmost: false))
        execute(result)
        syncUI()
    }

    // MARK: - Focus Loss

    func isWeChatFrontmost() -> Bool {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier == BUNDLE_ID
    }

    func checkAndHandleFocusChange() {
        let frontmost = isWeChatFrontmost()
        let result = core.handle(.focusChanged(isFrontmost: frontmost))
        execute(result)
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

    func startIdleTimer() {
        stopIdleTimer()
        idleCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let frontmost = self.isWeChatFrontmost()
            let idleTime = self.systemIdleTime()
            let result = self.core.handle(.idleCheckTick(isFrontmost: frontmost, idleTime: idleTime))
            self.execute(result)
            self.syncUI()
        }
        if let timer = idleCheckTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    func stopIdleTimer() {
        idleCheckTimer?.invalidate()
        idleCheckTimer = nil
    }

    // MARK: - Toggle Actions

    @objc func toggleFocusLoss() {
        let result = core.setFocusLossEnabled(!core.focusLossEnabled)
        if core.focusLossEnabled {
            checkAndHandleFocusChange()
        }
        execute(result)
        syncUI()
    }

    @objc func toggleIdleDetection() {
        let result = core.setIdleDetectionEnabled(!core.idleDetectionEnabled)
        execute(result)
        syncUI()
    }

    @objc func setFocusLossDelay(_ sender: NSMenuItem) {
        let result = core.setFocusLossDelay(TimeInterval(sender.tag))
        execute(result)
        syncUI()
    }

    @objc func setIdleDelay(_ sender: NSMenuItem) {
        let result = core.setIdleDelay(TimeInterval(sender.tag))
        execute(result)
        syncUI()
    }

    @objc func toggleAutoLaunch() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            print("开机自启设置失败: \(error)")
        }
        syncUI()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    @objc func showAbout() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let baseAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .paragraphStyle: paragraphStyle,
        ]
        let linkURL = URL(string: "https://github.com/CaffreySun/wesafechat")!
        let licenseURL = URL(string: "https://github.com/CaffreySun/wesafechat/blob/main/LICENSE")!

        var linkAttrs = baseAttrs
        linkAttrs[.link] = linkURL
        linkAttrs[.foregroundColor] = NSColor.linkColor
        linkAttrs[.underlineStyle] = NSUnderlineStyle.single.rawValue

        var licenseAttrs = baseAttrs
        licenseAttrs[.link] = licenseURL
        licenseAttrs[.foregroundColor] = NSColor.linkColor
        licenseAttrs[.underlineStyle] = NSUnderlineStyle.single.rawValue

        let credits = NSMutableAttributedString()
        credits.append(NSAttributedString(string: "macOS 菜单栏工具，自动隐藏微信窗口。\n\n", attributes: baseAttrs))
        credits.append(NSAttributedString(string: "github.com/CaffreySun/wesafechat", attributes: linkAttrs))
        credits.append(NSAttributedString(string: "\n\n", attributes: baseAttrs))
        credits.append(NSAttributedString(string: "MIT License", attributes: licenseAttrs))
        credits.append(NSAttributedString(string: "\n", attributes: baseAttrs))

        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits,
        ])
    }
}
