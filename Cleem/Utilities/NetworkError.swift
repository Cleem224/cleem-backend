import Foundation

enum NetworkError: Error {
    case noConnection
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case invalidData
    case decodingFailed(Error)
    
    var localizedDescription: String {
        switch self {
        case .noConnection:
            return "Отсутствует подключение к интернету. Пожалуйста, проверьте соединение и попробуйте снова."
        case .invalidURL:
            return "Неверный URL запроса."
        case .requestFailed(let error):
            return "Ошибка запроса: \(error.localizedDescription)"
        case .invalidResponse:
            return "Получен некорректный ответ от сервера."
        case .invalidData:
            return "Получены некорректные данные от сервера."
        case .decodingFailed(let error):
            return "Ошибка при обработке данных: \(error.localizedDescription)"
        }
    }
}

