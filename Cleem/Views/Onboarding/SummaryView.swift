import SwiftUI

struct SummaryView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @Environment(\.presentationMode) var presentationMode
    var completeOnboarding: () -> Void
    
    // Animation state
    @State private var animateElements = false
    
    init(viewModel: OnboardingViewModel, completeOnboarding: @escaping () -> Void) {
        self.viewModel = viewModel
        self.completeOnboarding = completeOnboarding
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Summary")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            Text("Please review your information")
                .foregroundColor(.secondary)
                .padding(.bottom)
            
            // Profile summary
            ScrollView {
                VStack(spacing: 15) {
                    SummaryInfoRow(title: "Gender", value: getGenderText(viewModel.gender))
                    SummaryInfoRow(title: "Age", value: "\(viewModel.age) years")
                    SummaryInfoRow(title: "Height", value: "\(Int(viewModel.height)) cm")
                    SummaryInfoRow(title: "Current Weight", value: String(format: "%.1f kg", viewModel.currentWeight))
                    SummaryInfoRow(title: "Target Weight", value: String(format: "%.1f kg", viewModel.targetWeight))
                    SummaryInfoRow(title: "Activity Level", value: getActivityLevelText(viewModel.activityLevel))
                    SummaryInfoRow(title: "Goal", value: getGoalText(viewModel.goal))
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(15)
                .padding(.horizontal)
                
                // Nutrition goals summary
                VStack(alignment: .leading, spacing: 15) {
                    Text("Daily Nutrition Goals")
                        .font(.headline)
                        .padding(.leading)
                    
                    VStack(spacing: 15) {
                        // Calories goal
                        HStack {
                            Text("Calories")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(viewModel.calculatedCalories) kcal")
                                .fontWeight(.semibold)
                        }
                        
                        Divider()
                        
                        // Protein goal
                        HStack {
                            Text("Protein")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(viewModel.calculatedProtein)g")
                                .fontWeight(.semibold)
                        }
                        
                        Divider()
                        
                        // Carbs goal
                        HStack {
                            Text("Carbs")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(viewModel.calculatedCarbs)g")
                                .fontWeight(.semibold)
                        }
                        
                        Divider()
                        
                        // Fat goal
                        HStack {
                            Text("Fat")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(viewModel.calculatedFat)g")
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    .padding(.horizontal)
                }
            }
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: {
                    // Save profile information
                    viewModel.saveProfile()
                    completeOnboarding()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Confirm & Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(height: 55)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    // Go back to edit information
                    viewModel.goToPreviousStep()
                }) {
                    Text("Go Back")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(height: 55)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
        .navigationBarHidden(true)
        .onAppear {
            // Add nutrition goals calculation here
            DispatchQueue.main.async {
                viewModel.calculateNutritionGoals()
            }
            
            // Trigger animations
            withAnimation(.easeOut(duration: 0.8)) {
                animateElements = true
            }
        }
    }
    
    // Helper functions to convert codes to display text
    private func getGenderText(_ gender: UserProfile.Gender) -> String {
        return gender.rawValue
    }
    
    private func getActivityLevelText(_ level: UserProfile.ActivityLevel) -> String {
        switch level {
        case .sedentary:
            return "Sedentary"
        case .lightlyActive:
            return "Lightly Active"
        case .moderatelyActive:
            return "Moderately Active"
        case .active:
            return "Active"
        case .veryActive:
            return "Very Active"
        }
    }
    
    private func getGoalText(_ goal: UserProfile.FitnessGoal) -> String {
        switch goal {
        case .loseWeight:
            return "Lose Weight"
        case .maintain:
            return "Maintain Weight"
        case .gainMuscle:
            return "Gain Muscle"
        }
    }
}

struct SummaryInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = OnboardingViewModel()
        SummaryView(viewModel: viewModel, completeOnboarding: {})
    }
} 