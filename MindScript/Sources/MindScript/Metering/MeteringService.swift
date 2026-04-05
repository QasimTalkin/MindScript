import Foundation
import os

/// Tracks monthly transcription usage for the freemium model.
///
/// Free tier: 60 min/month local, zero cost.
/// Pro tier: unlimited.
///
/// Strategy:
/// - Increment the local UserDefaults counter immediately (no network call on hot path)
/// - Sync to Supabase in the background, at most once per hour
/// - If Supabase is unreachable, allow the transcription (never punish users for our infra)
@MainActor
final class MeteringService {
    static let shared = MeteringService()

    private init() {}

    // MARK: - Check + increment

    /// Returns `true` if transcription is allowed. Increments the counter if allowed.
    /// Called AFTER transcription completes (not before) to avoid network latency on hot path.
    func checkAndIncrement(durationSeconds: Double) async -> Bool {
        // Pro users: always allowed
        if AppState.shared.userTier == .pro {
            syncUsageToServer(seconds: durationSeconds)
            return true
        }

        // Free users: check limit
        let current = UsageCache.monthlySeconds
        let limit = Constants.freeMonthlyLimitSeconds

        if current + durationSeconds > limit {
            Logger.metering.info("Limit reached: \(current, format: .fixed(precision: 0))s / \(limit)s")
            return false
        }

        // Increment locally
        UsageCache.add(durationSeconds)
        AppState.shared.monthlySecondsUsed = UsageCache.monthlySeconds

        // Background sync to Supabase (non-blocking)
        syncUsageToServer(seconds: durationSeconds)

        return true
    }

    // MARK: - Server sync

    /// Syncs current month usage from Supabase. Called on launch and after sign-in.
    func syncFromServer() async {
        guard AppState.shared.isSignedIn,
              let userId = SessionStore.userId else { return }

        struct MonthlyUsage: Decodable {
            let totalSeconds: Double?
            enum CodingKeys: String, CodingKey { case totalSeconds = "total_seconds" }
        }

        do {
            let result: MonthlyUsage = try await AuthManager.shared.supabaseClient
                .from("monthly_usage")
                .select("total_seconds")
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value

            let serverSeconds = result.totalSeconds ?? 0
            UsageCache.monthlySeconds = serverSeconds
            AppState.shared.monthlySecondsUsed = serverSeconds
            UsageCache.lastSyncDate = Date()
            Logger.metering.info("Synced from server: \(serverSeconds, format: .fixed(precision: 0))s used this month")
        } catch {
            // Not a fatal error — offline resilience is a feature
            Logger.metering.info("Server sync skipped (offline or no data): \(error)")
        }
    }

    // MARK: - Private

    private func syncUsageToServer(seconds: Double) {
        guard AppState.shared.isSignedIn,
              let userId = SessionStore.userId else { return }

        Task {
            do {
                struct UsageEvent: Encodable {
                    let userId: String
                    let durationSeconds: Double
                    enum CodingKeys: String, CodingKey {
                        case userId = "user_id"
                        case durationSeconds = "duration_seconds"
                    }
                }
                try await AuthManager.shared.supabaseClient
                    .from("usage_events")
                    .insert(UsageEvent(userId: userId, durationSeconds: seconds))
                    .execute()

                Logger.metering.debug("Usage event inserted: \(seconds, format: .fixed(precision: 1))s")
            } catch {
                Logger.metering.error("Usage event insert failed: \(error)")
            }
        }
    }
}
