import Foundation

// MARK: - Запросы к API

/// Запрос для аутентификации через Google
public struct GoogleSignInRequest: Codable {
    public let access_token: String
    public let id_token: String
    public let expires_in: Int
    public let refresh_token: String?
    public let token_type: String
    public let scope: String
    
    public init(access_token: String, id_token: String, expires_in: Int, refresh_token: String?, token_type: String, scope: String) {
        self.access_token = access_token
        self.id_token = id_token
        self.expires_in = expires_in
        self.refresh_token = refresh_token
        self.token_type = token_type
        self.scope = scope
    }
}

// MARK: - Ответы от API

/// Ответ от сервера при аутентификации
public struct Token: Codable {
    public let access_token: String
    public let token_type: String
    public let user: UserResponse
    
    public init(access_token: String, token_type: String, user: UserResponse) {
        self.access_token = access_token
        self.token_type = token_type
        self.user = user
    }
}

/// Данные пользователя
public struct UserResponse: Codable {
    public let id: String
    public let email: String
    public let name: String
    public let picture: String?
    public let google_id: String
    public let created_at: String
    public let updated_at: String?
    
    public init(id: String, email: String, name: String, picture: String?, google_id: String, created_at: String, updated_at: String?) {
        self.id = id
        self.email = email
        self.name = name
        self.picture = picture
        self.google_id = google_id
        self.created_at = created_at
        self.updated_at = updated_at
    }
}

/// Ошибка аутентификации
public struct GoogleAuthError: Codable, Error {
    public let detail: String
    
    public init(detail: String) {
        self.detail = detail
    }
} 