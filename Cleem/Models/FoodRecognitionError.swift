import Foundation

/// Типы ошибок, которые могут возникнуть в процессе распознавания пищи
enum FoodRecognitionError: Error {
    case networkError(String)
    case imageProcessingError(String)
    case invalidResponse
    case recognitionFailed(String)
    case decompositionFailed(String)
    case nutritionAnalysisFailed(String)
    case imageProcessingFailed
    case apiKeyMissing(String)
    case invalidURL
    case serverError(Int)
    case imageError(String)
    
    var localizedDescription: String {
        switch self {
        case .networkError(let message):
            return "Ошибка сети: \(message)"
        case .imageProcessingError(let message):
            return "Ошибка обработки изображения: \(message)"
        case .invalidResponse:
            return "Недопустимый ответ от сервера"
        case .recognitionFailed(let message):
            return "Ошибка распознавания: \(message)"
        case .decompositionFailed(let message):
            return "Ошибка декомпозиции блюда: \(message)"
        case .nutritionAnalysisFailed(let message):
            return "Ошибка анализа питательных веществ: \(message)"
        case .imageProcessingFailed:
            return "Ошибка обработки изображения"
        case .apiKeyMissing(let message):
            return "Отсутствует API ключ: \(message)"
        case .invalidURL:
            return "Неверный URL запроса"
        case .serverError(let code):
            return "Ошибка сервера: \(code)"
        case .imageError(let message):
            return "Проблема с изображением: \(message)"
        }
    }
} 