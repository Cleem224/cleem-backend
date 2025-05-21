import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @ObservedObject var profile: UserProfile
    @State private var showingSuccessAlert = false
    @State private var isFirstLaunch: Bool
    
    init(isFirstLaunch: Bool) {
        self.profile = NavigationCoordinator.shared.userProfile
        self.isFirstLaunch = isFirstLaunch
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView
                
                personalDetailsSection
                
                bodyMeasurementsSection
                
                fitnessGoalsSection
                
                Button(action: saveProfile) {
                    Text(isFirstLaunch ? "Complete Setup" : "Save Changes")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle(isFirstLaunch ? "Set Up Your Profile" : "Edit Profile")
        .alert(isFirstLaunch ? "Profile Created" : "Profile Updated", isPresented: $showingSuccessAlert) {
            Button("OK") {
                navigationCoordinator.dismissProfileSetup()
            }
        } message: {
            Text(isFirstLaunch ?
                "Your profile has been successfully created. You can now start tracking your nutrition!" :
                "Your profile has been successfully updated.")
        }
    }
    
    private var headerView: some View {
        VStack {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text(isFirstLaunch ? "Welcome to Cleem" : "Update Your Profile")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 10)
            
            Text(isFirstLaunch ?
                "Please set up your profile to get personalized nutrition recommendations" :
                "Update your information to keep your nutrition recommendations accurate")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.bottom, 20)
    }
    
    private var personalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Details")
                .font(.headline)
                .padding(.leading)
            
            VStack(spacing: 16) {
                TextField("Your Name", text: $profile.name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                HStack {
                    Text("Age:")
                    Spacer()
                    Stepper("\(profile.age) years", value: $profile.age, in: 18...100)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading) {
                    Text("Gender:")
                        .padding(.bottom, 5)
                    
                    Picker("Gender", selection: $profile.gender) {
                        ForEach(UserProfile.Gender.allCases, id: \.self) { gender in
                            Text(gender.rawValue).tag(gender)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    private var bodyMeasurementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Body Measurements")
                .font(.headline)
                .padding(.leading)
            
            VStack(spacing: 16) {
                HStack {
                    Text("Height:")
                    Spacer()
                    Stepper("\(profile.heightInCm) cm", value: $profile.heightInCm, in: 120...220)
                }
                .padding(.horizontal)
                
                HStack {
                    Text("Current Weight:")
                    Spacer()
                    HStack {
                        TextField("Weight", value: $profile.weightInKg, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("kg")
                    }
                }
                .padding(.horizontal)
                
                HStack {
                    Text("Target Weight:")
                    Spacer()
                    HStack {
                        TextField("Target Weight", value: $profile.targetWeightInKg, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("kg")
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    private var fitnessGoalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fitness Goals")
                .font(.headline)
                .padding(.leading)
            
            VStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Activity Level:")
                        .padding(.bottom, 5)
                    
                    Picker("Activity Level", selection: $profile.activityLevel) {
                        ForEach(UserProfile.ActivityLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading) {
                    Text("Goal:")
                        .padding(.bottom, 5)
                    
                    Picker("Goal", selection: $profile.fitnessGoal) {
                        ForEach(UserProfile.FitnessGoal.allCases, id: \.self) { goal in
                            Text(goal.rawValue).tag(goal)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)
                
                if profile.calculateBMI() > 0 {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("BMI: \(String(format: "%.1f", profile.calculateBMI()))")
                            .fontWeight(.medium)
                        
                        Text(bmiCategory)
                            .font(.caption)
                            .foregroundColor(bmiCategoryColor)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
            }
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    private var bmiCategory: String {
        let bmi = profile.calculateBMI()
        switch bmi {
        case ..<18.5:
            return "Underweight"
        case 18.5..<25:
            return "Normal weight"
        case 25..<30:
            return "Overweight"
        default:
            return "Obesity"
        }
    }
    
    private var bmiCategoryColor: Color {
        let bmi = profile.calculateBMI()
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
    
    private func saveProfile() {
        profile.updateProfile()
        showingSuccessAlert = true
    }
}

struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ProfileSetupView(isFirstLaunch: true)
                .environmentObject(NavigationCoordinator.shared)
        }
    }
}

