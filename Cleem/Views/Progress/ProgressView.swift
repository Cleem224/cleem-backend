import SwiftUI

struct NutritionProgressView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var selectedPeriod: TimePeriod = .week
    
    enum TimePeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Period selection
                    Picker("Time Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    // Weight progress
                    weightProgressSection
                    
                    // Calories progress
                    caloriesProgressSection
                    
                    // Nutrition progress
                    macronutrientsProgressSection
                }
                .padding(.vertical)
            }
            .navigationTitle("Progress")
        }
    }
    
    private var weightProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weight Progress")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Current Weight")
                    Spacer()
                    Text("\(String(format: "%.1f", navigationCoordinator.userProfile.weightInKg)) kg")
                        .fontWeight(.medium)
                }
                
                Divider()
                
                HStack {
                    Text("Target Weight")
                    Spacer()
                    Text("\(String(format: "%.1f", navigationCoordinator.userProfile.targetWeightInKg)) kg")
                        .fontWeight(.medium)
                }
                
                Divider()
                
                HStack {
                    Text("Difference")
                    Spacer()
                    let difference = navigationCoordinator.userProfile.targetWeightInKg - navigationCoordinator.userProfile.weightInKg
                    Text("\(String(format: "%.1f", abs(difference))) kg \(difference >= 0 ? "to gain" : "to lose")")
                        .fontWeight(.medium)
                        .foregroundColor(difference == 0 ? .green : .orange)
                }
                
                // Placeholder for chart
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray6))
                        .frame(height: 180)
                    
                    Text("Weight chart placeholder")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
    
    private var caloriesProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calorie Intake")
                .font(.headline)
                .padding(.horizontal)
            
            // Placeholder for chart
            ZStack {
                Rectangle()
                    .fill(Color(.systemGray6))
                    .frame(height: 200)
                
                Text("Calorie intake chart placeholder")
                    .foregroundColor(.secondary)
            }
            .cornerRadius(10)
            .padding(.horizontal)
            
            HStack(spacing: 20) {
                VStack {
                    Text("Average")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("0")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("Target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(navigationCoordinator.userProfile.dailyCalorieTarget)")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("Trend")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("--")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
    
    private var macronutrientsProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Macronutrient Distribution")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                MacroProgressRow(
                    name: "Protein",
                    color: .red,
                    actual: 0,
                    target: navigationCoordinator.userProfile.proteinGramsTarget
                )
                
                MacroProgressRow(
                    name: "Carbs",
                    color: .blue,
                    actual: 0,
                    target: navigationCoordinator.userProfile.carbsGramsTarget
                )
                
                MacroProgressRow(
                    name: "Fat",
                    color: .yellow,
                    actual: 0,
                    target: navigationCoordinator.userProfile.fatGramsTarget
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
}

struct MacroProgressRow: View {
    let name: String
    let color: Color
    let actual: Int
    let target: Int
    
    private var percentage: Double {
        guard target > 0 else { return 0 }
        return min(Double(actual) / Double(target), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(actual)g of \(target)g")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(height: 10)
                        .cornerRadius(5)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 10)
                        .cornerRadius(5)
                }
            }
            .frame(height: 10)
        }
    }
}

struct NutritionProgressView_Previews: PreviewProvider {
    static var previews: some View {
        NutritionProgressView()
            .environmentObject(NavigationCoordinator.shared)
    }
} 