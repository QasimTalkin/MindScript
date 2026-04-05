import Foundation

enum Constants {
    // Freemium limits
    static let freeMonthlyLimitSeconds: Double = 3600   // 60 minutes
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
}
