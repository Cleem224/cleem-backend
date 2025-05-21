import Foundation

// Методы для работы с UUID
extension UUID {
    // Вспомогательный метод для создания UUID
    static func generate() -> UUID {
        return UUID()
    }
    
    // Получение строкового представления UUID
    var string: String {
        return self.description
    }
} 