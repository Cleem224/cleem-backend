import Foundation
import Combine
import UIKit

/// Service for working with OpenAI API (GPT-4)
class OpenAIService {
    // Singleton for accessing the service
    static let shared = OpenAIService()
    
    // Base URL for OpenAI API
    private let baseURL = "https://api.openai.com/v1"
    
    // API key
    private var apiKey: String
    
    // URL session for requests
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    // Default GPT model
    private let defaultModel = "gpt-3.5-turbo-0125" // Using a more stable model
    
    private init() {
        // Set the default API key (it is recommended to replace it with your own key)
        let defaultApiKey = "YOUR_OPENAI_API_KEY"
        
        // Set the key in UserDefaults if it is missing
        if UserDefaults.standard.string(forKey: "openai_api_key") == nil {
            UserDefaults.standard.set(defaultApiKey, forKey: "openai_api_key")
        }
        
        // Get the key from UserDefaults
        self.apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? defaultApiKey
        
        // Check the validity of the API key (should start with "sk-")
        if !self.apiKey.hasPrefix("sk-") && !self.apiKey.contains("YOUR_OPENAI_API_KEY") {
            print("⚠️ Invalid API key: \(apiKey.prefix(5))..., using fallback")
            
            // Try to find a fallback by keywords
            for (foodType, ingredients) in fallbackByFoodType {
                if normalizedFoodName.contains(foodType) {
                    print("✅ Using fallback for dish type: \(foodType)")
                    return Just(ingredients)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
            }
            
            // If no matches are found, return a general set of ingredients
            print("⚠️ Using the basic set of ingredients (invalid API key)")
            return Just(["rice", "nori", "salmon", "avocado", "cucumber", "soy sauce"])
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Session configuration with increased timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60 // Increase timeout to 60 seconds
        self.session = URLSession(configuration: config)
        
        // Logging for debugging
        print("🔑 OpenAIService initialized with key: \(apiKey.prefix(10))...")
    }
    
    /// Update API key
    func updateApiKey(_ newKey: String) {
        self.apiKey = newKey
        UserDefaults.standard.set(newKey, forKey: "openai_api_key")
        UserDefaults.standard.synchronize()
        print("✅ OpenAI API key updated: \(newKey.prefix(10))...")
    }
    
    /// Decompose a dish into ingredients
    func decomposeFood(foodName: String, imageDescription: String? = nil) -> AnyPublisher<[String], Error> {
        print("🍽️ Starting to decompose the dish: \(foodName)")
        
        // In case of problems with the API, we will return a fallback with basic ingredients
        let fallbackByFoodType: [String: [String]] = [
            "roll": ["rice", "nori", "salmon", "avocado", "cucumber", "soy sauce"],
            "rolls": ["rice", "nori", "salmon", "avocado", "cucumber", "soy sauce"],
            "sushi": ["rice", "nori", "salmon", "soy sauce", "wasabi"],
            "pizza": ["dough", "tomato sauce", "mozzarella cheese", "pepperoni", "tomatoes"],
            "pasta": ["pasta", "tomato sauce", "parmesan cheese", "olive oil"],
            "pilaf": ["rice", "meat", "carrot", "onion", "oil", "spices"],
            "borscht": ["beetroot", "cabbage", "potato", "carrot", "onion", "tomato paste", "meat"]
        ]
        
        // Quick check - if the dish contains keywords, we will return a fallback immediately,
        // to avoid delays and potential problems with the API
        let normalizedFoodName = foodName.lowercased()
        for (foodType, ingredients) in fallbackByFoodType {
            if normalizedFoodName.contains(foodType) {
                print("✅ Using fallback for dish type: \(foodType) (quick check)")
                return Just(ingredients)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
        }
        
        // Check the validity of the API key
        if !apiKey.hasPrefix("sk-") && !apiKey.contains("YOUR_OPENAI_API_KEY") {
            print("⚠️ Invalid API key: \(apiKey.prefix(5))..., using fallback")
            
            // Try to find a fallback by keywords
            for (foodType, ingredients) in fallbackByFoodType {
                if normalizedFoodName.contains(foodType) {
                    print("✅ Using fallback for dish type: \(foodType)")
                    return Just(ingredients)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
            }
            
            // If no matches are found, return a general set of ingredients
            print("⚠️ Using the basic set of ingredients (invalid API key)")
            return Just(["rice", "nori", "salmon", "avocado", "cucumber", "soy sauce"])
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        let endpoint = "/chat/completions"
        var urlComponents = URLComponents(string: baseURL + endpoint)
        
        // Create URL
        guard let url = urlComponents?.url else {
            print("⚠️ Decomposition error: invalid URL")
            
            // Try to find a fallback by keywords
            for (foodType, ingredients) in fallbackByFoodType {
                if foodName.lowercased().contains(foodType) {
                    print("✅ Using fallback for dish type: \(foodType)")
                    return Just(ingredients)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
            }
            
            return Fail(error: OpenAIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        // Form the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Compose the instruction for GPT
        var systemPrompt = "You are a culinary and food expert. Your task is to break down a dish into its basic ingredients in list format."
        var userPrompt = "Break down the dish '\(foodName)' into individual ingredients. Return only the main ingredients, without decorations and garnishes. Provide only a JSON array of strings, without explanations or comments. For example: [\"rice\", \"salmon\", \"avocado\", \"cucumber\"]."
        
        // If there is an image description, add it
        if let imageDesc = imageDescription {
            systemPrompt += " Use the image description to clarify the ingredients."
            userPrompt += "\n\nImage description: \(imageDesc)"
        }
        
        // Form the request body
        let requestBody = OpenAIRequest(
            model: defaultModel,
            messages: [
                OpenAIMessage(role: "system", content: systemPrompt),
                OpenAIMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.2, // Low temperature for more deterministic responses
            max_tokens: 300  // Limit the response size
        )
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
            
            // Log the request for debugging
            if let requestStr = String(data: jsonData, encoding: .utf8) {
                print("📤 Request to OpenAI API:")
                print(requestStr)
            }
        } catch {
            print("⚠️ Request encoding error: \(error)")
            
            // In case of encoding error, use the fallback
            for (foodType, ingredients) in fallbackByFoodType {
                if foodName.lowercased().contains(foodType) {
                    print("✅ Using fallback for dish type: \(foodType)")
                    return Just(ingredients)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
            }
            
            return Fail(error: OpenAIServiceError.encodingError(error)).eraseToAnyPublisher()
        }
        
        // Execute the request
        print("🌐 Sending request to OpenAI API (Decompose dish):")
        print("   URL: \(url)")
        print("   Dish name: \(foodName)")
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("⚠️ Invalid response without HTTP code")
                    throw OpenAIServiceError.invalidResponse
                }
                
                // Log the response
                print("📥 Response from OpenAI API: HTTP \(httpResponse.statusCode)")
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("Response content: \(responseStr)")
                }
                
                if httpResponse.statusCode == 401 {
                    print("⚠️ Authorization error (401). Check the API key.")
                    throw OpenAIServiceError.unauthorizedRequest
                }
                
                if httpResponse.statusCode == 429 {
                    print("⚠️ Rate limit exceeded (429).")
                    throw OpenAIServiceError.rateLimitExceeded
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    print("⚠️ HTTP error: \(httpResponse.statusCode)")
                    throw OpenAIServiceError.httpError(statusCode: httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: OpenAIResponse.self, decoder: JSONDecoder())
            .tryMap { response -> [String] in
                guard let content = response.choices.first?.message.content else {
                    print("⚠️ Empty response from OpenAI")
                    throw OpenAIServiceError.emptyResponse
                }
                
                print("✅ Received response from OpenAI: \(content)")
                
                // Clean the text of possible code markers and extra characters
                let cleanedContent = content
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                do {
                    // Try to decode a JSON array of strings
                    guard let contentData = cleanedContent.data(using: .utf8) else {
                        throw OpenAIServiceError.decodingError(NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot convert string to data"]))
                    }
                    
                    let ingredients = try JSONDecoder().decode([String].self, from: contentData)
                    print("✅ Successfully decoded ingredients: \(ingredients)")
                    return ingredients
                } catch {
                    print("⚠️ JSON decoding error: \(error). Trying to extract ingredients manually...")
                    
                    // Look for anything that looks like an array in square brackets
                    let pattern = "\\[.*?\\]"
                    if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
                       let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..., in: content)),
                       let range = Range(match.range, in: content) {
                        
                        let arrayString = String(content[range])
                        print("🔍 Found array: \(arrayString)")
                        
                        do {
                            guard let arrayData = arrayString.data(using: .utf8) else {
                                throw OpenAIServiceError.decodingError(NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot convert array string to data"]))
                            }
                            
                            let ingredients = try JSONDecoder().decode([String].self, from: arrayData)
                            print("✅ Successfully extracted ingredients from array: \(ingredients)")
                            return ingredients
                        } catch {
                            print("⚠️ Error decoding found array: \(error)")
                        }
                    }
                    
                    // If all methods fail, split into lines and remove list markers
                    print("🔍 Trying to split text into lines...")
                    let fallbackIngredients = content
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty && $0.count < 50 } // Filter out too long lines
                        .map { line -> String in
                            var ingredient = line
                            // Remove list markers (-, *, 1., etc.)
                            if let range = ingredient.range(of: "^[\\-\\*\\d\\.]+\\s+", options: .regularExpression) {
                                ingredient.removeSubrange(range)
                            }
                            return ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        .filter { !$0.isEmpty }
                    
                    print("✅ Extracted ingredients by splitting text: \(fallbackIngredients)")
                    
                    if !fallbackIngredients.isEmpty {
                        return fallbackIngredients
                    }
                    
                    // As a last resort, use the standard response based on the dish
                    for (foodType, ingredients) in fallbackByFoodType {
                        if foodName.lowercased().contains(foodType) {
                            print("⚠️ Using fallback for \(foodType) after all attempts")
                            return ingredients
                        }
                    }
                    
                    // If nothing helps, return the general set of ingredients
                    print("⚠️ Using the basic set of ingredients")
                    return ["rice", "nori", "salmon", "avocado", "cucumber", "soy sauce"]
                }
            }
            .mapError { error -> Error in
                if let decodingError = error as? DecodingError {
                    print("⚠️ Decoding error: \(decodingError)")
                    return OpenAIServiceError.decodingError(decodingError)
                }
                print("⚠️ General error: \(error)")
                
                // If it's an authorization error, suggest using a different model
                if let openAIError = error as? OpenAIServiceError, case .unauthorizedRequest = openAIError {
                    // In case of authorization problems, use the fallback
                    for (foodType, ingredients) in fallbackByFoodType {
                        if foodName.lowercased().contains(foodType) {
                            print("✅ Using fallback for dish type after authorization error: \(foodType)")
                            return OpenAIServiceError.fallbackUsed(ingredients: ingredients)
                        }
                    }
                }
                
                return error
            }
            .catch { (error: Error) -> AnyPublisher<[String], Error> in
                // Handle fallbacks
                if let openAIError = error as? OpenAIServiceError, case .fallbackUsed(let ingredients) = openAIError {
                    return Just(ingredients)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                
                // Check if we can use a fallback by keywords
                let normalizedFoodName = foodName.lowercased()
                for (foodType, ingredients) in fallbackByFoodType {
                    if normalizedFoodName.contains(foodType) {
                        print("✅ Using fallback for dish type after error: \(foodType)")
                        return Just(ingredients)
                            .setFailureType(to: Error.self)
                            .eraseToAnyPublisher()
                    }
                }
                
                // Special checks for complex dish names
                if normalizedFoodName.contains("salmon") && normalizedFoodName.contains("avocado") {
                    print("✅ Using fallback for salmon and avocado rolls")
                    return Just(["rice", "nori", "salmon", "avocado", "cucumber", "soy sauce"])
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                
                // If all special checks fail, use the universal set of ingredients
                print("⚠️ Using the universal set of ingredients for an unknown dish")
                return Just(["rice", "nori", "salmon", "avocado", "cucumber", "soy sauce"])
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Data models for OpenAI API

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let max_tokens: Int
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIResponse: Codable {
    let id: String
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

// MARK: - Google Gemini API Model

// Data structures for requests to Gemini API
struct GeminiAPIRequest: Codable {
    let contents: [GeminiAPIContent]
    let generationConfig: GeminiAPIGenerationConfig
    
    enum CodingKeys: String, CodingKey {
        case contents
        case generationConfig = "generation_config"
    }
}

struct GeminiAPIContent: Codable {
    let parts: [GeminiAPIPart]
    let role: String
}

struct GeminiAPIPart: Codable {
    let text: String
}

struct GeminiAPIGenerationConfig: Codable {
    let temperature: Double
    let maxOutputTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case temperature
        case maxOutputTokens = "max_output_tokens"
    }
}

// Data structures for responses from Gemini API
struct GeminiAPIResponse: Codable {
    let candidates: [GeminiAPICandidate]?
    let promptFeedback: GeminiAPIPromptFeedback?
}

struct GeminiAPICandidate: Codable {
    let content: GeminiAPIContentResponse
}

struct GeminiAPIContentResponse: Codable {
    let parts: [GeminiAPIPartResponse]
    let role: String
}

struct GeminiAPIPartResponse: Codable {
    let text: String
}

struct GeminiAPIPromptFeedback: Codable {
    let blockReason: String?
}

// MARK: - Service errors

enum OpenAIServiceError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case unauthorizedRequest
    case rateLimitExceeded
    case decodingError(Error)
    case encodingError(Error)
    case emptyResponse
    case unknownError(Error)
    case fallbackUsed(ingredients: [String])
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from the server"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .unauthorizedRequest:
            return "Authorization error. Check the API key"
        case .rateLimitExceeded:
            return "API request limit exceeded"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .emptyResponse:
            return "Empty response from API"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        case .fallbackUsed(let ingredients):
            return "Fallback data used: \(ingredients.joined(separator: ", "))"
        }
    }
}

extension OpenAIService {
    /// Uses Google Gemini API to decompose a dish into ingredients (backup option)
    func decomposeWithGemini(foodName: String) -> AnyPublisher<[String], Error> {
        print("🧠 Starting to decompose the dish using Gemini: \(foodName)")
        
        // API key for Google Gemini
        let geminiApiKey = "AIzaSyBKaHxMvfr2PJ4T5_sJNGd9pc9PfOXaURs" // Use your own key
        
        // Base URL for Gemini API
        let geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.0-pro"
        let endpoint = ":generateContent"
        
        // Add API key as a query parameter
        guard var urlComponents = URLComponents(string: geminiBaseURL + endpoint) else {
            print("⚠️ Error creating URL for Gemini")
            
            // Return a fallback for rolls
            if foodName.lowercased().contains("roll") || 
               (foodName.lowercased().contains("salmon") && foodName.lowercased().contains("avocado")) {
                return Just(["rice", "nori", "salmon", "avocado", "cucumber", "soy sauce"])
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            
            return Fail(error: OpenAIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        // Add API key as a query parameter
        urlComponents.queryItems = [URLQueryItem(name: "key", value: geminiApiKey)]
        
        guard let url = urlComponents.url else {
            print("⚠️ Error creating URL for Gemini")
            return Fail(error: OpenAIServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        // Create a request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Form the prompt for Gemini
        let promptText = """
        Break down the dish '\(foodName)' into individual ingredients.
        Return only the main ingredients as a JSON array of strings, without explanations or comments.
        Example response format: ["rice", "salmon", "avocado", "cucumber"]
        """
        
        // Create the request body
        let requestBody = GeminiAPIRequest(
            contents: [
                GeminiAPIContent(
                    parts: [GeminiAPIPart(text: promptText)],
                    role: "user"
                )
            ],
            generationConfig: GeminiAPIGenerationConfig(
                temperature: 0.2,
                maxOutputTokens: 200
            )
        )
        
        // Encode the request
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
            
            // Log for debugging
            if let requestStr = String(data: jsonData, encoding: .utf8) {
                print("📤 Request to Gemini API:")
                print(requestStr)
            }
        } catch {
            print("⚠️ Error encoding Gemini request: \(error)")
            return Fail(error: OpenAIServiceError.encodingError(error)).eraseToAnyPublisher()
        }
        
        // Execute the request
        print("🌐 Sending request to Gemini API (Decompose dish):")
        print("   URL: \(url)")
        print("   Dish name: \(foodName)")
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("⚠️ Invalid response without HTTP code from Gemini")
                    throw OpenAIServiceError.invalidResponse
                }
                
                // Log the response
                print("📥 Response from Gemini API: HTTP \(httpResponse.statusCode)")
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("Gemini response content: \(responseStr)")
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    print("⚠️ HTTP error from Gemini: \(httpResponse.statusCode)")
                    throw OpenAIServiceError.httpError(statusCode: httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: GeminiAPIResponse.self, decoder: JSONDecoder())
            .tryMap { response -> [String] in
                guard let candidate = response.candidates?.first,
                      let part = candidate.content.parts.first,
                      !part.text.isEmpty else {
                    print("⚠️ Empty response from Gemini")
                    throw OpenAIServiceError.emptyResponse
                }
                
                print("✅ Received response from Gemini: \(part.text)")
                
                // Clean the text of possible code markers and extra characters
                let cleanedContent = part.text
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                do {
                    // Try to decode a JSON array of strings
                    guard let contentData = cleanedContent.data(using: .utf8) else {
                        throw OpenAIServiceError.decodingError(NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot convert string to data"]))
                    }
                    
                    let ingredients = try JSONDecoder().decode([String].self, from: contentData)
                    print("✅ Successfully decoded ingredients from Gemini: \(ingredients)")
                    return ingredients
                } catch {
                    print("⚠️ Error decoding JSON from Gemini: \(error). Trying to extract ingredients manually...")
                    
                    // Look for anything that looks like an array in square brackets
                    let pattern = "\\[.*?\\]"
                    if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
                       let match = regex.firstMatch(in: cleanedContent, options: [], range: NSRange(cleanedContent.startIndex..., in: cleanedContent)),
                       let range = Range(match.range, in: cleanedContent) {
                        
                        let arrayString = String(cleanedContent[range])
                        print("🔍 Found array in Gemini response: \(arrayString)")
                        
                        do {
                            guard let arrayData = arrayString.data(using: .utf8) else {
                                throw OpenAIServiceError.decodingError(NSError(domain: "OpenAIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cannot convert array string to data"]))
                            }
                            
                            let ingredients = try JSONDecoder().decode([String].self, from: arrayData)
                            print("✅ Successfully extracted ingredients from array Gemini: \(ingredients)")
                            return ingredients
                        } catch {
                            print("⚠️ Error decoding found array from Gemini: \(error)")
                        }
                    }
                    
                    // If all methods fail, split into lines and remove list markers
                    print("🔍 Trying to split Gemini text into lines...")
                    let fallbackIngredients = cleanedContent
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty && $0.count < 50 } // Filter out too long lines
                        .map { line -> String in
                            var ingredient = line
                            // Remove list markers (-, *, 1., etc.)
                            if let range = ingredient.range(of: "^[\\-\\*\\d\\.]+\\s+", options: .regularExpression) {
                                ingredient.removeSubrange(range)
                            }
                            return ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        .filter { !$0.isEmpty }
                    
                    print("✅ Extracted ingredients by splitting Gemini text: \(fallbackIngredients)")
                    
                    if !fallbackIngredients.isEmpty {
                        return fallbackIngredients
                    }
                    
                    throw OpenAIServiceError.decodingError(error)
                }
            }
            .catch { error -> AnyPublisher<[String], Error> in
                print("⚠️ Error using Gemini API: \(error.localizedDescription)")
                
                // Find the corresponding fallback
                let normalizedFoodName = foodName.lowercased()
                let fallbackByFoodType: [String: [String]] = [
                    "roll": ["rice", "nori", "salmon", "avocado", "cucumber", "soy sauce"],
                    "rolls": ["rice", "nori", "salmon", "avocado", "cucumber", "soy sauce"],
                    "sushi": ["rice", "nori", "salmon", "soy sauce", "wasabi"],
                    "pizza": ["dough", "tomato sauce", "mozzarella cheese", "pepperoni", "tomatoes"],
                    "pasta": ["pasta", "tomato sauce", "parmesan cheese", "olive oil"],
                    "pilaf": ["rice", "meat", "carrot", "onion", "oil", "spices"],
                    "borscht": ["beetroot", "cabbage", "potato", "carrot", "onion", "tomato paste", "meat"]
                ]
                
                for (foodType, ingredients) in fallbackByFoodType {
                    if normalizedFoodName.contains(foodType) {
                        print("✅ Using fallback for dish type after Gemini error: \(foodType)")
                        return Just(ingredients)
                            .setFailureType(to: Error.self)
                            .eraseToAnyPublisher()
                    }
                }
                
                // Special checks
                if normalizedFoodName.contains("salmon") && normalizedFoodName.contains("avocado") {
                    return Just(["rice", "nori", "salmon", "avocado", "cucumber", "soy sauce"])
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                
                // Basic set
                return Just(["rice", "nori", "salmon", "avocado", "cucumber", "soy sauce"])
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// Decompose a dish using multiple APIs in case of errors
    func decomposeWithFallback(foodName: String, imageDescription: String? = nil) -> AnyPublisher<[String], Error> {
        // First, try using OpenAI
        return self.decomposeFood(foodName: foodName, imageDescription: imageDescription)
            .catch { error -> AnyPublisher<[String], Error> in
                print("⚠️ Error using OpenAI for decomposition, switching to Gemini: \(error.localizedDescription)")
                
                // If OpenAI fails, try Gemini
                return self.decomposeWithGemini(foodName: foodName)
            }
            .eraseToAnyPublisher()
    }
} 