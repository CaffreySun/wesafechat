import Foundation

enum Event {
    case focusChanged(isFrontmost: Bool)
    case idleCheckTick(isFrontmost: Bool, idleTime: TimeInterval)
    case closeTimerFired(isFrontmost: Bool)
}

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

class Core {
    private(set) var focusLossEnabled: Bool
    private(set) var idleDetectionEnabled: Bool
    private(set) var focusLossDelay: TimeInterval
    private(set) var idleDelay: TimeInterval
    private(set) var isHidden = false
    private var closeTimerActive = false

    init(focusLossEnabled: Bool, idleDetectionEnabled: Bool,
         focusLossDelay: TimeInterval, idleDelay: TimeInterval) {
        self.focusLossEnabled = focusLossEnabled
        self.idleDetectionEnabled = idleDetectionEnabled
        self.focusLossDelay = focusLossDelay
        self.idleDelay = idleDelay
    }

    // MARK: - Config changes (from menu)

    func setFocusLossEnabled(_ enabled: Bool) -> [Action] {
        focusLossEnabled = enabled
        var actions: [Action] = [.persistSettings, .updateStatusIcon]
        if !enabled {
            closeTimerActive = false
            actions.insert(.cancelCloseTimer, at: 0)
        }
        return actions
    }

    func setIdleDetectionEnabled(_ enabled: Bool) -> [Action] {
        idleDetectionEnabled = enabled
        if enabled {
            return [.startIdleCheck, .persistSettings, .updateStatusIcon]
        } else {
            return [.stopIdleCheck, .persistSettings, .updateStatusIcon]
        }
    }

    func setFocusLossDelay(_ seconds: TimeInterval) -> [Action] {
        focusLossDelay = seconds
        if closeTimerActive {
            closeTimerActive = false
            return [.cancelCloseTimer, .startCloseTimer(delay: seconds), .persistSettings]
        }
        return [.persistSettings]
    }

    func setIdleDelay(_ seconds: TimeInterval) -> [Action] {
        idleDelay = seconds
        return [.persistSettings]
    }

    // MARK: - External events

    func handle(_ event: Event) -> [Action] {
        switch event {
        case .focusChanged(let isFrontmost):
            return handleFocusChanged(isFrontmost: isFrontmost)
        case .idleCheckTick(let isFrontmost, let idleTime):
            return handleIdleCheckTick(isFrontmost: isFrontmost, idleTime: idleTime)
        case .closeTimerFired(let isFrontmost):
            return handleCloseTimerFired(isFrontmost: isFrontmost)
        }
    }

    func resetHidden() {
        isHidden = false
    }

    // MARK: - Private

    private func handleFocusChanged(isFrontmost: Bool) -> [Action] {
        if isFrontmost {
            isHidden = false
            if closeTimerActive {
                closeTimerActive = false
                return [.cancelCloseTimer]
            }
            return []
        }

        guard focusLossEnabled, !isHidden, !closeTimerActive else { return [] }
        closeTimerActive = true
        return [.startCloseTimer(delay: focusLossDelay)]
    }

    private func handleIdleCheckTick(isFrontmost: Bool, idleTime: TimeInterval) -> [Action] {
        guard idleDetectionEnabled, isFrontmost, !isHidden else { return [] }
        guard idleTime >= idleDelay else { return [] }
        isHidden = true
        return [.hideWeChat, .scheduleHiddenReset]
    }

    private func handleCloseTimerFired(isFrontmost: Bool) -> [Action] {
        closeTimerActive = false
        guard focusLossEnabled, !isFrontmost, !isHidden else { return [] }
        isHidden = true
        return [.hideWeChat, .scheduleHiddenReset]
    }
}
