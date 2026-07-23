import Foundation

struct Migration {
    static func runWith(_ defaults: UserDefaults) {
        let version = defaults.integer(forKey: "schemaVersion")

        if version < 1 {
            migrateToV1(defaults)
        }
        // if version < 2 { migrateToV2(defaults) }
    }

    private static func migrateToV1(_ defaults: UserDefaults) {
        // v0.3.x → v0.4.0: 总开关拆分为无焦点隐藏 + 无操作隐藏，共用延时拆分为两个独立延时
        if defaults.object(forKey: "isSafing") != nil {
            let savedSafing = defaults.bool(forKey: "isSafing")
            defaults.set(savedSafing, forKey: "focusLossEnabled")
            defaults.removeObject(forKey: "isSafing")
        }
        let oldDelay = defaults.integer(forKey: "delaySeconds")
        if oldDelay > 0 {
            defaults.set(oldDelay, forKey: "focusLossDelaySeconds")
            defaults.set(oldDelay, forKey: "idleDelaySeconds")
            defaults.removeObject(forKey: "delaySeconds")
        }
        defaults.set(1, forKey: "schemaVersion")
    }
}
