import Foundation

enum Constants {
    // Tier model names
    static let freeTierModelName = "openai_whisper-tiny"
    static let proTierModelName  = "openai_whisper-base"

    /// Repo-local directory where WhisperKit models are downloaded.
    /// Stored in <repo>/mindscript/Models/ and gitignored.
    static let modelsDirectory: URL = {
        // Walk up from this source file: Sources/MindScript/Utilities/ → Sources/MindScript/ → Sources/ → package root
        let here = URL(fileURLWithPath: #file)
        let packageRoot = here
            .deletingLastPathComponent()  // Utilities/
            .deletingLastPathComponent()  // MindScript/
            .deletingLastPathComponent()  // Sources/
            .deletingLastPathComponent()  // MindScript package root
        return packageRoot.appendingPathComponent("Models", isDirectory: true)
    }()

    // Metering — set to .infinity for fully local builds (no server-side limit)
    static let freeMonthlyLimitSeconds: Double = .infinity
    static let meteringSyncIntervalSeconds: TimeInterval = 3600
    static let meteringAnonymousGraceDays: Int = 7

    // Backend — fill in after creating your Supabase project
    static let supabaseURL      = "https://YOUR_PROJECT.supabase.co"
    static let supabaseAnonKey  = "YOUR_ANON_KEY"

    // Payments — fill in after creating your Stripe product
    static let stripeProMonthlyURL = "https://buy.stripe.com/YOUR_LINK"

    // Audio
    static let audioSampleRate: Double   = 16_000
    static let audioChannelCount: UInt32 = 1

    // Languages
    static let supportedLanguages: [(name: String, code: String?)] = [
        ("Auto-detect",  nil),
        ("English",      "en"),
        ("Spanish",      "es"),
        ("French",       "fr"),
        ("German",       "de"),
        ("Italian",      "it"),
        ("Portuguese",   "pt"),
        ("Russian",      "ru"),
        ("Chinese",      "zh"),
        ("Japanese",     "ja"),
        ("Korean",       "ko"),
        ("Arabic",       "ar"),
        ("Hindi",        "hi"),
        ("Urdu",         "ur"),
        ("Turkish",      "tr"),
        ("Dutch",        "nl"),
        ("Polish",       "pl"),
    ]
}
