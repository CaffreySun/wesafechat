import Foundation

func testMigrationV1WithOldKeys() {
    let defaults = UserDefaults(suiteName: "test_migration_v1_old")!
    defaults.removePersistentDomain(forName: "test_migration_v1_old")
    defaults.set(true, forKey: "isSafing")
    defaults.set(7, forKey: "delaySeconds")
    defaults.set(0, forKey: "schemaVersion")

    Migration.runWith(defaults)

    assertTrue(defaults.bool(forKey: "focusLossEnabled"),
               "isSafing=true should migrate to focusLossEnabled=true")
    assertEqual(defaults.integer(forKey: "focusLossDelaySeconds"), 7,
                "delaySeconds=7 should migrate to focusLossDelaySeconds=7")
    assertEqual(defaults.integer(forKey: "idleDelaySeconds"), 7,
                "delaySeconds=7 should migrate to idleDelaySeconds=7")
    assertEqual(defaults.integer(forKey: "schemaVersion"), 1,
                "schemaVersion should be set to 1")
    assertTrue(defaults.object(forKey: "isSafing") == nil,
               "old key isSafing should be removed")
    assertTrue(defaults.object(forKey: "delaySeconds") == nil,
               "old key delaySeconds should be removed")

    defaults.removePersistentDomain(forName: "test_migration_v1_old")
}

func testMigrationV1WithoutOldKeys() {
    let defaults = UserDefaults(suiteName: "test_migration_v1_none")!
    defaults.removePersistentDomain(forName: "test_migration_v1_none")

    Migration.runWith(defaults)

    assertTrue(defaults.object(forKey: "focusLossEnabled") == nil,
               "no old isSafing -> no focusLossEnabled")
    assertEqual(defaults.integer(forKey: "focusLossDelaySeconds"), 0,
                "no old delay -> focusLossDelaySeconds not set")
    assertEqual(defaults.integer(forKey: "schemaVersion"), 1,
                "schemaVersion should be set to 1")

    defaults.removePersistentDomain(forName: "test_migration_v1_none")
}

func testMigrationV1Idempotent() {
    let defaults = UserDefaults(suiteName: "test_migration_v1_idem")!
    defaults.removePersistentDomain(forName: "test_migration_v1_idem")
    defaults.set(true, forKey: "isSafing")
    defaults.set(7, forKey: "delaySeconds")

    Migration.runWith(defaults)
    Migration.runWith(defaults)

    assertTrue(defaults.bool(forKey: "focusLossEnabled"),
               "after two migrations, focusLossEnabled should be true")
    assertEqual(defaults.integer(forKey: "schemaVersion"), 1,
                "schemaVersion should still be 1")

    defaults.removePersistentDomain(forName: "test_migration_v1_idem")
}

func testMigrationAlreadyV1() {
    let defaults = UserDefaults(suiteName: "test_migration_already_v1")!
    defaults.removePersistentDomain(forName: "test_migration_already_v1")
    defaults.set(1, forKey: "schemaVersion")
    defaults.set(true, forKey: "shouldStay")

    Migration.runWith(defaults)

    assertTrue(defaults.bool(forKey: "shouldStay"),
               "existing keys should not be touched")
    assertEqual(defaults.integer(forKey: "schemaVersion"), 1,
                "schemaVersion should stay 1")

    defaults.removePersistentDomain(forName: "test_migration_already_v1")
}

func runMigrationTests() {
    testMigrationV1WithOldKeys()
    testMigrationV1WithoutOldKeys()
    testMigrationV1Idempotent()
    testMigrationAlreadyV1()
}
