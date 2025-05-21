import SwiftUI

// Component for displaying nutrients with consistent styling
struct NutrientView: View {
    let icon: String
    let color: Color
    let value: Double
    let unit: String
    
    // Helper to get the appropriate letter for the icon
    private var letterForIcon: String {
        switch icon {
        case "flame.fill":
            return "" // Keep flame icon for calories
        case "drop.fill" where color == .red || color == .blue:
            return "P" // Protein
        case "leaf.fill", "drop.fill" where color == .orange || color == .blue:
            return "C" // Carbs
        case "drop.fill" where color == .blue || color == .yellow || color == .orange:
            return "F" // Fat
        default:
            return ""
        }
    }
    
    // Helper to determine if we should use flame icon or letter
    private var useFlameIcon: Bool {
        return icon == "flame.fill"
    }
    
    // Helper to get the correct color for each nutrient
    private var nutrientColor: Color {
        switch icon {
        case "flame.fill":
            return .black // Calories
        case "drop.fill" where letterForIcon == "P":
            return .red // Protein - red
        case "leaf.fill", "drop.fill" where letterForIcon == "C":
            return .blue // Carbs - blue
        case "drop.fill" where letterForIcon == "F":
            return .orange // Fat - orange
        default:
            return color // Default to passed color
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Square background with letter or icon
            RoundedRectangle(cornerRadius: 4)
                .fill(nutrientColor)
                .frame(width: 20, height: 20)
                .overlay(
                    Group {
                        if useFlameIcon {
                            // Use flame icon for calories
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        } else {
                            // Use letter for nutrients
                            Text(letterForIcon)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                )
                
            // Show the value
            Text("\(Int(value))\(unit)")
                .font(.system(size: 10))
                .foregroundColor(.black)
        }
    }
}

// Структура NutrientRow перенесена в отдельный файл
