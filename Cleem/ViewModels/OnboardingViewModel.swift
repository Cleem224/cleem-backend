import SwiftUI
import CoreData
import Foundation

// Use UserProfile enums
typealias Gender = UserProfile.Gender
typealias ActivityLevel = UserProfile.ActivityLevel
typealias FitnessGoal = UserProfile.FitnessGoal

class OnboardingViewModel: ObservableObject {
    @Published var currentStep = 1
    let totalSteps = 6
    
    // User information
    @Published var gender: Gender = .male
    @Published var age: Int = 30
    @Published var height: Double = 170.0  // cm
    @Published var currentWeight: Double = 70.0  // kg
    @Published var targetWeight: Double = 65.0  // kg
    @Published var activityLevel: ActivityLevel = .moderatelyActive
    @Published var goal: FitnessGoal = .loseWeight
    
    // Calculated values
    @Published var calculatedCalories: Int = 0
    @Published var calculatedProtein: Int = 0
    @Published var calculatedCarbs: Int = 0
    @Published var calculatedFat: Int = 0
    @Published var dailyWaterTarget: Double = 2.5  // liters
    @Published var dailyStepsTarget: Int = 10000
    
    // Set default values for faster testing
    func setDefaultValues() {
        // Calculate values locally first
        let defaultGender: Gender = .male
        let defaultAge = 30
        let defaultHeight = 175.0
        let defaultCurrentWeight = 75.0
        let defaultTargetWeight = 70.0
        let defaultActivityLevel: ActivityLevel = .moderatelyActive
        let defaultGoal: FitnessGoal = .loseWeight
        
        // Update all @Published properties at once on the main thread
        DispatchQueue.main.async {
            self.gender = defaultGender
            self.age = defaultAge
            self.height = defaultHeight
            self.currentWeight = defaultCurrentWeight
            self.targetWeight = defaultTargetWeight
            self.activityLevel = defaultActivityLevel
            self.goal = defaultGoal
            
            // Calculate nutrition goals after setting defaults
            self.calculateNutritionGoals()
        }
    }
    
    // Calculate daily nutrition goals based on user data
    func calculateNutritionGoals() {
        // Calculate BMR (Basal Metabolic Rate) using Mifflin-St Jeor Equation
        let bmr: Double
        if gender == .male {
            bmr = 10 * currentWeight + 6.25 * height - 5 * Double(age) + 5
        } else {
            bmr = 10 * currentWeight + 6.25 * height - 5 * Double(age) - 161
        }
        
        // Apply activity multiplier
        let activityMultiplier = activityLevel.activityMultiplier
        
        let maintenanceCalories = bmr * activityMultiplier
        
        // Calculate all values locally before updating published properties
        var calculatedCalorieGoal: Double
        var calculatedProteinGoal: Double
        var calculatedFatGoal: Double
        var calculatedCarbsGoal: Double
        var calculatedWaterTarget: Double
        var calculatedStepsTarget: Int
        
        // Adjust calories based on goal
        calculatedCalorieGoal = maintenanceCalories * goal.calorieAdjustment
        
        // Round to nearest 50
        calculatedCalorieGoal = round(calculatedCalorieGoal / 50) * 50
        
        // Calculate macronutrient goals
        if goal == .loseWeight {
            // Higher protein for weight loss
            calculatedProteinGoal = currentWeight * 2.0  // 2g per kg bodyweight
            calculatedFatGoal = currentWeight * 1.0      // 1g per kg bodyweight
            // Remaining calories from carbs
            let proteinCalories = calculatedProteinGoal * 4
            let fatCalories = calculatedFatGoal * 9
            let carbCalories = calculatedCalorieGoal - proteinCalories - fatCalories
            calculatedCarbsGoal = carbCalories / 4
        } else if goal == .gainMuscle {
            // Higher carbs for weight gain
            calculatedProteinGoal = currentWeight * 1.8  // 1.8g per kg bodyweight
            calculatedFatGoal = currentWeight * 1.0      // 1g per kg bodyweight
            // Remaining calories from carbs
            let proteinCalories = calculatedProteinGoal * 4
            let fatCalories = calculatedFatGoal * 9
            let carbCalories = calculatedCalorieGoal - proteinCalories - fatCalories
            calculatedCarbsGoal = carbCalories / 4
        } else {
            // Balanced for maintenance
            calculatedProteinGoal = currentWeight * 1.6  // 1.6g per kg bodyweight
            calculatedFatGoal = currentWeight * 0.8      // 0.8g per kg bodyweight
            // Remaining calories from carbs
            let proteinCalories = calculatedProteinGoal * 4
            let fatCalories = calculatedFatGoal * 9
            let carbCalories = calculatedCalorieGoal - proteinCalories - fatCalories
            calculatedCarbsGoal = carbCalories / 4
        }
        
        // Round macros to nearest whole number
        calculatedProteinGoal = round(calculatedProteinGoal)
        calculatedCarbsGoal = round(calculatedCarbsGoal)
        calculatedFatGoal = round(calculatedFatGoal)
        
        // Set daily water target based on weight
        calculatedWaterTarget = round((currentWeight * 0.033) * 10) / 10  // About 33ml per kg bodyweight
        
        // Set daily steps target based on activity level
        switch activityLevel {
        case .sedentary:
            calculatedStepsTarget = 8000
        case .lightlyActive:
            calculatedStepsTarget = 10000
        case .moderatelyActive:
            calculatedStepsTarget = 12000
        case .active:
            calculatedStepsTarget = 15000
        case .veryActive:
            calculatedStepsTarget = 15000
        }
        
        // Update all @Published properties at once on the main thread
        DispatchQueue.main.async {
            self.calculatedCalories = Int(calculatedCalorieGoal)
            self.calculatedProtein = Int(calculatedProteinGoal)
            self.calculatedCarbs = Int(calculatedCarbsGoal)
            self.calculatedFat = Int(calculatedFatGoal)
            self.dailyWaterTarget = calculatedWaterTarget
            self.dailyStepsTarget = calculatedStepsTarget
        }
    }
    
    // Go to previous step
    func goToPreviousStep() {
        if currentStep > 1 {
            currentStep -= 1
        }
    }
    
    // Go to next step
    func goToNextStep() {
        if currentStep < totalSteps {
            currentStep += 1
        }
    }
    
    // Save profile to UserProfile
    func saveProfile() {
        let userProfile = UserProfile()
        
        // Set values directly - no need for conversion now
        userProfile.gender = gender
        userProfile.age = age
        userProfile.heightInCm = Int(height)
        userProfile.weightInKg = currentWeight
        userProfile.targetWeightInKg = targetWeight
        userProfile.activityLevel = activityLevel
        userProfile.fitnessGoal = goal  // Changed field name from goal to fitnessGoal
        
        // Set calculated values
        userProfile.dailyCalorieTarget = calculatedCalories
        userProfile.proteinGramsTarget = calculatedProtein
        userProfile.carbsGramsTarget = calculatedCarbs
        userProfile.fatGramsTarget = calculatedFat
        
        // Save profile
        userProfile.updateProfile()
    }
    
    // Save user data to Core Data
    func saveUserData(context: NSManagedObjectContext) {
        // Just delegate to saveProfile for now
        saveProfile()
    }
} 