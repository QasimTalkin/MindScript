import Foundation
import os

// MARK: - Types

enum AISummarisationProviderType: String, Codable, CaseIterable, Identifiable {
    case ollama    = "Ollama"
    case openai    = "OpenAI"
    case anthropic = "Anthropic"

    var id: String { rawValue }

    /// Whether this provider needs an API key to function.
    var requiresApiKey: Bool {
        switch self {
        case .ollama:    return false
        case .openai:    return true
        case .anthropic: return true
        }
    }

    /// Human-readable default model name shown in Settings.
    var defaultModel: String {
        switch self {
        case .ollama:    return "glm-4.7-flash:latest"
        case .openai:    return "gpt-4o-mini"
        case .anthropic: return "claude-3-haiku-20240307"
        }
    }
}

enum AISummarisationError: LocalizedError {
    case invalidURL
    case configurationMissing(String)
    case apiError(Int, String)
    case emptyResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid AI provider URL."
        case .configurationMissing(let field):
            return "AI configuration missing: \(field)."
        case .apiError(let code, let body):
            return "AI API error (\(code)): \(body)"
        case .emptyResponse:
            return "AI returned an empty summary."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Protocol

protocol AISummarisationProvider {
    /// Summarise a voice-note transcription using the given model + optional API key.
    func summarise(text: String, model: String, apiKey: String?) async throws -> String
}

// MARK: - Shared (private)

/// Single prompt used by ALL providers.
/// Stability requirement: produce only bullets, never hallucinate.
private let kSummarisationPrompt = """
You are a precise note summariser. Given a raw voice note transcription, \
produce a concise, accurate bullet-point summary.

Rules:
• Preserve all proper nouns, numbers, dates, and technical terms exactly as spoken.
• Remove filler words (um, uh, like, you know) and false starts.
• Group closely related ideas under one bullet.
• Never add information the speaker did not say.
• Output only the bullet points — no title, no preamble, no sign-off.
"""

// MARK: - Providers

// ── Ollama ──────────────────────────────────────────────────────────────────

struct OllamaProvider: AISummarisationProvider {
    func summarise(text: String, model: String, apiKey: String?) async throws -> String {
        let url = URL(string: "http://localhost:11434/api/generate")!

        let body: [String: Any] = [
            "model":  model,
            "prompt": "\(kSummarisationPrompt)\n\nTranscription:\n\"\"\"\n\(text)\n\"\"\"",
            "stream": false
        ]

        let data = try await postJSON(to: url, body: body, headers: [:])

        struct Response: Decodable { let response: String }
        let r = try JSONDecoder().decode(Response.self, from: data)
        let summary = r.response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else { throw AISummarisationError.emptyResponse }
        return summary
    }
}

// ── OpenAI (or any OpenAI-compatible endpoint) ───────────────────────────────

struct OpenAIProvider: AISummarisationProvider {
    func summarise(text: String, model: String, apiKey: String?) async throws -> String {
        guard let key = apiKey, !key.isEmpty else {
            throw AISummarisationError.configurationMissing("OpenAI API key")
        }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        let body: [String: Any] = [
            "model": model,
            "temperature": 0,
            "messages": [
                ["role": "system",  "content": kSummarisationPrompt],
                ["role": "user",    "content": "Transcription:\n\"\"\"\n\(text)\n\"\"\""]
            ]
        ]
        let headers = ["Authorization": "Bearer \(key)"]
        let data = try await postJSON(to: url, body: body, headers: headers)

        struct Response: Decodable {
            struct Choice: Decodable { struct Message: Decodable { let content: String }; let message: Message }
            let choices: [Choice]
        }
        let r = try JSONDecoder().decode(Response.self, from: data)
        let summary = r.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !summary.isEmpty else { throw AISummarisationError.emptyResponse }
        return summary
    }
}

// ── Anthropic / Claude ────────────────────────────────────────────────────────

struct AnthropicProvider: AISummarisationProvider {
    func summarise(text: String, model: String, apiKey: String?) async throws -> String {
        guard let key = apiKey, !key.isEmpty else {
            throw AISummarisationError.configurationMissing("Anthropic API key")
        }
        let url = URL(string: "https://api.anthropic.com/v1/messages")!

        let body: [String: Any] = [
            "model":      model,
            "max_tokens": 1024,
            "system":     kSummarisationPrompt,
            "messages": [
                ["role": "user", "content": "Transcription:\n\"\"\"\n\(text)\n\"\"\""]
            ]
        ]
        let headers = [
            "x-api-key":         key,
            "anthropic-version": "2023-06-01"
        ]
        let data = try await postJSON(to: url, body: body, headers: headers)

        struct Response: Decodable {
            struct Block: Decodable { let text: String }
            let content: [Block]
        }
        let r = try JSONDecoder().decode(Response.self, from: data)
        let summary = r.content.first?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !summary.isEmpty else { throw AISummarisationError.emptyResponse }
        return summary
    }
}

// MARK: - Shared HTTP helper (private)

/// POST JSON, return response body. Throws `AISummarisationError` on non-2xx.
private func postJSON(to url: URL, body: [String: Any], headers: [String: String]) async throws -> Data {
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.addValue("application/json", forHTTPHeaderField: "Content-Type")
    for (k, v) in headers { req.addValue(v, forHTTPHeaderField: k) }
    req.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response): (Data, URLResponse)
    do {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180 // 3 minutes
        config.timeoutIntervalForResource = 300 // 5 minutes
        let session = URLSession(configuration: config)
        (data, response) = try await session.data(for: req)
    } catch {
        throw AISummarisationError.networkError(error)
    }

    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(status) else {
        let msg = String(data: data, encoding: .utf8) ?? "no body"
        throw AISummarisationError.apiError(status, msg)
    }
    return data
}

// MARK: - Service

actor SummarisationService {
    static let shared = SummarisationService()
    private let logger = Logger(subsystem: "com.mindscript.app", category: "Summarisation")
    private init() {}

    func summarise(text: String) async throws -> String {
        let state = AppState.shared
        let providerType = state.summarizationProviderType
        let model        = state.summarizationModel
        let apiKey       = state.summarizationApiKey

        let provider: AISummarisationProvider = switch providerType {
        case .ollama:    OllamaProvider()
        case .openai:    OpenAIProvider()
        case .anthropic: AnthropicProvider()
        }

        logger.info("Summarising with \(providerType.rawValue) / \(model)")

        await MainActor.run {
            state.isSummarizing = true
            state.lastSummary   = ""
        }

        do {
            let summary = try await provider.summarise(text: text, model: model, apiKey: apiKey)
            await MainActor.run { state.lastSummary = summary }
            logger.info("Summary ready (\(summary.count) chars)")
            await MainActor.run { state.isSummarizing = false }
            return summary
        } catch {
            logger.error("Summarisation failed: \(error.localizedDescription)")
            await MainActor.run { state.isSummarizing = false }
            throw error
        }
    }
}
