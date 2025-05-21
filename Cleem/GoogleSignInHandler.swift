import Foundation
import UIKit
import SwiftUI
import Combine

class GoogleSignInHandler: ObservableObject {
    // Синглтон для доступа из любого места
    static let shared = GoogleSignInHandler()
    
    // Состояние аутентификации
    @Published var isAuthenticated = false
    @Published var userData: UserResponse?
    @Published var error: Error?
    @Published var isLoading = false
    
    // Client ID из GoogleService-Info.plist
    private let clientID: String = {
        // Сначала пытаемся получить ID из Info.plist
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            return clientID
        }
        // Если нет, используем значение по умолчанию (тестовое)
        return "mock.apps.googleusercontent.com"
    }()
    
    // Сервис аутентификации
    private let authService = AuthService.shared
    
    // Отслеживание подписок
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Подписываемся на изменения статуса аутентификации
        authService.authStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                
                switch status {
                case .authenticated:
                    self.isAuthenticated = true
                case .unauthenticated:
                    self.isAuthenticated = false
                    self.userData = nil
                case .unknown:
                    self.isAuthenticated = false
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Методы для работы с Google Sign-In
    
    /// Метод для выполнения входа через Google
    func signIn(from viewController: UIViewController, completion: @escaping (Result<UserData, Error>) -> Void) {
        self.isLoading = true
        
        print("GoogleSignInHandler: начинаем вход через Google с clientID: \(clientID)")
        
        // Используем GoogleSignInService для выполнения входа
        GoogleSignInService.shared.signIn(clientID: clientID, presentingViewController: viewController) { [weak self] gUser, error in
            guard let self = self else { return }
            
            if let error = error {
                print("GoogleSignInHandler: ошибка входа - \(error.localizedDescription)")
                self.isLoading = false
                self.error = error
                completion(.failure(error))
                return
            }
            
            guard let user = gUser,
                  let idToken = user.authentication.idToken,
                  let accessToken = user.authentication.accessToken else {
                let error = NSError(domain: "GoogleSignIn", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не удалось получить данные пользователя"])
                self.isLoading = false
                self.error = error
                completion(.failure(error))
                return
            }
            
            // Создаем запрос для аутентификации на нашем сервере
            let googleToken = GoogleSignInRequest(
                access_token: accessToken,
                id_token: idToken,
                expires_in: 3600,
                refresh_token: nil,
                token_type: "Bearer",
                scope: "email profile"
            )
            
            // Теперь выполняем аутентификацию на нашем сервере
            self.authService.authenticateWithGoogle(googleToken: googleToken) { [weak self] result in
                guard let self = self else { return }
                
                self.isLoading = false
                
                switch result {
                case .success(let token):
                    self.userData = token.user
                    self.isAuthenticated = true
                    let userData = UserData.fromUserResponse(token.user)
                    completion(.success(userData))
                    
                case .failure(let error):
                    self.error = error
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Метод для выхода из аккаунта
    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
        self.isLoading = true
        
        // Выходим через сервис аутентификации
        authService.logout { [weak self] result in
            guard let self = self else { return }
            
            self.isLoading = false
            completion(result)
        }
    }
    
    /// Проверка статуса аутентификации
    func checkAuthStatus() -> AuthStatus {
        return authService.authStatus
    }
}

// MARK: - UIKit представление для интеграции с SwiftUI

/// SwiftUI представление для процесса входа через Google
struct GoogleSignInViewControllerUI: UIViewControllerRepresentable {
    @EnvironmentObject var googleSignInHandler: GoogleSignInHandler
    var onComplete: (Result<UserData, Error>) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        
        // Запускаем процесс аутентификации при создании контроллера
        DispatchQueue.main.async {
            googleSignInHandler.signIn(from: vc) { result in
                onComplete(result)
            }
        }
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
} 

