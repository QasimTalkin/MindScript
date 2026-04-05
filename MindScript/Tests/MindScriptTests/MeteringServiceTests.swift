import XCTest
@testable import MindScript

final class MeteringServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Reset cache before each test
        UserDefaults.standard.removeObject(forKey: "metering_monthly_seconds")
        UserDefaults.standard.removeObject(forKey: "metering_month")
    }

    func testUsageCacheAccumulates() {
        UsageCache.monthlySeconds = 0
        UsageCache.add(60)
        UsageCache.add(120)
        XCTAssertEqual(UsageCache.monthlySeconds, 180, accuracy: 0.001)
    }

    func testMonthlyResetOnNewMonth() {
        // Simulate a previous month entry
        UserDefaults.standard.set(1800.0, forKey: "metering_monthly_seconds")
        UserDefaults.standard.set("1999-01", forKey: "metering_month")  // old month

        // Reading should trigger a reset
        let seconds = UsageCache.monthlySeconds
        XCTAssertEqual(seconds, 0, "Cache should reset when month changes")
    }

    @MainActor
    func testFreeTierAllowsUnderLimit() async {
        AppState.shared.userTier = .free
        UsageCache.monthlySeconds = 0
        let allowed = await MeteringService.shared.checkAndIncrement(durationSeconds: 60)
        XCTAssertTrue(allowed)
    }

    @MainActor
    func testFreeTierBlocksAtLimit() async {
        AppState.shared.userTier = .free
        // Set usage just under the limit, then add enough to exceed it
        UsageCache.monthlySeconds = Constants.freeMonthlyLimitSeconds - 10
        let allowed = await MeteringService.shared.checkAndIncrement(durationSeconds: 30)
        XCTAssertFalse(allowed, "Should block when limit is exceeded")
    }

    @MainActor
    func testProTierAlwaysAllowed() async {
        AppState.shared.userTier = .pro
        UsageCache.monthlySeconds = Constants.freeMonthlyLimitSeconds + 1000
        let allowed = await MeteringService.shared.checkAndIncrement(durationSeconds: 300)
        XCTAssertTrue(allowed, "Pro tier should never be blocked")
    }
}
