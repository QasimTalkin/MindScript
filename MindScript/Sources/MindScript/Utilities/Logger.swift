import os

extension Logger {
    private static let subsystem = "com.mindscript.app"

    static let app          = Logger(subsystem: subsystem, category: "App")
    static let recording    = Logger(subsystem: subsystem, category: "Recording")
    static let transcription = Logger(subsystem: subsystem, category: "Transcription")
    static let injection    = Logger(subsystem: subsystem, category: "Injection")
    static let metering     = Logger(subsystem: subsystem, category: "Metering")
    static let auth         = Logger(subsystem: subsystem, category: "Auth")
}
