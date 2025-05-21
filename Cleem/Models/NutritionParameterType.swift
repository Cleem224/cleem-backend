import SwiftUI

/// NutritionParameterType defines the types of nutrition parameters that can be tracked and edited
public enum NutritionParameterType {
    case calories
    case protein
    case carbs
    case fats
    
    public var title: String {
        switch self {
        case .calories: return "Calories"
        case .protein: return "Protein"
        case .carbs: return "Carbs"
        case .fats: return "Fats"
        }
    }
    
    public var label: String {
        switch self {
        case .calories: return "Calories"
        case .protein: return "Protein"
        case .carbs: return "Carbs"
        case .fats: return "Fats"
        }
    }
    
    public var iconName: String {
        switch self {
        case .calories: return "flame.fill"
        case .protein: return "p"
        case .carbs: return "c"
        case .fats: return "f"
        }
    }
    
    // Determines if icon should use custom square background
    public var useCustomSquareBackground: Bool {
        switch self {
        case .calories, .protein, .carbs, .fats: return true
        }
    }
    
    public func formatValue(_ value: Int) -> String {
        switch self {
        case .calories:
            return "\(value)"
        case .protein, .carbs, .fats:
            return "\(value)g"
        }
    }
    
    // Minimum value for each parameter
    public var minValue: Int {
        switch self {
        case .calories: return 500
        case .protein: return 20
        case .carbs: return 20
        case .fats: return 10
        }
    }
    
    // Maximum value for each parameter
    public var maxValue: Int {
        switch self {
        case .calories: return 4000
        case .protein: return 300
        case .carbs: return 500
        case .fats: return 200
        }
    }
    
    // Color for visualization
    public var color: Color {
        switch self {
        case .calories: return .black
        case .protein: return .red
        case .carbs: return .blue
        case .fats: return .orange
        }
    }
}

