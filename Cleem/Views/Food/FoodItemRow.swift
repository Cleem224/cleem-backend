import SwiftUI
import CoreData

// Универсальный компонент для отображения строки продукта
struct FoodItemRow<T: FoodDisplayable>: View {
    let food: T
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Иконка или изображение продукта
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    if let image = food.displayImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(Circle())
                            .frame(width: 45, height: 45)
                    } else {
                        Image(systemName: getFoodIcon(for: food.displayName))
                            .font(.system(size: 22))
                            .foregroundColor(getFoodColor(for: food.displayName))
                    }
                }
                
                // Название и описание
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.displayName)
                        .font(.system(size: 16, weight: .medium))
                    
                    HStack(spacing: 8) {
                        // Калории
                        Text("\(Int(food.displayCalories)) kcal")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black.opacity(0.7))
                        
                        // Макросы (если доступны)
                        if let protein = food.displayProtein, let carbs = food.displayCarbs, let fat = food.displayFat {
                            HStack(spacing: 5) {
                                Text("P: \(Int(protein))g")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue.opacity(0.8))
                                
                                Text("C: \(Int(carbs))g")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green.opacity(0.8))
                                
                                Text("F: \(Int(fat))g")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange.opacity(0.8))
                            }
                        }
                    }
                    
                    if let serving = food.displayServingUnit {
                        Text("Serving: \(Int(food.displayServingSize))") + Text(serving)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Иконка действия
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.blue)
            }
            .padding(12)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Helper functions to get appropriate icons and colors based on food name
    private func getFoodIcon(for name: String) -> String {
        let lowercaseName = name.lowercased()
        
        if lowercaseName.contains("apple") {
            return "apple.logo"
        } else if lowercaseName.contains("banana") {
            return "leaf.fill"
        } else if lowercaseName.contains("chicken") || lowercaseName.contains("meat") {
            return "fork.knife"
        } else if lowercaseName.contains("milk") || lowercaseName.contains("yogurt") {
            return "cup.and.saucer.fill"
        } else if lowercaseName.contains("fish") || lowercaseName.contains("salmon") {
            return "water.waves"
        } else if lowercaseName.contains("egg") {
            return "oval.fill"
        } else if lowercaseName.contains("bread") {
            return "square.grid.2x2.fill"
        } else if lowercaseName.contains("vege") || lowercaseName.contains("salad") {
            return "leaf.circle.fill"
        }
        
        return "circle.grid.2x2.fill"  // Default icon
    }
    
    private func getFoodColor(for name: String) -> Color {
        let lowercaseName = name.lowercased()
        
        if lowercaseName.contains("apple") {
            return Color.red
        } else if lowercaseName.contains("banana") {
            return Color.yellow
        } else if lowercaseName.contains("chicken") || lowercaseName.contains("meat") {
            return Color.brown
        } else if lowercaseName.contains("milk") || lowercaseName.contains("yogurt") {
            return Color.blue
        } else if lowercaseName.contains("fish") || lowercaseName.contains("salmon") {
            return Color.blue
        } else if lowercaseName.contains("egg") {
            return Color.yellow
        } else if lowercaseName.contains("bread") {
            return Color.brown
        } else if lowercaseName.contains("vege") || lowercaseName.contains("salad") {
            return Color.green
        }
        
        return Color.gray  // Default color
    }
}

