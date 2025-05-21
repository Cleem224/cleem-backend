import SwiftUI
// Импортируем компонент NutrientRow из отдельного файла
// import "Cleem/Views/Components/NutrientRow.swift" - Swift автоматически находит все файлы в проекте

// Импортируем компоненты
import Cleem

struct NutritionDetailsView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    let foodName: String
    let nutrition: FoodNutrition
    
    init(foodName: String, nutrition: FoodNutrition) {
        self.foodName = foodName
        self.nutrition = nutrition
    }
    
    // Alternative initializer for FoodItem
    init(foodItem: FoodItem, nutrition: FoodNutrition) {
        self.foodName = foodItem.name
        self.nutrition = nutrition
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with food name and close button
                HStack {
                    Text(foodName)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        navigationCoordinator.dismissActiveScreen()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                
                // Nutrition summary card
                NutritionFactsCard(calories: Int(nutrition.calories))
                    .padding(.horizontal)
                
                // Macronutrients view
                MacronutrientsView(nutrition: nutrition)
                    .padding(.horizontal)
                
                // Nutrient details
                NutrientDetailsView(nutrition: nutrition)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationBarHidden(true)
    }
}

struct NutritionFactsCard: View {
    let calories: Int
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Nutrition Facts")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            VStack(spacing: 4) {
                Text("Calories")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("\(calories)")
                    .font(.system(size: 36, weight: .bold))
                
                Text("per serving")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MacronutrientsView: View {
    let nutrition: FoodNutrition
    
    private var totalMacros: Double {
        Double(nutrition.protein + nutrition.carbs + nutrition.fat)
    }
    
    private var proteinPercentage: Double {
        totalMacros > 0 ? Double(nutrition.protein) / totalMacros : 0
    }
    
    private var carbsPercentage: Double {
        totalMacros > 0 ? Double(nutrition.carbs) / totalMacros : 0
    }
    
    private var fatPercentage: Double {
        totalMacros > 0 ? Double(nutrition.fat) / totalMacros : 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Macronutrients")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            HStack(spacing: 20) {
                MacroCircle(
                    value: Int(nutrition.protein),
                    total: Int(totalMacros),
                    percentage: proteinPercentage,
                    name: "Protein",
                    color: .red
                )
                
                MacroCircle(
                    value: Int(nutrition.carbs),
                    total: Int(totalMacros),
                    percentage: carbsPercentage,
                    name: "Carbs",
                    color: .blue
                )
                
                MacroCircle(
                    value: Int(nutrition.fat),
                    total: Int(totalMacros),
                    percentage: fatPercentage,
                    name: "Fat",
                    color: .yellow
                )
            }
            .padding(.vertical, 12)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MacroCircle: View {
    let value: Int
    let total: Int
    let percentage: Double
    let name: String
    let color: Color
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 10)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: CGFloat(percentage))
                    .stroke(color, lineWidth: 10)
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(value)g")
                        .font(.system(size: 16, weight: .bold))
                    
                    Text("\(Int(percentage * 100))%")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }
}

struct NutrientDetailsView: View {
    let nutrition: FoodNutrition
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Nutrient Details")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            Group {
                // Show fiber if available
                if let fiber = nutrition.fiber {
                    NutrientRow(name: "Dietary Fiber", value: "\(Int(fiber))g")
                    Divider()
                }
                
                // Show sugars if available
                if let sugars = nutrition.sugars {
                    NutrientRow(name: "Sugars", value: "\(Int(sugars))g")
                    Divider()
                }
                
                // Show sodium if available
                if let sodium = nutrition.sodium {
                    NutrientRow(name: "Sodium", value: "\(Int(sodium))mg")
                }
                
                // Display serving size information
                Divider()
                NutrientRow(name: "Serving Size", value: "\(Int(nutrition.servingSize)) \(nutrition.servingUnit)")
                
                // Display data source
                Divider()
                NutrientRow(name: "Source", value: nutrition.source)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct NutritionDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleNutrition = FoodNutrition(
            calories: 95,
            protein: 0.5,
            carbs: 25.0,
            fat: 0.3,
            sugars: 19.0,
            fiber: 4.4,
            sodium: 2.0,
            servingSize: 100,
            servingUnit: "г",
            foodName: "Apple",
            source: "preview"
        )
        
        let sampleFood = FoodItem(
            name: "Apple",
            category: "Fruits",
            servingSize: 182,
            servingUnit: "g",
            description: "A crisp and sweet apple, rich in fiber and vitamin C.",
            image: nil
        )
        
        return NutritionDetailsView(foodItem: sampleFood, nutrition: sampleNutrition)
            .environmentObject(NavigationCoordinator.shared)
    }
}

