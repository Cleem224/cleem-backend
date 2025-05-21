import Foundation
import Combine

/// Сервис для работы с аутентификацией
class AuthService {
    // Синглтон для доступа из любого места
    static let shared = AuthService()
    
    // URL сервера
    private let baseURL = "https://api.cleemai.com"
    
    // Сессия для работы с сетью
    private let session: URLSession
    
    // Издатель для отслеживания статуса аутентификации
    private let authStatusSubject = CurrentValueSubject<AuthStatus, Never>(.unknown)
    var authStatusPublisher: AnyPublisher<AuthStatus, Never> {
        return authStatusSubject.eraseToAnyPublisher()
    }
    
    // Хранилище подписок
    private var cancellables = Set<AnyCancellable>()
    
    // Текущий статус аутентификации
    var authStatus: AuthStatus {
        return authStatusSubject.value
    }
    
    // Токен аутентификации
    private var _authToken: String?
    var authToken: String? {
        return _authToken
    }
    
    // Приватный инициализатор для синглтона
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        
        // Проверяем наличие токена при запуске
        if let token = readTokenFromKeychain() {
            self._authToken = token
            validateToken()
        } else {
            authStatusSubject.send(.unauthenticated)
        }
    }
    
    // MARK: - Авторизация через Google
    
    /// Авторизация через Google (регистрация токена на сервере)
    func authenticateWithGoogle(googleToken: GoogleSignInRequest, completion: @escaping (Result<Token, Error>) -> Void) {
        // Используем ApiService для аутентификации
        ApiService.shared.authenticateWithGoogle(googleToken: googleToken)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completionResult in
                switch completionResult {
                case .failure(let error):
                    completion(.failure(error))
                case .finished:
                    break
                }
            }, receiveValue: { [weak self] token in
                guard let self = self else { return }
                
                // Сохраняем токен в Keychain
                self.saveTokenToKeychain(token.access_token)
                self._authToken = token.access_token
                self.authStatusSubject.send(.authenticated)
                
                completion(.success(token))
            })
            .store(in: &cancellables)
    }
    
    /// Выход из аккаунта (уведомление сервера)
    func logout(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let token = _authToken else {
            // Если токена нет, значит мы уже разлогинены
            self._authToken = nil
            self.authStatusSubject.send(.unauthenticated)
            completion(.success(()))
            return
        }
        
        // Создаем запрос к серверу
        let endpoint = "\(baseURL)/auth/logout"
        guard var request = createRequest(for: endpoint, method: "POST") else {
            completion(.failure(AuthError.invalidRequest))
            return
        }
        
        // Добавляем токен авторизации
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Выполняем запрос
        session.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self else { return }
            
            // Очищаем токен независимо от результата запроса
            self.deleteTokenFromKeychain()
            self._authToken = nil
            self.authStatusSubject.send(.unauthenticated)
            
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }.resume()
    }
    
    /// Проверка валидности токена
    private func validateToken() {
        guard let token = _authToken else {
            authStatusSubject.send(.unauthenticated)
            return
        }
        
        // Создаем запрос к серверу
        let endpoint = "\(baseURL)/auth/validate"
        guard var request = createRequest(for: endpoint, method: "GET") else {
            authStatusSubject.send(.unauthenticated)
            return
        }
        
        // Добавляем токен авторизации
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Выполняем запрос
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Токен валидный
                self.authStatusSubject.send(.authenticated)
            } else {
                // Токен невалидный, удаляем его
                self.deleteTokenFromKeychain()
                self._authToken = nil
                self.authStatusSubject.send(.unauthenticated)
            }
        }.resume()
    }
    
    // MARK: - Работа с токеном
    
    /// Создание HTTP запроса
    private func createRequest(for endpoint: String, method: String) -> URLRequest? {
        guard let url = URL(string: endpoint) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        return request
    }
    
    /// Сохранение токена в Keychain
    private func saveTokenToKeychain(_ token: String) {
        // В реальном приложении здесь должно быть сохранение в Keychain
        // Для примера сохраняем в UserDefaults, но в продакшене это небезопасно
        UserDefaults.standard.set(token, forKey: "auth_token")
    }
    
    /// Чтение токена из Keychain
    private func readTokenFromKeychain() -> String? {
        // В реальном приложении здесь должно быть чтение из Keychain
        return UserDefaults.standard.string(forKey: "auth_token")
    }
    
    /// Удаление токена из Keychain
    private func deleteTokenFromKeychain() {
        // В реальном приложении здесь должно быть удаление из Keychain
        UserDefaults.standard.removeObject(forKey: "auth_token")
    }
}

// MARK: - Модели данных

/// Статус аутентификации
enum AuthStatus {
    case unknown
    case authenticated
    case unauthenticated
}

/// Ошибки авторизации
enum AuthError: Error {
    case invalidRequest
    case noData
    case invalidToken
    case serverError
    case networkError
} 