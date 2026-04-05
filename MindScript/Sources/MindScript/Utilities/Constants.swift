import Foundation

enum Constants {
    // Limits — set to .infinity for fully local/free builds (no server cost)
    static let freeMonthlyLimitSeconds: Double = .infinity
    static let freeTierModelName = "openai_whisper-tiny"
    static let proTierModelName  = "openai_whisper-base"

    // Supabase — fill in after creating your project at supabase.com
    static let supabaseURL  = "https://YOUR_PROJECT.supabase.co"
    static let supabaseAnonKey = "YOUR_ANON_KEY"

    // Stripe — fill in after creating your products at stripe.com
    static let stripeProMonthlyURL = "https://buy.stripe.com/YOUR_LINK"

    // Metering cache
    static let meteringSyncIntervalSeconds: TimeInterval = 3600   // sync hourly
    static let meteringAnonymousGraceDays: Int = 7

    // Recording
    static let audioSampleRate: Double = 16_000
    static let audioChannelCount: UInt32 = 1

    // Injection
    static let injectionActivationDelayMs: UInt64 = 50

    // Languages — (display name, ISO 639-1 code). nil code = Whisper auto-detect.
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
