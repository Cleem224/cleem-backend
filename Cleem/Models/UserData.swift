import Foundation

/// Модель данных пользователя после успешной аутентификации
public struct UserData: Codable {
    public let id: String
    public let name: String
    public let email: String
    public let picture: String?
    
    /// Create a UserData instance with all fields
    public init(id: String, name: String, email: String, picture: String?) {
        self.id = id
        self.name = name
        self.email = email
        self.picture = picture
    }
    
    /// Создает данные пользователя из UserResponse
    static func fromUserResponse(_ response: UserResponse) -> UserData {
        return UserData(
            id: response.id,
            name: response.name,
            email: response.email,
            picture: response.picture
        )
    }
} 