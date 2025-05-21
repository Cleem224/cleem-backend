import Foundation
import Combine
import UIKit
import CoreData

/// Сервис для работы с Spoonacular API
class SpoonacularService {
    // Синглтон для доступа к сервису
    static let shared = SpoonacularService()
    
    // Базовый URL для Spoonacular API
    private let baseURL = "https://api.spoonacular.com"
    
    // API ключ
    private var apiKey: String
    
    // URL сессия для запросов
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Устанавливаем API ключ по умолчанию
        let defaultApiKey = "8306f242464448258f1b14a05c3598d2"
        
        // Устанавливаем ключ в UserDefaults, если отсутствует
        if UserDefaults.standard.string(forKey: "spoonacular_api_key") == nil {
            UserDefaults.standard.set(defaultApiKey, forKey: "spoonacular_api_key")
        }
        
        // Получаем ключ из UserDefaults
        self.apiKey = UserDefaults.standard.string(forKey: "spoonacular_api_key") ?? defaultApiKey
        
        // Конфигурация сессии
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        
        // Логирование для отладки
        print("🔑 SpoonacularService инициализирован с ключом: \(apiKey.prefix(10))...")
    }
    
    /// Обновление API ключа
    func updateApiKey(_ newKey: String) {
        self.apiKey = newKey
        UserDefaults.standard.set(newKey, forKey: "spoonacular_api_key")
        UserDefaults.standard.synchronize()
        print("✅ Spoonacular API ключ обновлен: \(newKey.prefix(10))...")
    }
    
    /// Получение информации о нутриентах для ингредиентов
    func getNutritionInfoForIngredients(ingredients: [String]) -> AnyPublisher<SpoonacularNutritionResponse, Error> {
        let endpoint = "/recipes/parseIngredients"
        var urlComponents = URLComponents(string: baseURL + endpoint)
        
        // Создаем URL
        guard let url = urlComponents?.url else {
            return Fail(error: SpoonacularServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        // Формируем запрос
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Формируем параметры
        var parameters: [String: String] = [
            "apiKey": apiKey,
            "includeNutrition": "true",
            "language": "ru"
        ]
        
        // Добавляем ингредиенты
        for (index, ingredient) in ingredients.enumerated() {
            parameters["ingredientList[\(index)]"] = ingredient
        }
        
        // Кодируем параметры для form-data
        let bodyString = parameters.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        // Выполняем запрос
        print("🌐 Отправка запроса к Spoonacular API (Parse Ingredients):")
        print("   URL: \(url)")
        print("   Ингредиенты: \(ingredients.joined(separator: ", "))")
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SpoonacularServiceError.invalidResponse
                }
                
                if httpResponse.statusCode == 401 {
                    throw SpoonacularServiceError.unauthorizedRequest
                }
                
                if httpResponse.statusCode == 402 {
                    throw SpoonacularServiceError.usageLimitExceeded
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    throw SpoonacularServiceError.httpError(statusCode: httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: SpoonacularNutritionResponse.self, decoder: JSONDecoder())
            .mapError { error -> Error in
                if let decodingError = error as? DecodingError {
                    return SpoonacularServiceError.decodingError(decodingError)
                }
                return error
            }
            .eraseToAnyPublisher()
    }
    
    /// Поиск рецепта/блюда по названию
    func searchFoodByName(query: String) -> AnyPublisher<SpoonacularSearchResponse, Error> {
        let endpoint = "/recipes/complexSearch"
        var urlComponents = URLComponents(string: baseURL + endpoint)
        
        // Настройка параметров запроса
        urlComponents?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "addRecipeNutrition", value: "true"),
            URLQueryItem(name: "number", value: "5") // Ограничиваем количество результатов
        ]
        
        // Создаем URL
        guard let url = urlComponents?.url else {
            return Fail(error: SpoonacularServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        // Выполняем запрос
        print("🌐 Отправка запроса к Spoonacular API (Search):")
        print("   URL: \(url)")
        print("   Запрос: \(query)")
        
        return session.dataTaskPublisher(for: url)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SpoonacularServiceError.invalidResponse
                }
                
                if httpResponse.statusCode == 401 {
                    throw SpoonacularServiceError.unauthorizedRequest
                }
                
                if httpResponse.statusCode == 402 {
                    throw SpoonacularServiceError.usageLimitExceeded
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    throw SpoonacularServiceError.httpError(statusCode: httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: SpoonacularSearchResponse.self, decoder: JSONDecoder())
            .mapError { error -> Error in
                if let decodingError = error as? DecodingError {
                    return SpoonacularServiceError.decodingError(decodingError)
                }
                return error
            }
            .eraseToAnyPublisher()
    }
    
    /// Анализ рецепта и получение информации о нутриентах
    func analyzeRecipe(title: String, ingredients: [String]) -> AnyPublisher<SpoonacularRecipeAnalysisResponse, Error> {
        let endpoint = "/recipes/analyze"
        var urlComponents = URLComponents(string: baseURL + endpoint)
        
        // Создаем URL
        guard let url = urlComponents?.url else {
            return Fail(error: SpoonacularServiceError.invalidURL).eraseToAnyPublisher()
        }
        
        // Формируем запрос
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Подготавливаем тело запроса
        let requestBody = RecipeAnalysisRequest(
            title: title,
            servings: 1,
            ingredients: ingredients,
            apiKey: apiKey
        )
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
        } catch {
            return Fail(error: SpoonacularServiceError.encodingError(error)).eraseToAnyPublisher()
        }
        
        // Выполняем запрос
        print("🌐 Отправка запроса к Spoonacular API (Recipe Analysis):")
        print("   URL: \(url)")
        print("   Название: \(title)")
        print("   Ингредиенты: \(ingredients.joined(separator: ", "))")
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SpoonacularServiceError.invalidResponse
                }
                
                if httpResponse.statusCode == 401 {
                    throw SpoonacularServiceError.unauthorizedRequest
                }
                
                if httpResponse.statusCode == 402 {
                    throw SpoonacularServiceError.usageLimitExceeded
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    throw SpoonacularServiceError.httpError(statusCode: httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: SpoonacularRecipeAnalysisResponse.self, decoder: JSONDecoder())
            .mapError { error -> Error in
                if let decodingError = error as? DecodingError {
                    return SpoonacularServiceError.decodingError(decodingError)
                }
                return error
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Модели данных для Spoonacular API

struct RecipeAnalysisRequest: Codable {
    let title: String
    let servings: Int
    let ingredients: [String]
    let apiKey: String
}

struct SpoonacularNutritionResponse: Codable {
    let nutrients: [SpoonacularNutrient]
    let properties: [SpoonacularProperty]?
    let ingredients: [SpoonacularIngredient]
}

struct SpoonacularNutrient: Codable {
    let name: String
    let amount: Double
    let unit: String
}

struct SpoonacularProperty: Codable {
    let name: String
    let amount: Double
    let unit: String
}

struct SpoonacularIngredient: Codable {
    let id: Int
    let name: String
    let amount: Double
    let unit: String
    let nutrients: [SpoonacularNutrient]?
}

struct SpoonacularSearchResponse: Codable {
    let results: [SpoonacularSearchResult]
    let offset: Int
    let number: Int
    let totalResults: Int
}

struct SpoonacularSearchResult: Codable {
    let id: Int
    let title: String
    let image: String?
    let imageType: String?
    let nutrition: SpoonacularNutritionInfo?
}

struct SpoonacularNutritionInfo: Codable {
    let nutrients: [SpoonacularNutrient]?
    let caloricBreakdown: CaloricBreakdown?
}

struct CaloricBreakdown: Codable {
    let percentProtein: Double
    let percentFat: Double
    let percentCarbs: Double
}

struct SpoonacularRecipeAnalysisResponse: Codable {
    let id: Int?
    let title: String
    let nutrition: SpoonacularNutritionInfo
}

// MARK: - Ошибки сервиса

enum SpoonacularServiceError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case unauthorizedRequest
    case usageLimitExceeded
    case decodingError(DecodingError)
    case encodingError(Error)
    case unknownError(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Неверный URL"
        case .invalidResponse:
            return "Недопустимый ответ от сервера"
        case .httpError(let statusCode):
            return "HTTP ошибка: \(statusCode)"
        case .unauthorizedRequest:
            return "Ошибка авторизации. Проверьте API ключ"
        case .usageLimitExceeded:
            return "Превышен лимит использования API"
        case .decodingError(let error):
            return "Ошибка декодирования: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Ошибка кодирования: \(error.localizedDescription)"
        case .unknownError(let error):
            return "Неизвестная ошибка: \(error.localizedDescription)"
        }
    }
} 