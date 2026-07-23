import Foundation

runCoreTests()
runMigrationTests()

print("\(passed) passed, \(failed) failed")
exit(failed > 0 ? 1 : 0)
