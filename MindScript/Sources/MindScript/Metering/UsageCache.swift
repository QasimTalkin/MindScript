import Foundation

/// Local UserDefaults cache for monthly usage.
/// Used to avoid a Supabase round-trip on every transcription.
enum UsageCache {
    private static let secondsKey   = "metering_monthly_seconds"
    private static let monthKey     = "metering_month"           // "2024-04" format
    private static let syncedAtKey  = "metering_synced_at"
    private static let firstLaunchKey = "metering_first_launch"

    static var monthlySeconds: Double {
        get {
            resetIfMonthChanged()
            return UserDefaults.standard.double(forKey: secondsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: secondsKey)
            UserDefaults.standard.set(currentMonthString, forKey: monthKey)
        }
    }

    static func add(_ seconds: Double) {
        monthlySeconds += seconds
    }

    static var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: syncedAtKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: syncedAtKey) }
    }

    static var firstLaunchDate: Date {
        if let date = UserDefaults.standard.object(forKey: firstLaunchKey) as? Date {
            return date
        }
        let now = Date()
        UserDefaults.standard.set(now, forKey: firstLaunchKey)
        return now
    }

    /// True if the user has been using the app for more than the grace period.
    static var isAnonymousGracePeriodOver: Bool {
        let days = Calendar.current.dateComponents([.day], from: firstLaunchDate, to: Date()).day ?? 0
        return days >= Constants.meteringAnonymousGraceDays
    }

    // MARK: - Month rollover

    private static var currentMonthString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }

    private static func resetIfMonthChanged() {
        let stored = UserDefaults.standard.string(forKey: monthKey) ?? ""
        if stored != currentMonthString {
            UserDefaults.standard.set(0.0, forKey: secondsKey)
            UserDefaults.standard.set(currentMonthString, forKey: monthKey)
        }
    }
}
