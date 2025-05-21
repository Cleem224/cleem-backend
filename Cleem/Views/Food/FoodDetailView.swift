import SwiftUI
import Cleem

struct FoodDetailView<T: FoodDisplayable>: View {
    let food: T
    var onAdd: (() -> Void)?
    
    @Environment(\.presentationMode) var presentationMode
    @State private var servingSize: Double
    @State private var calories: Double = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    
    init(food: T, onAdd: (() -> Void)? = nil) {
        self.food = food
        self.onAdd = onAdd
        self._servingSize = State(initialValue: food.displayServingSize)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with image
                ZStack(alignment: .bottom) {
                    // Food image or icon
                    if let image = food.displayImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                    } else {
                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 200)
                            
                            Image(systemName: getFoodIcon(for: food.displayName))
                                .font(.system(size: 60))
                                .foregroundColor(getFoodColor(for: food.displayName))
                        }
                    }
                    
                    // Gradient overlay for better text visibility
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0)]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 80)
                    
                    // Food name
                    HStack {
                        VStack(alignment: .leading) {
                            Text(food.displayName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            if let category = food.displayCategory {
                                Text(category)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                
                // Nutrition information
                VStack(spacing: 24) {
                    // Serving size control
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Serving Size")
                            .font(.headline)
                        
                        HStack {
                            Slider(value: $servingSize, in: 10...300, step: 10)
                                .onChange(of: servingSize) { newValue in
                                    updateNutritionValues()
                                }
                            
                            Text(String(Int(servingSize)) + (food.displayServingUnit ?? "g"))
                                .font(.system(size: 16, weight: .medium))
                                .frame(width: 60)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Macronutrient circles
                    HStack(spacing: 20) {
                        // Calories
                        NutrientCircle(
                            value: calories,
                            maxValue: 1000,
                            title: "Calories",
                            unitText: "kcal",
                            color: .orange
                        )
                        
                        // Protein
                        NutrientCircle(
                            value: protein,
                            maxValue: 50,
                            title: "Protein",
                            unitText: "g",
                            color: .blue
                        )
                        
                        // Carbs
                        NutrientCircle(
                            value: carbs,
                            maxValue: 100,
                            title: "Carbs",
                            unitText: "g",
                            color: .green
                        )
                        
                        // Fat
                        NutrientCircle(
                            value: fat,
                            maxValue: 50,
                            title: "Fat",
                            unitText: "g",
                            color: .red
                        )
                    }
                    .padding(.vertical)
                    
                    // Detailed nutrition information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Nutrition Facts")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        NutrientRow(name: "Calories", value: String(Int(calories)) + "kcal")
                        Divider()
                        
                        NutrientRow(name: "Protein", value: String(Int(protein)) + "g")
                        Divider()
                        
                        NutrientRow(name: "Carbohydrates", value: String(Int(carbs)) + "g")
                        
                        if let sugar = food.displaySugar {
                            let scaledSugar = sugar * (servingSize / food.displayServingSize)
                            HStack {
                                Text("   of which Sugars")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(Int(scaledSugar)) + "g")
                                    .font(.subheadline)
                            }
                            .padding(.leading)
                        }
                        
                        Divider()
                        
                        NutrientRow(name: "Fat", value: String(Int(fat)) + "g")
                        
                        if let fiber = food.displayFiber {
                            Divider()
                            let scaledFiber = fiber * (servingSize / food.displayServingSize)
                            NutrientRow(name: "Fiber", value: String(Int(scaledFiber)) + "g")
                        }
                        
                        if let sodium = food.displaySodium {
                            Divider()
                            let scaledSodium = sodium * (servingSize / food.displayServingSize)
                            NutrientRow(name: "Sodium", value: String(Int(scaledSodium)) + "mg")
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Action buttons
                HStack(spacing: 16) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Cancel")
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        if let onAdd = onAdd {
                            onAdd()
                        } else {
                            // Default action - add to recently logged
                            if let recommendedFood = food as? RecommendedFoodItem {
                                FoodDatabaseService.shared.addFoodToRecentlyLogged(food: recommendedFood)
                            }
                            
                            // Show success banner
                            let banner = BannerData(title: "Added to Recent", detail: food.displayName, type: .success)
                            NotificationCenter.default.post(name: Notification.Name("ShowBanner"), object: banner)
                        }
                        
                        // Dismiss the view
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Add to Log")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .edgesIgnoringSafeArea(.top)
        .onAppear {
            updateNutritionValues()
        }
    }
    
    private func updateNutritionValues() {
        // Calculate nutrition values based on serving size
        let ratio = servingSize / food.displayServingSize
        
        // Update calories
        calories = food.displayCalories * ratio
        
        // Update macronutrients if available
        protein = (food.displayProtein ?? 0) * ratio
        carbs = (food.displayCarbs ?? 0) * ratio
        fat = (food.displayFat ?? 0) * ratio
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

// Preview provider for development
struct FoodDetailView_Previews: PreviewProvider {
    static var previews: some View {
        FoodDetailView(food: RecommendedFoodItem.sampleRecommendations[0])
    }
}

