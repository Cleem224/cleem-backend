import SwiftUI
import UIKit

struct IndividualFoodDetailsView: View {
    let food: Food
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @Environment(\.colorScheme) var colorScheme
    
    // State variables
    @State private var portions: Int = 1
    @State private var isShowingPortionInput: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var appearCompleted = false
    
    // Calculated nutrition values based on portions
    private var totalCalories: Double {
        return food.calories * Double(portions)
    }
    
    private var totalProtein: Double {
        return food.protein * Double(portions)
    }
    
    private var totalCarbs: Double {
        return food.carbs * Double(portions)
    }
    
    private var totalFat: Double {
        return food.fat * Double(portions)
    }
    
    var body: some View {
        ZStack {
            // Background color
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header with image
                    headerSection
                    
                    // Nutrition information
                    VStack(spacing: 20) {
                        // Name and calories
                        foodHeaderSection
                        
                        // Nutritional information
                        NutritionCirclesView(
                            calories: totalCalories,
                            protein: totalProtein,
                            carbs: totalCarbs,
                            fat: totalFat
                        )
                        .padding(.horizontal)
                        
                        // Portion selection
                        portionControlSection
                            .padding(.top, 10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: -2)
                    )
                    .offset(y: -20)
                    
                    Spacer(minLength: 40)
                }
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    CloseButtonView()
                        .environmentObject(navigationCoordinator)
                }
                Spacer()
            }
            .padding(.top, 10)
            .padding(.trailing, 10)
            
            // Portion input overlay
            if isShowingPortionInput {
                PortionInputView(portions: $portions, isShowingPortionInput: $isShowingPortionInput)
            }
        }
        .onAppear {
            // Initial animation to indicate successful load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    appearCompleted = true
                }
            }
        }
        .reliableDismiss(with: navigationCoordinator)
    }
    
    // MARK: - View Components
    
    // Header with food image
    private var headerSection: some View {
        ZStack(alignment: .top) {
            // Background image
            if let imageData = food.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: UIScreen.main.bounds.width, height: 300)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.4), Color.black.opacity(0)]),
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            } else {
                // Fallback if no image
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: UIScreen.main.bounds.width, height: 300)
                    
                    Image(systemName: getIconForFood(food.name ?? ""))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(getColorForFood(food.name ?? ""))
                        .frame(width: 100, height: 100)
                }
            }
        }
        .frame(height: 300)
    }
    
    // Food name and calories section
    private var foodHeaderSection: some View {
        VStack(spacing: 10) {
            // Food name
            Text(food.name ?? "Food")
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(appearCompleted ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.5), value: appearCompleted)
            
            // Calories
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(Int(totalCalories)) calories")
                    .font(.system(size: 18, weight: .medium))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .background(
                Capsule()
                    .fill(Color.orange.opacity(0.15))
            )
            .padding(.bottom, 10)
        }
    }
    
    // Portion control section
    private var portionControlSection: some View {
        VStack(spacing: 10) {
            Text("Portions")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                // Decrease button
                Button(action: {
                    if portions > 1 {
                        portions -= 1
                    }
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(portions > 1 ? .primary : .gray)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color(.systemGray6))
                        )
                }
                .disabled(portions <= 1)
                
                // Portion number (tappable)
                Button(action: {
                    isShowingPortionInput = true
                }) {
                    Text("\(portions)")
                        .font(.system(size: 24, weight: .bold))
                        .frame(width: 60)
                }
                
                // Increase button
                Button(action: {
                    portions += 1
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color(.systemGray6))
                        )
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(.systemGray6).opacity(0.5))
            )
        }
    }
    
    // Helper to get icon for food type
    private func getIconForFood(_ foodName: String) -> String {
        let name = foodName.lowercased()
        
        if name.contains("apple") {
            return "apple.logo"
        } else if name.contains("banana") {
            return "leaf.fill"
        } else if name.contains("chicken") || name.contains("meat") || name.contains("beef") || name.contains("steak") {
            return "fork.knife"
        } else if name.contains("yogurt") || name.contains("milk") {
            return "cup.and.saucer.fill"
        } else if name.contains("bread") {
            return "square.grid.2x2.fill"
        } else if name.contains("cereal") || name.contains("rice") {
            return "dot.square.fill"
        } else if name.contains("juice") {
            return "drop.fill"
        } else if name.contains("broccoli") || name.contains("vegetable") {
            return "leaf.circle.fill"
        } else if name.contains("carrot") {
            return "triangle.fill"
        } else if name.contains("fish") || name.contains("salmon") || name.contains("seafood") {
            return "water.waves"
        } else if name.contains("coca-cola") || name.contains("cola") || name.contains("coke") {
            return "bubble.right.fill"
        } else if name.contains("water") {
            return "drop.fill"
        } else if name.contains("coffee") {
            return "cup.and.saucer.fill"
        } else if name.contains("egg") {
            return "oval.fill"
        }
        
        return "circle.grid.2x2.fill" // Default icon
    }
    
    // Helper to get color for food type
    private func getColorForFood(_ foodName: String) -> Color {
        let name = foodName.lowercased()
        
        if name.contains("apple") {
            return .red
        } else if name.contains("banana") {
            return .yellow
        } else if name.contains("chicken") || name.contains("meat") || name.contains("beef") || name.contains("steak") {
            return .brown
        } else if name.contains("yogurt") || name.contains("milk") {
            return .blue
        } else if name.contains("bread") {
            return .brown
        } else if name.contains("cereal") || name.contains("rice") {
            return .orange
        } else if name.contains("juice") {
            return .orange
        } else if name.contains("broccoli") || name.contains("vegetable") {
            return .green
        } else if name.contains("carrot") {
            return .orange
        } else if name.contains("fish") || name.contains("salmon") || name.contains("seafood") {
            return .blue
        } else if name.contains("coca-cola") || name.contains("cola") || name.contains("coke") {
            return .red
        } else if name.contains("water") {
            return .blue
        } else if name.contains("coffee") {
            return .brown
        } else if name.contains("egg") {
            return .yellow
        }
        
        return .green // Default color
    }
}

// Nutrition circles view for the individual food
struct NutritionCirclesView: View {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    
    var body: some View {
        VStack(spacing: 20) {
            // Nutrition title
            Text("Nutrition")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 5)
            
            // Nutrition circles
            HStack(spacing: 20) {
                // Protein circle
                NutritionCircleView(
                    title: "Protein",
                    value: protein,
                    unit: "g",
                    color: .red,
                    icon: "drop.fill"
                )
                
                // Carbs circle
                NutritionCircleView(
                    title: "Carbs",
                    value: carbs,
                    unit: "g",
                    color: .orange,
                    icon: "leaf.fill"
                )
                
                // Fat circle
                NutritionCircleView(
                    title: "Fat",
                    value: fat,
                    unit: "g",
                    color: .blue,
                    icon: "drop.fill"
                )
            }
        }
    }
}

// Individual nutrition circle component
struct NutritionCircleView: View {
    let title: String
    let value: Double
    let unit: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 70, height: 70)
                
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 16))
                    
                    Text("\(Int(value))\(unit)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
}

struct IndividualFoodDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock Food object for preview
        let context = CoreDataManager.shared.context
        let mockFood = Food(context: context)
        mockFood.name = "Apple"
        mockFood.calories = 52
        mockFood.protein = 0.3
        mockFood.carbs = 14
        mockFood.fat = 0.2
        
        return IndividualFoodDetailsView(food: mockFood)
            .environmentObject(NavigationCoordinator.shared)
            .previewLayout(.sizeThatFits)
    }
}


