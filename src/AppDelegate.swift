import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    let BUNDLE_ID = "com.tencent.xinWeChat"
    let defaults = UserDefaults.standard

    var focusLossEnabled = false
    var focusLossDelaySeconds: TimeInterval = 3.0
    var idleDetectionEnabled = true
    var idleDelaySeconds: TimeInterval = 5.0

    var statusItem: NSStatusItem!
    var closeTimer: Timer?
    var idleCheckTimer: Timer?
    var isHidden = false

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        Migration.run()

        focusLossEnabled = defaults.bool(forKey: "focusLossEnabled")
        let fdl = defaults.integer(forKey: "focusLossDelaySeconds")
        focusLossDelaySeconds = TimeInterval(fdl > 0 ? fdl : 3)
        let loadedIdle = defaults.object(forKey: "idleDetectionEnabled")
        idleDetectionEnabled = (loadedIdle as? Bool) ?? true
        let idl = defaults.integer(forKey: "idleDelaySeconds")
        idleDelaySeconds = TimeInterval(idl > 0 ? idl : 5)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "WeChat Monitor")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        let menu = NSMenu()
        focusLossMenuItem.target = self
        focusLossMenuItem.toolTip = "微信失去焦点时自动隐藏"
        focusLossMenuItem.state = focusLossEnabled ? .on : .off

        let focusLossDelaySubmenu = NSMenuItem(title: "无焦点隐藏延时", action: nil, keyEquivalent: "")
        focusLossDelaySubmenu.toolTip = "失去焦点后等待时间"
        for (index, item) in focusLossDelayItems.enumerated() {
            item.target = self
            item.tag = index + 1
            if item.tag == Int(focusLossDelaySeconds) { item.state = .on }
            focusLossDelayMenu.addItem(item)
        }
        focusLossDelaySubmenu.submenu = focusLossDelayMenu

        idleDetectionMenuItem.target = self
        idleDetectionMenuItem.toolTip = "微信有焦点但无操作时自动隐藏"
        idleDetectionMenuItem.state = idleDetectionEnabled ? .on : .off

        let idleDelaySubmenu = NSMenuItem(title: "无操作隐藏延时", action: nil, keyEquivalent: "")
        idleDelaySubmenu.toolTip = "无操作后等待时间"
        for (index, item) in idleDelayItems.enumerated() {
            item.target = self
            item.tag = index + 1
            if item.tag == Int(idleDelaySeconds) { item.state = .on }
            idleDelayMenu.addItem(item)
        }
        idleDelaySubmenu.submenu = idleDelayMenu

        autoLaunchMenuItem.target = self
        autoLaunchMenuItem.toolTip = "登录时自动启动 WeSafeChat"
        autoLaunchMenuItem.state = SMAppService.mainApp.status == .enabled ? .on : .off

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

        if focusLossEnabled {
            startObserving()
            checkAndHandleFocusChange()
        }
        if idleDetectionEnabled {
            startIdleCheck()
        }
        updateStatusIcon()
    }

    // MARK: - Status Icon

    func updateStatusIcon() {
        if focusLossEnabled || idleDetectionEnabled {
            statusItem.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Monitoring")
            statusItem.button?.image?.size = NSSize(width: 18, height: 18)
        } else {
            statusItem.button?.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "WeChat Monitor")
            statusItem.button?.image?.size = NSSize(width: 18, height: 18)
        }
    }

    // MARK: - Toggle Actions

    @objc func toggleFocusLoss() {
        focusLossEnabled.toggle()
        defaults.set(focusLossEnabled, forKey: "focusLossEnabled")
        focusLossMenuItem.state = focusLossEnabled ? .on : .off
        if focusLossEnabled {
            startObserving()
            checkAndHandleFocusChange()
        } else {
            cancelCloseTimer()
            stopObserving()
        }
        updateStatusIcon()
    }

    @objc func toggleIdleDetection() {
        idleDetectionEnabled.toggle()
        defaults.set(idleDetectionEnabled, forKey: "idleDetectionEnabled")
        idleDetectionMenuItem.state = idleDetectionEnabled ? .on : .off
        if idleDetectionEnabled {
            startIdleCheck()
        } else {
            stopIdleCheck()
        }
        updateStatusIcon()
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

    // MARK: - Delay Settings

    @objc func setFocusLossDelay(_ sender: NSMenuItem) {
        focusLossDelaySeconds = TimeInterval(sender.tag)
        defaults.set(sender.tag, forKey: "focusLossDelaySeconds")
        for item in focusLossDelayItems {
            item.state = (item.tag == sender.tag) ? .on : .off
        }
        if closeTimer != nil {
            startCloseTimer()
        }
    }

    @objc func setIdleDelay(_ sender: NSMenuItem) {
        idleDelaySeconds = TimeInterval(sender.tag)
        defaults.set(sender.tag, forKey: "idleDelaySeconds")
        for item in idleDelayItems {
            item.state = (item.tag == sender.tag) ? .on : .off
        }
        if idleCheckTimer != nil {
            stopIdleCheck()
            startIdleCheck()
        }
    }

    // MARK: - Focus Loss Detection

    func startObserving() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(appActivated), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(appDeactivated), name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
    }

    func stopObserving() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc func appActivated(_ notification: Notification) {
        guard focusLossEnabled else { return }
        checkAndHandleFocusChange()
    }

    @objc func appDeactivated(_ notification: Notification) {
        guard focusLossEnabled else { return }
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           app.bundleIdentifier == BUNDLE_ID {
            checkAndHandleFocusChange()
        }
    }

    func isWeChatFrontmost() -> Bool {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier == BUNDLE_ID
    }

    func checkAndHandleFocusChange() {
        guard focusLossEnabled else { return }
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
        closeTimer = Timer.scheduledTimer(withTimeInterval: focusLossDelaySeconds, repeats: false) { [weak self] _ in
            guard let self, self.focusLossEnabled else { return }
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
            guard let self, self.idleDetectionEnabled else { return }
            guard self.isWeChatFrontmost(), !self.isHidden else { return }
            if self.systemIdleTime() >= self.idleDelaySeconds {
                self.hideWeChat()
            }
        }
        RunLoop.current.add(idleCheckTimer!, forMode: .common)
    }

    func stopIdleCheck() {
        idleCheckTimer?.invalidate()
        idleCheckTimer = nil
    }

    // MARK: - Hide WeChat

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
