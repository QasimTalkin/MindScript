import Foundation
import Supabase
import os

/// Manages authentication via Supabase.
/// Supports email magic-link and Apple Sign In.
@MainActor
final class AuthManager {
    static let shared = AuthManager()

    private let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Constants.supabaseURL)!,
            supabaseKey: Constants.supabaseAnonKey
        )
    }

    // MARK: - Session restoration

    func restoreSession() async {
        do {
            let session = try await client.auth.session
            SessionStore.accessToken = session.accessToken
            SessionStore.userId = session.user.id.uuidString
            AppState.shared.isSignedIn = true
            AppState.shared.userEmail = session.user.email
            await refreshProfile()
            Logger.auth.info("Session restored for \(session.user.email ?? "unknown")")
        } catch {
            Logger.auth.info("No existing session")
        }
    }

    // MARK: - Sign in

    func signInWithEmail(_ email: String) async throws {
        try await client.auth.signInWithOTP(email: email)
        Logger.auth.info("Magic link sent to \(email)")
    }

    func signInWithApple() async throws {
        // Launches native Apple Sign In sheet, handled by Supabase SDK
        try await client.auth.signInWithOAuth(provider: .apple)
    }

    // MARK: - Sign out

    func signOut() async throws {
        try await client.auth.signOut()
        SessionStore.accessToken = nil
        SessionStore.userId = nil
        AppState.shared.isSignedIn = false
        AppState.shared.userEmail = nil
        AppState.shared.userTier = .free
        Logger.auth.info("Signed out")
    }

    // MARK: - Profile

    func refreshProfile() async {
        guard let userId = SessionStore.userId else { return }

        struct Profile: Decodable {
            let tier: String
        }

        do {
            let profile: Profile = try await client
                .from("profiles")
                .select("tier")
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            AppState.shared.userTier = profile.tier == "pro" ? .pro : .free
            Logger.auth.info("Profile refreshed — tier: \(profile.tier)")
        } catch {
            Logger.auth.error("Profile refresh failed: \(error)")
        }
    }

    // MARK: - Internal client access for MeteringService

    var supabaseClient: SupabaseClient { client }
}
