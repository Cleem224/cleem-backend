import Foundation
import UIKit

/// Wrapper struct to avoid type conflicts with RecognizedFoodV2
public struct RecognizedFood: Identifiable, Equatable, Codable {
    public let id: UUID
    public var name: String
    public var confidence: Double
    public var nutritionData: NutritionData?
    public var originalImage: UIImage?
    public var ingredients: [String]?
    
    // For UI purposes
    public var isProcessing: Bool = false
    public var isSelected: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, name, confidence, nutritionData
        // originalImage, isProcessing, и isSelected не кодируются
    }
    
    public init(id: UUID = UUID(), name: String, confidence: Double, nutritionData: NutritionData? = nil, originalImage: UIImage? = nil, ingredients: [String]? = nil, isProcessing: Bool = false, isSelected: Bool = false) {
        self.id = id
        self.name = name
        self.confidence = confidence
        self.nutritionData = nutritionData
        self.originalImage = originalImage
        self.ingredients = ingredients
        self.isProcessing = isProcessing
        self.isSelected = isSelected
    }
    
    // Конструктор для преобразования из RecognizedFoodV2
    public init(from foodV2: RecognizedFoodV2) {
        self.id = foodV2.id
        self.name = foodV2.name
        self.confidence = foodV2.confidence
        self.originalImage = foodV2.originalImage
        self.ingredients = foodV2.ingredients
        self.isProcessing = false
        self.isSelected = false
        
        // Конвертируем NutritionDataV2 в NutritionData, если он доступен
        if let nutritionDataV2 = foodV2.nutritionData {
            self.nutritionData = NutritionData(from: nutritionDataV2)
        } else {
            self.nutritionData = nil
        }
    }
    
    // Инициализатор из декодера
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        confidence = try container.decode(Double.self, forKey: .confidence)
        nutritionData = try container.decodeIfPresent(NutritionData.self, forKey: .nutritionData)
        
        // Эти свойства не кодируются
        originalImage = nil
        isProcessing = false
        isSelected = false
        ingredients = nil
    }
    
    // Кодирование в энкодер
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(confidence, forKey: .confidence)
        try container.encodeIfPresent(nutritionData, forKey: .nutritionData)
        
        // originalImage, isProcessing, и isSelected не кодируются
    }
    
    public static func == (lhs: RecognizedFood, rhs: RecognizedFood) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Nutrition data model
public struct NutritionData: Codable {
    public let calories: Double
    public let protein: Double // в граммах
    public let fat: Double // в граммах
    public let carbs: Double // в граммах
    
    // Дополнительные данные при необходимости
    public let sugar: Double?
    public let fiber: Double?
    public let sodium: Double?
    public let cholesterol: Double?
    public let servingSize: Double
    public let servingUnit: String
    
    // Метаданные
    public let source: String // источник данных, например "edamam"
    public var foodLabel: String // Оригинальное название из API
    
    // Публичный инициализатор
    public init(calories: Double, protein: Double, fat: Double, carbs: Double, sugar: Double?, fiber: Double?, sodium: Double?, source: String, foodLabel: String, cholesterol: Double? = nil, servingSize: Double = 100.0, servingUnit: String = "г") {
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.sugar = sugar
        self.fiber = fiber
        self.sodium = sodium
        self.cholesterol = cholesterol
        self.servingSize = servingSize
        self.servingUnit = servingUnit
        self.source = source
        self.foodLabel = foodLabel
    }
    
    // Дополнительный конструктор для преобразования из NutritionDataV2
    public init(from nutritionDataV2: NutritionDataV2) {
        self.calories = nutritionDataV2.calories
        self.protein = nutritionDataV2.protein
        self.fat = nutritionDataV2.fat
        self.carbs = nutritionDataV2.carbs
        self.sugar = nutritionDataV2.sugar
        self.fiber = nutritionDataV2.fiber
        self.sodium = nutritionDataV2.sodium
        self.cholesterol = nutritionDataV2.cholesterol
        self.servingSize = nutritionDataV2.servingSize ?? 100.0
        self.servingUnit = nutritionDataV2.servingUnit ?? "г"
        self.source = nutritionDataV2.source
        self.foodLabel = nutritionDataV2.foodLabel
    }
    
    /// Преобразование в FoodNutrition для обратной совместимости
    public func toFoodNutrition() -> FoodNutrition {
        return FoodNutrition(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            sugars: sugar,
            fiber: fiber,
            sodium: sodium,
            servingSize: 100.0,
            servingUnit: "г",
            foodName: foodLabel,
            source: source
        )
    }
    
    /// Форматирование значений питательных веществ для отображения
    public func formattedValue(_ value: Double) -> String {
        return String(format: "%.1f", value)
    }
    
    public var formattedCalories: String {
        return String(format: "%.0f", calories)
    }
    
    public var formattedProtein: String {
        return formattedValue(protein)
    }
    
    public var formattedFat: String {
        return formattedValue(fat)
    }
    
    public var formattedCarbs: String {
        return formattedValue(carbs)
    }
    
    public var formattedSugar: String {
        if let sugar = sugar {
            return formattedValue(sugar)
        }
        return "N/A"
    }
    
    public var formattedFiber: String {
        if let fiber = fiber {
            return formattedValue(fiber)
        }
        return "N/A"
    }
    
    public var formattedSodium: String {
        if let sodium = sodium {
            return formattedValue(sodium)
        }
        return "N/A"
    }
}

/// Response model for Gemini API
public struct GeminiResponse: Codable {
    public let candidates: [Candidate]?
    
    public struct Candidate: Codable {
        public let content: Content?
        public let finishReason: String?
    }
    
    public struct Content: Codable {
        public let parts: [Part]?
        public let role: String?
    }
    
    public struct Part: Codable {
        public let text: String?
    }
} 