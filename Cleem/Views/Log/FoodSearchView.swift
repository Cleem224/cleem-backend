import SwiftUI

struct FoodSearchView: View {
    let mealType: String
    let onFoodSelected: (FoodItem, FoodNutrition) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    @State private var searchText = ""
    @State private var searchResults: [FoodItem] = []
    @State private var isSearching = false
    
    // Sample food database
    private let sampleFoods: [FoodItem] = [
        FoodItem(name: "Apple", category: "Fruits", servingSize: 182, servingUnit: "g", description: "Fresh apple", image: nil),
        FoodItem(name: "Banana", category: "Fruits", servingSize: 118, servingUnit: "g", description: "Yellow banana", image: nil),
        FoodItem(name: "Chicken Breast", category: "Proteins", servingSize: 100, servingUnit: "g", description: "Grilled chicken breast", image: nil),
        FoodItem(name: "Greek Yogurt", category: "Dairy", servingSize: 245, servingUnit: "g", description: "Plain Greek yogurt", image: nil),
        FoodItem(name: "Brown Rice", category: "Grains", servingSize: 195, servingUnit: "g", description: "Cooked brown rice", image: nil),
        FoodItem(name: "Salmon", category: "Proteins", servingSize: 100, servingUnit: "g", description: "Atlantic salmon fillet", image: nil),
        FoodItem(name: "Avocado", category: "Fruits", servingSize: 68, servingUnit: "g", description: "Fresh avocado", image: nil),
        FoodItem(name: "Spinach", category: "Vegetables", servingSize: 30, servingUnit: "g", description: "Raw spinach", image: nil),
        FoodItem(name: "Egg", category: "Proteins", servingSize: 50, servingUnit: "g", description: "Whole egg", image: nil),
        FoodItem(name: "Oatmeal", category: "Grains", servingSize: 234, servingUnit: "g", description: "Cooked oatmeal", image: nil)
    ]
    
    // Nutrition lookup for sample foods
    private func getNutrition(for food: FoodItem) -> FoodNutrition {
        switch food.name {
        case "Apple":
            return FoodNutrition(
                calories: 95,
                protein: 0.5,
                carbs: 25,
                fat: 0.3,
                sugars: 19,
                fiber: 4.4,
                sodium: 2,
                servingSize: 100,
                servingUnit: "г",
                foodName: "Apple",
                source: "sample"
            )
        case "Banana":
            return FoodNutrition(
                calories: 105,
                protein: 1.3,
                carbs: 27,
                fat: 0.4,
                sugars: 14,
                fiber: 3.1,
                sodium: 1,
                servingSize: 100,
                servingUnit: "г",
                foodName: "Banana",
                source: "sample"
            )
        case "Chicken Breast":
            return FoodNutrition(
                calories: 165,
                protein: 31,
                carbs: 0,
                fat: 3.6,
                sugars: 0,
                fiber: 0,
                sodium: 74,
                servingSize: 100,
                servingUnit: "г",
                foodName: "Chicken Breast",
                source: "sample"
            )
        case "Greek Yogurt":
            return FoodNutrition(
                calories: 145,
                protein: 20,
                carbs: 8,
                fat: 3.8,
                sugars: 7,
                fiber: 0,
                sodium: 68,
                servingSize: 100,
                servingUnit: "г",
                foodName: "Greek Yogurt",
                source: "sample"
            )
        case "Brown Rice":
            return FoodNutrition(
                calories: 216,
                protein: 5,
                carbs: 45,
                fat: 1.8,
                sugars: 0.7,
                fiber: 3.5,
                sodium: 10,
                servingSize: 100,
                servingUnit: "г",
                foodName: "Brown Rice",
                source: "sample"
            )
        case "Salmon":
            return FoodNutrition(
                calories: 208,
                protein: 22,
                carbs: 0,
                fat: 13,
                sugars: 0,
                fiber: 0,
                sodium: 59,
                servingSize: 100,
                servingUnit: "г",
                foodName: "Salmon",
                source: "sample"
            )
        case "Avocado":
            return FoodNutrition(
                calories: 160,
                protein: 2,
                carbs: 8.5,
                fat: 14.7,
                sugars: 0.7,
                fiber: 6.7,
                sodium: 7,
                servingSize: 100,
                servingUnit: "г",
                foodName: "Avocado",
                source: "sample"
            )
        case "Spinach":
            return FoodNutrition(
                calories: 7,
                protein: 0.9,
                carbs: 1.1,
                fat: 0.1,
                sugars: 0.1,
                fiber: 0.7,
                sodium: 24,
                servingSize: 100,
                servingUnit: "г",
                foodName: "Spinach",
                source: "sample"
            )
        case "Egg":
            return FoodNutrition(
                calories: 72,
                protein: 6.3,
                carbs: 0.4,
                fat: 5,
                sugars: 0.2,
                fiber: 0,
                sodium: 71,
                servingSize: 100,
                servingUnit: "г",
                foodName: "Egg",
                source: "sample"
            )
        case "Oatmeal":
            return FoodNutrition(
                calories: 166,
                protein: 5.9,
                carbs: 28,
                fat: 3.6,
                sugars: 0.6,
                fiber: 4,
                sodium: 9,
                servingSize: 100,
                servingUnit: "г",
                foodName: "Oatmeal",
                source: "sample"
            )
        default:
            // Generic nutrition data
            return FoodNutrition(
                calories: 100,
                protein: 5,
                carbs: 15,
                fat: 2,
                sugars: 5,
                fiber: 2,
                sodium: 50,
                servingSize: 100,
                servingUnit: "г",
                foodName: food.name,
                source: "sample"
            )
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search for food", text: $searchText)
                        .onChange(of: searchText) { _, newValue in
                            performSearch(query: newValue)
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Meal type header
                HStack {
                    Text("Adding to \(mealType)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 5)
                
                // Recent or suggested foods
                if searchText.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Suggested Foods")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top)
                        
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(sampleFoods) { food in
                                    FoodSearchItemRow(food: food) {
                                        selectFood(food)
                                    }
                                    Divider()
                                        .padding(.leading)
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                } else {
                    // Search results
                    if isSearching {
                        ProgressView("Searching...")
                            .padding()
                    } else if searchResults.isEmpty && !searchText.isEmpty {
                        VStack {
                            Spacer()
                            Text("No results found")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(searchResults) { food in
                                    FoodSearchItemRow(food: food) {
                                        selectFood(food)
                                    }
                                    Divider()
                                        .padding(.leading)
                                }
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
                
                // Custom food button
                Button(action: {
                    let customFood = FoodItem(
                        name: searchText.isEmpty ? "Custom Food" : searchText,
                        category: mealType,
                        servingSize: 100,
                        servingUnit: "g",
                        description: "Custom entry",
                        image: nil
                    )
                    selectFood(customFood)
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Custom Food")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Food Search")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            searchResults = sampleFoods.filter {
                $0.name.lowercased().contains(query.lowercased()) ||
                $0.category.lowercased().contains(query.lowercased())
            }
            isSearching = false
        }
    }
    
    private func selectFood(_ food: FoodItem) {
        // Create a copy of the food item with guaranteed non-nil servingUnit
        let sanitizedFood = FoodItem(
            id: food.id,
            name: food.name,
            category: food.category,
            servingSize: food.servingSize,
            servingUnit: food.servingUnit ?? "g",  // Ensure servingUnit is not nil
            description: food.description,
            image: food.image
        )
        
        let nutrition = getNutrition(for: food)
        onFoodSelected(sanitizedFood, nutrition)
        presentationMode.wrappedValue.dismiss()
    }
}

struct FoodSearchItemRow: View {
    let food: FoodItem
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 15) {
                if let image = food.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(Int(food.servingSize)) \(food.servingUnit ?? "g")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FoodSearchView_Previews: PreviewProvider {
    static var previews: some View {
        FoodSearchView(
            mealType: "Breakfast",
            onFoodSelected: { _, _ in }
        )
        .environmentObject(NavigationCoordinator.shared)
    }
}

