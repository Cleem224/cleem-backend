import Foundation
import Combine
import UIKit

/// Сервис для взаимодействия с API сервера
class ApiService {
    // Синглтон для доступа из любого места
    static let shared = ApiService()
    
    // URL базового API
    // Для локальной разработки используйте "http://127.0.0.1:8080"
    // Для тестирования на реальном устройстве используйте IP вашего компьютера
    // Для продакшена используйте "https://api.cleemai.com"
    private let baseURL = "https://api.cleemai.com"
    
    // URL сессия для сетевых запросов
    private let session: URLSession
    
    // Сервис аутентификации
    private let authService = AuthService.shared
    
    // Приватный инициализатор для синглтона
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Методы для аутентификации
    
    /// Аутентификация через Google
    func authenticateWithGoogle(googleToken: GoogleSignInRequest) -> AnyPublisher<Token, Error> {
        guard let url = URL(string: "\(baseURL)/auth/google") else {
            return Fail(error: ApiError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Создаем тело запроса
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(googleToken)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ApiError.invalidResponse
                }
                
                if httpResponse.statusCode == 401 {
                    throw ApiError.unauthorized
                }
                
                if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                    throw ApiError.serverError(statusCode: httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: Token.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // MARK: - Общие методы для работы с API
    
    /// Выполнение GET запроса
    func get<T: Decodable>(endpoint: String, type: T.Type) -> AnyPublisher<T, Error> {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            return Fail(error: ApiError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Добавляем токен авторизации, если есть
        if let token = authService.authToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ApiError.invalidResponse
                }
                
                if httpResponse.statusCode == 401 {
                    throw ApiError.unauthorized
                }
                
                if httpResponse.statusCode != 200 {
                    throw ApiError.serverError(statusCode: httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    /// Выполнение POST запроса
    func post<T: Decodable, E: Encodable>(endpoint: String, body: E, type: T.Type) -> AnyPublisher<T, Error> {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            return Fail(error: ApiError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Добавляем токен авторизации, если есть
        if let token = authService.authToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Кодируем тело запроса
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ApiError.invalidResponse
                }
                
                if httpResponse.statusCode == 401 {
                    throw ApiError.unauthorized
                }
                
                if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                    throw ApiError.serverError(statusCode: httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    // MARK: - Методы для работы с продуктами
    
    /// Получение списка всех продуктов пользователя
    func getFoodItems() -> AnyPublisher<[FoodItemResponse], Error> {
        return get(endpoint: "foods", type: [FoodItemResponse].self)
    }
    
    /// Добавление нового продукта
    func addFood(food: FoodItemRequest) -> AnyPublisher<FoodItemResponse, Error> {
        return post(endpoint: "foods", body: food, type: FoodItemResponse.self)
    }
    
    /// Получение данных пользователя
    func getUserProfile() -> AnyPublisher<ApiUserProfile, Error> {
        return get(endpoint: "users/me/profile", type: ApiUserProfile.self)
    }
    
    /// Обновление данных пользователя
    func updateUserProfile(profile: UserProfileRequest) -> AnyPublisher<ApiUserProfile, Error> {
        return post(endpoint: "users/me/profile", body: profile, type: ApiUserProfile.self)
    }
    
    /// Синхронизация данных с сервером
    func syncData(data: SyncRequest) -> AnyPublisher<SyncResponse, Error> {
        return post(endpoint: "sync", body: data, type: SyncResponse.self)
    }
    
    // MARK: - Анализ изображений еды
    
    /// Отправляет изображение на сервер для анализа и получения информации о питательной ценности
    func analyzeFood(image: UIImage, modelName: String = "model1", confidenceThreshold: Float = 0.1) -> AnyPublisher<NutritionAnalysisResponse, Error> {
        guard let url = URL(string: "\(baseURL)/analyze") else {
            return Fail(error: ApiError.invalidURL).eraseToAnyPublisher()
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return Fail(error: ApiError.invalidData).eraseToAnyPublisher()
        }
        
        // Создаем multipart/form-data запрос
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Добавляем токен авторизации, если есть
        if let token = authService.authToken {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Генерируем уникальную границу для multipart/form-data
        let boundary = "Boundary-\(UUID().uuidString)"
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Добавляем файл изображения
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"food.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Добавляем модель
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model_name\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(modelName)\r\n".data(using: .utf8)!)
        
        // Добавляем порог уверенности
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"conf_threshold\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(confidenceThreshold)\r\n".data(using: .utf8)!)
        
        // Завершаем multipart/form-data запрос
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ApiError.invalidResponse
                }
                
                if httpResponse.statusCode == 401 {
                    throw ApiError.unauthorized
                }
                
                if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                    throw ApiError.serverError(statusCode: httpResponse.statusCode)
                }
                
                return data
            }
            .decode(type: NutritionAnalysisResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}

// MARK: - Модели данных для API

/// Ошибки API
enum ApiError: Error {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(statusCode: Int)
    case decodingError
    case networkError
    case invalidData
}

/// Запрос на добавление продукта
struct FoodItemRequest: Codable {
    let name: String
    let nutritionData: String?
    let calories: Double?
    let createdAt: Date
}

/// Ответ с данными о продукте
struct FoodItemResponse: Codable {
    let id: String
    let name: String
    let nutritionData: String?
    let calories: Double?
    let createdAt: String
}

/// Модель профиля пользователя для API
struct ApiUserProfile: Codable {
    let id: String
    let email: String
    let name: String?
    let profileImage: String?
    let preferences: UserPreferences?
    let stats: UserStats?
}

/// Предпочтения пользователя
struct UserPreferences: Codable {
    let theme: String?
    let languageCode: String?
    let notificationsEnabled: Bool
}

/// Статистика пользователя
struct UserStats: Codable {
    let registrationDate: String
    let lastLoginDate: String
    let totalFoodItems: Int
}

/// Запрос на обновление профиля
struct UserProfileRequest: Codable {
    let name: String?
    let preferences: UserPreferences?
}

/// Запрос на синхронизацию данных
struct SyncRequest: Codable {
    let lastSyncTimestamp: String?
    let foodItems: [FoodItemRequest]?
}

/// Ответ на синхронизацию данных
struct SyncResponse: Codable {
    let timestamp: String
    let foodItems: [FoodItemResponse]?
    let deletedItemIds: [String]?
    let message: String?
} 