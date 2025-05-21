import SwiftUI

struct FoodDetailsView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    let foodItem: FoodItem
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with food name and close button
                HStack {
                    Text(foodItem.name)
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
                
                // Food image
                if let image = foodItem.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                
                // Food details
                VStack(alignment: .leading, spacing: 16) {
                    // Basic information section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Food Information")
                            .font(.headline)
                        
                        Divider()
                        
                        HStack {
                            Text("Category")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(foodItem.category)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Text("Serving Size")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(foodItem.servingSize)) \(foodItem.servingUnit ?? "g")")
                                .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // View nutrition button
                    if let nutrition = navigationCoordinator.foodNutrition {
                        Button(action: {
                            navigationCoordinator.activeScreen = .nutritionDetails(foodItem: foodItem)
                        }) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                Text("View Nutrition Facts")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    
                    // Description
                    if let description = foodItem.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            
                            Divider()
                            
                            Text(description)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationBarHidden(true)
    }
}

struct FoodDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleFood = FoodItem(
            id: UUID().uuidString,
            name: "Apple",
            category: "Fruits",
            servingSize: 182,
            servingUnit: "g",
            description: "A crisp and sweet apple, rich in fiber and vitamin C.",
            image: nil
        )
        
        return FoodDetailsView(foodItem: sampleFood)
            .environmentObject(NavigationCoordinator.shared)
    }
}

