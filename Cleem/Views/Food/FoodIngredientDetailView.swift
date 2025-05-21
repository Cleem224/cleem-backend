import SwiftUI
import CoreData

struct FoodIngredientDetailView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    let food: Food
    
    @State private var portions: Int = 1
    @State private var selectedSize: String = "Medium"
    @State private var isEditingIngredients: Bool = false
    @State private var removedIngredients: Set<UUID> = []
    
    private let sizes = ["Small", "Medium", "Large"]
    private let sizeMultipliers: [String: Double] = [
        "Small": 0.7,
        "Medium": 1.0,
        "Large": 1.4
    ]
    
    // Original nutrition values
    @State private var originalCalories: Double = 0
    @State private var originalProtein: Double = 0
    @State private var originalCarbs: Double = 0
    @State private var originalFat: Double = 0
    
    // Calculate adjusted nutrition values based on selected ingredients, portion and size
    private var adjustedCalories: Double {
        let sizeMultiplier = sizeMultipliers[selectedSize] ?? 1.0
        let portionMultiplier = Double(portions)
        return originalCalories * sizeMultiplier * portionMultiplier
    }
    
    private var adjustedProtein: Double {
        let sizeMultiplier = sizeMultipliers[selectedSize] ?? 1.0
        let portionMultiplier = Double(portions)
        return originalProtein * sizeMultiplier * portionMultiplier
    }
    
    private var adjustedCarbs: Double {
        let sizeMultiplier = sizeMultipliers[selectedSize] ?? 1.0
        let portionMultiplier = Double(portions)
        return originalCarbs * sizeMultiplier * portionMultiplier
    }
    
    private var adjustedFat: Double {
        let sizeMultiplier = sizeMultipliers[selectedSize] ?? 1.0
        let portionMultiplier = Double(portions)
        return originalFat * sizeMultiplier * portionMultiplier
    }
    
    var body: some View {
        ZStack {
            // Background color
            Color(.systemGray6)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Button(action: {
                        navigationCoordinator.activeScreen = nil
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(10)
                            .background(Circle().fill(Color(.systemGray5)))
                    }
                    
                    Spacer()
                    
                    Text("Details")
                        .font(.headline)
                    
                    Spacer()
                    
                    // Placeholder for visual balance
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 37, height: 37)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Food image and name
                        HStack {
                            if let imageData = food.imageData, let image = UIImage(data: imageData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(12)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "fork.knife")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(food.name ?? "Unknown Dish")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("\(Int(adjustedCalories)) calories")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                // Ingredient count tag
                                if let ingredients = food.ingredients as? Set<Ingredient>, !ingredients.isEmpty {
                                    HStack {
                                        Text("\(ingredients.count - removedIngredients.count) ingredients")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Capsule().fill(Color.green.opacity(0.2)))
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // Portion and size selection
                        VStack(spacing: 12) {
                            HStack {
                                Text("Portions")
                                    .font(.headline)
                                
                                Spacer()
                                
                                // Portion stepper
                                HStack {
                                    Button(action: {
                                        if portions > 1 {
                                            portions -= 1
                                        }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Text("\(portions)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .frame(width: 30, alignment: .center)
                                    
                                    Button(action: {
                                        portions += 1
                                    }) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Size selector
                            HStack(spacing: 0) {
                                ForEach(sizes, id: \.self) { size in
                                    Button(action: {
                                        selectedSize = size
                                    }) {
                                        Text(size)
                                            .font(.subheadline)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(selectedSize == size ? Color.black : Color.gray.opacity(0.1))
                                            )
                                            .foregroundColor(selectedSize == size ? .white : .black)
                                    }
                                    .padding(.horizontal, 2)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Nutrition summary
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Nutrition Summary")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            HStack(spacing: 20) {
                                // Protein
                                NutrientCircle(
                                    value: Int(adjustedProtein),
                                    label: "P",
                                    unit: "g",
                                    color: .red
                                )
                                
                                // Carbs
                                NutrientCircle(
                                    value: Int(adjustedCarbs),
                                    label: "C",
                                    unit: "g",
                                    color: .blue
                                )
                                
                                // Fat
                                NutrientCircle(
                                    value: Int(adjustedFat),
                                    label: "F",
                                    unit: "g",
                                    color: .orange
                                )
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        // Ingredients section
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Ingredients")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button(action: {
                                    isEditingIngredients.toggle()
                                    
                                    // Reset removed ingredients when exiting edit mode
                                    if !isEditingIngredients {
                                        // Apply the changes by removing the ingredients
                                        applyIngredientChanges()
                                    }
                                }) {
                                    Text(isEditingIngredients ? "Done" : "Edit")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            if let ingredients = food.ingredients as? Set<Ingredient>, !ingredients.isEmpty {
                                ScrollView {
                                    VStack(spacing: 4) {
                                        ForEach(Array(ingredients), id: \.id) { ingredient in
                                            if !removedIngredients.contains(ingredient.id ?? UUID()) {
                                                HStack {
                                                    if isEditingIngredients {
                                                        Button(action: {
                                                            // Mark ingredient for removal
                                                            if let id = ingredient.id {
                                                                removedIngredients.insert(id)
                                                                recalculateNutrition()
                                                            }
                                                        }) {
                                                            Image(systemName: "minus.circle.fill")
                                                                .foregroundColor(.red)
                                                        }
                                                        .padding(.trailing, 5)
                                                    } else {
                                                        Image(systemName: "circle.fill")
                                                            .font(.system(size: 6))
                                                            .foregroundColor(.gray)
                                                            .padding(.trailing, 5)
                                                    }
                                                    
                                                    Text(ingredient.name ?? "Unknown")
                                                        .font(.system(size: 16))
                                                    
                                                    Spacer()
                                                    
                                                    if !isEditingIngredients {
                                                        // Show nutrition values for each ingredient
                                                        HStack(spacing: 8) {
                                                            Text("\(Int(ingredient.calories))cal")
                                                                .font(.caption)
                                                                .foregroundColor(.secondary)
                                                        }
                                                    }
                                                }
                                                .padding(.vertical, 8)
                                                .padding(.horizontal)
                                                .background(Color.white)
                                                .cornerRadius(8)
                                                .padding(.horizontal)
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: 200)
                            }
                            
                            // Add ingredient button (when in edit mode)
                            if isEditingIngredients {
                                Button(action: {
                                    // Show food database to add new ingredient
                                    navigationCoordinator.showFoodDatabase(onFoodSelected: { selectedFood in
                                        if let foodToAdd = selectedFood as? Food {
                                            addIngredient(foodToAdd)
                                        }
                                    })
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.green)
                                        
                                        Text("Add Ingredient")
                                            .font(.subheadline)
                                            .foregroundColor(.green)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        
                        // Add to log button
                        Button(action: {
                            // Save updated food and close
                            saveChanges()
                            navigationCoordinator.activeScreen = nil
                        }) {
                            Text("Add to Log")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                        .padding(.vertical, 20)
                    }
                    .padding(.top, 10)
                }
            }
        }
        .onAppear {
            // Initialize nutrition values
            originalCalories = food.calories
            originalProtein = food.protein
            originalCarbs = food.carbs
            originalFat = food.fat
        }
    }
    
    // Recalculate nutrition based on removed ingredients
    private func recalculateNutrition() {
        guard let ingredients = food.ingredients as? Set<Ingredient>, !ingredients.isEmpty else { return }
        
        // Reset to base values
        originalCalories = 0
        originalProtein = 0
        originalCarbs = 0
        originalFat = 0
        
        // Sum up values from remaining ingredients
        for ingredient in ingredients {
            if let id = ingredient.id, !removedIngredients.contains(id) {
                originalCalories += ingredient.calories
                originalProtein += ingredient.protein
                originalCarbs += ingredient.carbs
                originalFat += ingredient.fat
            }
        }
    }
    
    // Apply ingredient changes to the food
    private func applyIngredientChanges() {
        // Save the context after removing ingredients
        let context = CoreDataManager.shared.context
        
        guard let ingredients = food.ingredients as? Set<Ingredient> else { return }
        
        if !removedIngredients.isEmpty {
            // Actually remove the ingredients from CoreData
            for ingredient in ingredients {
                if let id = ingredient.id, removedIngredients.contains(id) {
                    context.delete(ingredient)
                }
            }
            
            // Update the food's nutrition values
            food.calories = originalCalories
            food.protein = originalProtein
            food.carbs = originalCarbs
            food.fat = originalFat
            
            // Save changes
            do {
                try context.save()
                print("✅ Successfully removed ingredients and updated nutrition values")
            } catch {
                print("❌ Error saving context after removing ingredients: \(error)")
            }
        }
    }
    
    // Add a new ingredient to the food
    private func addIngredient(_ ingredientFood: Food) {
        let context = CoreDataManager.shared.context
        
        // Create new ingredient
        let ingredient = Ingredient(context: context)
        ingredient.id = UUID()
        ingredient.name = ingredientFood.name
        ingredient.originalName = ingredientFood.name
        ingredient.calories = ingredientFood.calories
        ingredient.protein = ingredientFood.protein
        ingredient.carbs = ingredientFood.carbs
        ingredient.fat = ingredientFood.fat
        ingredient.createdAt = Date()
        ingredient.amount = 1.0
        ingredient.unit = "g"
        ingredient.food = food
        
        // Update food nutrition
        originalCalories += ingredientFood.calories
        originalProtein += ingredientFood.protein
        originalCarbs += ingredientFood.carbs
        originalFat += ingredientFood.fat
        
        // Save the food nutrition values
        food.calories = originalCalories
        food.protein = originalProtein
        food.carbs = originalCarbs
        food.fat = originalFat
        
        // Save changes
        do {
            try context.save()
            print("✅ Successfully added ingredient and updated nutrition values")
        } catch {
            print("❌ Error adding ingredient: \(error)")
        }
    }
    
    // Save final changes and add to log
    private func saveChanges() {
        // Apply any pending ingredient changes
        applyIngredientChanges()
        
        // Update the timestamp to make sure it appears at the top of recently logged
        food.createdAt = Date()
        
        // Mark as standalone food (not ingredient)
        food.isIngredient = false
        
        // Apply adjustments for portion and size
        let sizeMultiplier = sizeMultipliers[selectedSize] ?? 1.0
        let portionMultiplier = Double(portions)
        let totalMultiplier = sizeMultiplier * portionMultiplier
        
        // Save the multiplier info in UserDefaults
        if let id = food.id?.uuidString {
            UserDefaults.standard.set(totalMultiplier, forKey: "food_multiplier_\(id)")
        }
        
        // Save changes
        do {
            try CoreDataManager.shared.context.save()
            print("✅ Successfully saved food changes")
            
            // Notify about food update
            NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
        } catch {
            print("❌ Error saving food changes: \(error)")
        }
    }
} 