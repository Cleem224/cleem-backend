import Foundation

// MARK: - Модели для анализа питания

/// Ответ от сервера с данными о анализе питания
struct NutritionAnalysisResponse: Codable {
    let message: String
    let model: String
    let model_type: String
    let product_name: String
    let count: Int
    let nutrition_per_item: AnalysisNutritionInfo?
    let total_nutrition: AnalysisNutritionInfo?
    let num_detections: Int
    let detections: [DetectedObject]
    let processing_time_sec: Double
}

/// Информация о питательной ценности
struct AnalysisNutritionInfo: Codable {
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let serving_weight_grams: Double
}

/// Обнаруженный объект на изображении
struct DetectedObject: Codable {
    let bbox: [Double]
    let confidence: Double
    let class_id: Int
    let class_name: String
} 