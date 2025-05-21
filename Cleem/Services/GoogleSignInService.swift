import Foundation
import UIKit
// Удаляем условный импорт GoogleSignIn
// #if canImport(GoogleSignIn)
// import GoogleSignIn
// #endif

// Добавляем импорт AppAuth
import AppAuth
// Удаляем лишние импорты, которые только создают проблемы
// import GTMAppAuth
// import GTMSessionFetcher

// Сервис для работы с Google Sign-In
class GoogleSignInService {
    // Синглтон для доступа из любого места
    static let shared = GoogleSignInService()
    
    // Приватный инициализатор для синглтона
    private init() {}
    
    // MARK: - Методы для работы с Google Sign-In
    
    /// Метод для входа через Google
    /// - Parameters:
    ///   - clientID: Идентификатор клиента Google
    ///   - presentingViewController: Контроллер для отображения окна аутентификации
    ///   - completion: Замыкание, вызываемое по завершении аутентификации
    func signIn(clientID: String, presentingViewController: UIViewController, completion: @escaping (MyGIDGoogleUser?, Error?) -> Void) {
        print("GoogleSignInService: Начало входа через Google")
        
        // Всегда используем мок-реализацию
        fallbackMockSignIn(completion: completion)
    }
    
    /// Метод для выхода из Google-аккаунта
    func signOut() {
        print("GoogleSignInService: Выход из Google-аккаунта")
        // Ничего не делаем в мок-реализации
    }
    
    // MARK: - Вспомогательные методы
    
    /// Создание мок-пользователя для эмуляции работы с Google Sign-In
    private func fallbackMockSignIn(completion: @escaping (MyGIDGoogleUser?, Error?) -> Void) {
        print("GoogleSignInService: Используем мок реализацию")
        // Создаем заглушку пользователя
        let user = createMockUser()
        
        // Эмулируем асинхронную аутентификацию
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            print("GoogleSignInService: Успешная аутентификация с ID токеном (мок)")
            completion(user, nil)
        }
    }
    
    /// Создание мок-пользователя для эмуляции работы с Google Sign-In
    private func createMockUser() -> MyGIDGoogleUser {
        let user = MyGIDGoogleUser()
        user.userID = "google_\(Int.random(in: 10000...99999))"
        
        // Создаем профиль
        let profile = MyGIDProfileData()
        profile.name = "Тестовый Пользователь"
        profile.email = "test\(Int.random(in: 100...999))@example.com"
        
        // Создаем URL изображения профиля
        if let url = URL(string: "https://picsum.photos/200") {
            profile.imageURL = url
        }
        
        user.profile = profile
        
        // Добавляем данные аутентификации
        let auth = MyGIDAuthentication()
        auth.idToken = "google_id_token_\(UUID().uuidString)"
        auth.accessToken = "google_access_token_\(UUID().uuidString)"
        user.authentication = auth
        
        return user
    }
} 