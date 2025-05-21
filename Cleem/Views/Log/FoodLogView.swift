import SwiftUI
import CoreData

struct FoodLogView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var selectedDate = Date()
    @State private var foodEntries: [FoodLogEntry] = []
    @State private var isShowingFoodSearch = false
    @State private var currentMealType = ""
    
    private let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snacks"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Date selector
                    DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .labelsHidden()
                        .padding(.horizontal)
                    
                    // Nutrition summary for the day
                    dailySummaryCard
                    
                    // Food entries by meal type
                    ForEach(mealTypes, id: \.self) { mealType in
                        let entries = entriesForMealType(mealType)
                        
                        if !entries.isEmpty {
                            mealSectionCard(title: mealType, entries: entries)
                        } else {
                            emptyMealSection(title: mealType)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Food Log")
            .onAppear(perform: loadFoodEntries)
            .sheet(isPresented: $isShowingFoodSearch) {
                FoodSearchView(mealType: currentMealType, onFoodSelected: { foodItem, nutrition in
                    addFoodEntry(foodItem: foodItem, nutrition: nutrition, mealType: currentMealType)
                })
            }
        }
    }
    
    private var dailySummaryCard: some View {
        VStack(spacing: 16) {
            Text("Today's Summary")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            HStack(spacing: 20) {
                // Calories summary
                VStack {
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(totalCalories)")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("of \(navigationCoordinator.userProfile.dailyCalorieTarget)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                // Protein summary
                MacroProgressSummary(
                    name: "Protein",
                    current: totalProtein,
                    target: navigationCoordinator.userProfile.proteinGramsTarget,
                    color: .red
                )
                
                // Carbs summary
                MacroProgressSummary(
                    name: "Carbs",
                    current: totalCarbs,
                    target: navigationCoordinator.userProfile.carbsGramsTarget,
                    color: .blue
                )
                
                // Fat summary
                MacroProgressSummary(
                    name: "Fat",
                    current: totalFat,
                    target: navigationCoordinator.userProfile.fatGramsTarget,
                    color: .yellow
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func mealSectionCard(title: String, entries: [FoodLogEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.leading)
            
            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    FoodLogEntryRow(entry: entry)
                    
                    if entry != entries.last {
                        Divider()
                            .padding(.leading)
                    }
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func emptyMealSection(title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.leading)
            
            HStack {
                Text("No \(title.lowercased()) items logged")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    // Add food for this meal type
                    showFoodSearch(for: title)
                }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private func loadFoodEntries() {
        // In a real app, this would load from a database or persistence layer
        // For this example, we'll use sample data
        foodEntries = FoodLogEntry.sampleEntries
    }
    
    private func entriesForMealType(_ mealType: String) -> [FoodLogEntry] {
        return foodEntries.filter { $0.mealType == mealType && Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    private var totalCalories: Int {
        return foodEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .reduce(0) { $0 + $1.calories }
    }
    
    private var totalProtein: Int {
        return foodEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .reduce(0) { $0 + $1.protein }
    }
    
    private var totalCarbs: Int {
        return foodEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .reduce(0) { $0 + $1.carbs }
    }
    
    private var totalFat: Int {
        return foodEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .reduce(0) { $0 + $1.fat }
    }
    
    private func showFoodSearch(for mealType: String) {
        currentMealType = mealType
        isShowingFoodSearch = true
    }
    
    private func addFoodEntry(foodItem: FoodItem, nutrition: FoodNutrition, mealType: String) {
        let servingSizeText = "\(Int(foodItem.servingSize)) \(foodItem.servingUnit ?? "g")"
        let newEntry = FoodLogEntry(
            foodName: foodItem.name,
            servingSize: servingSizeText,
            calories: Int(nutrition.calories),
            protein: Int(nutrition.protein),
            carbs: Int(nutrition.carbs),
            fat: Int(nutrition.fat),
            date: selectedDate,
            mealType: mealType,
            foodImage: foodItem.image
        )
        
        // Add to our local array
        foodEntries.append(newEntry)
        
        // In a real app, you would also save to a persistence layer here
    }
}

struct MacroProgressSummary: View {
    let name: String
    let current: Int
    let target: Int
    let color: Color
    
    private var percentage: Double {
        guard target > 0 else { return 0 }
        return min(Double(current) / Double(target), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: CGFloat(percentage))
                    .stroke(color, lineWidth: 4)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                
                Text("\(current)g")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            
            Text("\(Int(percentage * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct FoodLogEntryRow: View {
    let entry: FoodLogEntry
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        HStack(spacing: 15) {
            if let image = entry.foodImage {
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
                Text(entry.foodName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(entry.servingSize) • \(entry.calories) kcal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Nutrient icons with values
            HStack(spacing: 6) {
                // Protein - P in red square
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Text("P")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                    Text("\(entry.protein)g")
                        .font(.system(size: 9))
                        .foregroundColor(.black)
                }
                
                // Carbs - C in blue square
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Text("C")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                    Text("\(entry.carbs)g")
                        .font(.system(size: 9))
                        .foregroundColor(.black)
                }
                
                // Fats - F in orange square
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Text("F")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        )
                    Text("\(entry.fat)g")
                        .font(.system(size: 9))
                        .foregroundColor(.black)
                }
            }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedTime(from: entry.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            // Create FoodNutrition object from entry data
            let nutrition = FoodNutrition(
                calories: Double(entry.calories),
                protein: Double(entry.protein),
                carbs: Double(entry.carbs),
                fat: Double(entry.fat),
                sugars: 0,
                fiber: 0,
                sodium: 0,
                servingSize: 100,
                servingUnit: "г",
                foodName: entry.foodName,
                source: "log"
            )
            
            // Create a FoodItem from entry data
            let foodItem = FoodItem(
                name: entry.foodName,
                category: entry.mealType,
                servingSize: 100, // Default to 100g since we can't parse the string easily
                servingUnit: "g",
                description: nil,
                image: entry.foodImage
            )
            
            // Set the nutrition and navigate to the details view
            navigationCoordinator.foodNutrition = nutrition
            navigationCoordinator.activeScreen = .nutritionDetails(foodItem: foodItem)
        }
    }
    
    private func formattedTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

struct FoodLogEntry: Identifiable, Equatable {
    let id = UUID()
    let foodName: String
    let servingSize: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let date: Date
    let mealType: String
    let foodImage: UIImage?
    
    // Implement Equatable conformance
    static func == (lhs: FoodLogEntry, rhs: FoodLogEntry) -> Bool {
        // We only compare by ID because UIImage is not Equatable
        // and we want to ensure entries with the same ID are considered equal
        return lhs.id == rhs.id
    }
    
    static var sampleEntries: [FoodLogEntry] {
        // Breakfast entries
        let breakfastEntries = [
            FoodLogEntry(
                foodName: "Oatmeal with Berries",
                servingSize: "1 bowl (250g)",
                calories: 220,
                protein: 6,
                carbs: 38,
                fat: 4,
                date: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!,
                mealType: "Breakfast",
                foodImage: nil
            ),
            FoodLogEntry(
                foodName: "Greek Yogurt",
                servingSize: "1 cup (200g)",
                calories: 150,
                protein: 20,
                carbs: 8,
                fat: 4,
                date: Calendar.current.date(bySettingHour: 8, minute: 15, second: 0, of: Date())!,
                mealType: "Breakfast",
                foodImage: nil
            )
        ]
        
        // Lunch entries
        let lunchEntries = [
            FoodLogEntry(
                foodName: "Grilled Chicken Salad",
                servingSize: "1 plate (350g)",
                calories: 320,
                protein: 35,
                carbs: 15,
                fat: 12,
                date: Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: Date())!,
                mealType: "Lunch",
                foodImage: nil
            )
        ]
        
        return breakfastEntries + lunchEntries
    }
}

struct FoodLogView_Previews: PreviewProvider {
    static var previews: some View {
        FoodLogView()
            .environmentObject(NavigationCoordinator.shared)
    }
}


