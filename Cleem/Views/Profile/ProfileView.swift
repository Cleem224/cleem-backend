import SwiftUI

struct ProfileView: View {
    @ObservedObject var coordinator: NavigationCoordinator
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile header with user avatar and name
                    profileHeader
                    
                    // Stats summary card
                    statsSummaryCard
                    
                    // Profile details
                    profileDetailsCard
                    
                    // Edit profile button
                    Button(action: {
                        coordinator.showProfileSetup()
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit Profile")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Profile")
        }
    }
    
    private var profileHeader: some View {
        VStack {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
                .padding(.bottom, 10)
            
            Text(coordinator.userProfile.name.isEmpty ? "User" : coordinator.userProfile.name)
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom, 5)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var statsSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Health Summary")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                // BMI Stat
                VStack {
                    Text("BMI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.1f", coordinator.userProfile.calculateBMI()))
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text(bmiCategory)
                        .font(.caption)
                        .foregroundColor(bmiCategoryColor)
                }
                .frame(maxWidth: .infinity)
                
                // Calories Stat
                VStack {
                    Text("Daily Calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(coordinator.userProfile.dailyCalorieTarget)")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                
                // Goal Stat
                VStack {
                    Text("Goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(goalText)
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    private var profileDetailsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Profile Details")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                ProfileInfoRow(title: "Age", value: "\(coordinator.userProfile.age) years")
                
                Divider()
                
                ProfileInfoRow(title: "Gender", value: coordinator.userProfile.gender.rawValue)
                
                Divider()
                
                ProfileInfoRow(title: "Height", value: "\(coordinator.userProfile.heightInCm) cm")
                
                Divider()
                
                ProfileInfoRow(title: "Weight", value: String(format: "%.1f kg", coordinator.userProfile.weightInKg))
                
                Divider()
                
                ProfileInfoRow(title: "Target Weight", value: String(format: "%.1f kg", coordinator.userProfile.targetWeightInKg))
                
                Divider()
                
                ProfileInfoRow(title: "Activity Level", value: activityLevelText)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    private var bmiCategory: String {
        let bmi = coordinator.userProfile.calculateBMI()
        switch bmi {
        case ..<18.5:
            return "Underweight"
        case 18.5..<25:
            return "Normal"
        case 25..<30:
            return "Overweight"
        default:
            return "Obese"
        }
    }
    
    private var bmiCategoryColor: Color {
        let bmi = coordinator.userProfile.calculateBMI()
        switch bmi {
        case ..<18.5:
            return .orange
        case 18.5..<25:
            return .green
        case 25..<30:
            return .orange
        default:
            return .red
        }
    }
    
    private var activityLevelText: String {
        switch coordinator.userProfile.activityLevel {
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
    
    private var goalText: String {
        switch coordinator.userProfile.fitnessGoal {
        case .loseWeight:
            return "Lose Weight"
        case .maintain:
            return "Maintain"
        case .gainMuscle:
            return "Gain Weight"
        }
    }
}

struct ProfileInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView(coordinator: NavigationCoordinator.shared)
    }
} 