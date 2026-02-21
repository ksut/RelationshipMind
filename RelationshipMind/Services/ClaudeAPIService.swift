import Foundation

struct ClaudeAPIService {
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"

    struct ExtractionResponse: Codable {
        let summary: String
        let mentionedPeople: [MentionedPerson]
        let facts: [ExtractedFactData]

        enum CodingKeys: String, CodingKey {
            case summary
            case mentionedPeople = "mentioned_people"
            case facts
        }

        struct MentionedPerson: Codable {
            let name: String
            let relationshipToPrimary: String?
            let isPrimary: Bool

            enum CodingKeys: String, CodingKey {
                case name
                case relationshipToPrimary = "relationship_to_primary"
                case isPrimary = "is_primary"
            }
        }

        struct ExtractedFactData: Codable {
            let personName: String
            let category: String
            let key: String
            let value: String
            let factDate: String?
            let isTimeSensitive: Bool
            let timeProgression: String?
            let confidence: Double

            enum CodingKeys: String, CodingKey {
                case personName = "person_name"
                case category
                case key
                case value
                case factDate = "fact_date"
                case isTimeSensitive = "is_time_sensitive"
                case timeProgression = "time_progression"
                case confidence
            }
        }
    }

    func extractFromNote(
        note: String,
        primaryPersonName: String
    ) async throws -> ExtractionResponse {
        guard let storedKey = KeychainHelper.get(.claudeAPIKey), !storedKey.isEmpty else {
            throw ClaudeAPIError.noAPIKey
        }
        let apiKey = storedKey.trimmingCharacters(in: .whitespacesAndNewlines)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())

        let systemPrompt = """
        You are an AI assistant that extracts structured relationship data from personal conversation notes. Extract the following:
        1. A brief summary (1-2 sentences)
        2. People mentioned (with relationship context if stated)
        3. Structured facts about the PRIMARY person

        The primary person this note is about: \(primaryPersonName)
        Today's date: \(todayString)

        Return JSON in this exact format (no markdown, just raw JSON):
        {
          "summary": "...",
          "mentioned_people": [
            {
              "name": "...",
              "relationship_to_primary": "...",
              "is_primary": true/false
            }
          ],
          "facts": [
            {
              "person_name": "...",
              "category": "education|career|family|health|location|travel|interest|milestone|plan|general",
              "key": "...",
              "value": "...",
              "fact_date": "YYYY-MM-DD or null",
              "is_time_sensitive": true/false,
              "time_progression": "academicYear|age|tenure|none",
              "confidence": 0.0-1.0
            }
          ]
        }

        IMPORTANT Guidelines:
        - Always include the primary person in mentioned_people with is_primary: true
        - ALL facts should be attributed to the PRIMARY person (\(primaryPersonName)), NOT to mentioned family members
        - For family members mentioned, create facts about the primary person like:
          * "daughter Emma is in 2nd grade" → key: "daughter_name", value: "Emma" AND key: "daughter_grade", value: "2nd grade" (both for primary person)
          * "his wife works at Google" → key: "wife_company", value: "Google" (for primary person)
          * "son just started college" → key: "son_education", value: "College, 1st year" (for primary person)
        - Only extract facts that are explicitly stated or strongly implied
        - Use appropriate categories for each fact (family for family-related facts)
        - Set confidence lower (0.6-0.8) for inferred facts, higher (0.9-1.0) for explicit facts
        - For time_sensitive facts like education year, job tenure, or age, set is_time_sensitive: true
        - If no facts can be extracted, return an empty facts array
        - If no other people are mentioned, only include the primary person
        """

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": note]
            ],
            "system": systemPrompt
        ]

        guard let url = URL(string: baseURL) else {
            throw ClaudeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        request.httpBody = jsonData

        // Debug: print request
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("Claude API Request: \(jsonString)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            var errorMessage = "Status \(httpResponse.statusCode)"
            if let errorBody = String(data: data, encoding: .utf8) {
                print("Claude API Error: \(errorBody)")
                // Try to extract error message from response
                if let errorData = errorBody.data(using: .utf8),
                   let errorJSON = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
                   let error = errorJSON["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    errorMessage = message
                }
            }
            throw ClaudeAPIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Parse the Claude response
        let claudeResponse = try JSONDecoder().decode(ClaudeMessageResponse.self, from: data)

        guard let textContent = claudeResponse.content.first(where: { $0.type == "text" }),
              let jsonText = textContent.text else {
            throw ClaudeAPIError.noContent
        }

        // Clean up the JSON (remove markdown code blocks if present)
        let cleanedJSON = jsonText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            throw ClaudeAPIError.invalidJSON
        }

        let extraction = try JSONDecoder().decode(ExtractionResponse.self, from: jsonData)
        return extraction
    }
}

// MARK: - Claude API Response Types

private struct ClaudeMessageResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let stopReason: String?
    let usage: Usage

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
        case usage
    }

    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }

    struct Usage: Codable {
        let inputTokens: Int
        let outputTokens: Int

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }
}

// MARK: - Errors

enum ClaudeAPIError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case noContent
    case invalidJSON

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your Claude API key in Settings."
        case .invalidURL:
            return "Invalid API URL."
        case .invalidResponse:
            return "Invalid response from server."
        case .httpError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .noContent:
            return "No content in API response."
        case .invalidJSON:
            return "Failed to parse extraction results."
        }
    }
}
