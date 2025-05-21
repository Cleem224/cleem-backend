import SwiftUI

// This enum defines the types of nutrients that can be tracked
enum NutrientType {
    case calories
    case protein
    case carbs
    case fat
    
    var title: String {
        switch self {
        case .calories: return "Calorie goal"
        case .protein: return "Protein goal"
        case .carbs: return "Carb goal"
        case .fat: return "Fat goal"
        }
    }
    
    var iconName: String {
        switch self {
        case .calories: return "flame.fill"
        case .protein: return "p.square.fill"
        case .carbs: return "c.square.fill"
        case .fat: return "f.square.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .calories: return Color.black
        case .protein: return Color.red
        case .carbs: return Color.blue
        case .fat: return Color.orange
        }
    }
    
    // Min values for each nutrient
    var minValue: Int {
        switch self {
        case .calories: return 500
        case .protein: return 20
        case .carbs: return 20
        case .fat: return 10
        }
    }
    
    // Max values for each nutrient
    var maxValue: Int {
        switch self {
        case .calories: return 4000
        case .protein: return 300
        case .carbs: return 500
        case .fat: return 200
        }
    }
    
    // Определяет, нужно ли отображать иконку в квадратном фоне
    var useCustomSquareBackground: Bool {
        switch self {
        case .calories, .protein, .carbs, .fat: return true // Use square background for all nutrients
        }
    }
}

