import Foundation

// Режимы сканирования - единое место определения
public enum ScanMode: String, CaseIterable {
    case food = "Еда"
    case barcode = "Штрих-код"
    case label = "Этикетка"
    case gallery = "Галерея"
    
    // Теги для кнопок
    public var tag: Int {
        switch self {
        case .food: return 0
        case .barcode: return 1
        case .label: return 2
        case .gallery: return 3
        }
    }
}

// Типы приемов пищи - единое место определения
public enum MealType: String, CaseIterable, Identifiable, Codable {
    case breakfast = "Завтрак"
    case lunch = "Обед"
    case dinner = "Ужин"
    case snack = "Перекус"
    
    public var id: String { self.rawValue }
    
    public var displayName: String {
        return self.rawValue
    }
    
    public var icon: String {
        switch self {
        case .breakfast: return "sun.and.horizon"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        case .snack: return "cup.and.saucer"
        }
    }
}

