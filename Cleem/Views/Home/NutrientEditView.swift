import SwiftUI
import Combine

struct NutrientEditView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // Properties
    var nutrientType: NutrientType
    @Binding var value: Int
    
    // References to other nutrients for recalculation
    @Binding var calorieGoal: Int
    @Binding var proteinGoal: Int
    @Binding var carbsGoal: Int
    @Binding var fatGoal: Int
    
    // State for editing
    @State private var localValue: Int
    @State private var inputValue: String = ""
    @State private var initialValue: Int
    @State private var displayValue: Int
    @State private var animateItems = false
    @State private var isNavigating = false
    @FocusState private var isInputFocused: Bool
    
    // Calculate progress for indicator
    private var relativeProgress: CGFloat {
        let min = nutrientType.minValue
        let max = nutrientType.maxValue
        
        // Calculate progress in range 0.1 to 1.0 (never empty)
        let progress = CGFloat(displayValue - min) / CGFloat(max - min)
        return 0.1 + (progress * 0.9) // Min 10% circle always filled
    }
    
    // Init
    init(nutrientType: NutrientType, value: Binding<Int>, calorieGoal: Binding<Int>, proteinGoal: Binding<Int>, carbsGoal: Binding<Int>, fatGoal: Binding<Int>) {
        self.nutrientType = nutrientType
        self._value = value
        self._calorieGoal = calorieGoal
        self._proteinGoal = proteinGoal
        self._carbsGoal = carbsGoal
        self._fatGoal = fatGoal
        self._localValue = State(initialValue: value.wrappedValue)
        self._initialValue = State(initialValue: value.wrappedValue)
        self._displayValue = State(initialValue: value.wrappedValue)
        self._inputValue = State(initialValue: String(value.wrappedValue))
    }
    
    var body: some View {
        ZStack {
            // Background color
            Color.white.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Top bar with back button
                HStack {
                    Button(action: {
                        if isNavigating { return }
                        isNavigating = true
                        
                        // Vibration on tap
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        // Dismiss sheet
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "xmark")
                                .foregroundColor(.black)
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .padding(.leading, 20)
                    .disabled(isNavigating)
                    
                    Spacer()
                }
                .padding(.top, 16)
                
                // Title
                Text("Edit \(nutrientType.title)")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 30)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer().frame(height: 50)
                
                // Indicator container
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 15).fill(Color.white))
                        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                    
                    HStack {
                        // Progress indicator
                        ZStack {
                            // Background circle
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                                .frame(width: 70, height: 70)
                            
                            // Progress circle
                            Circle()
                                .trim(from: 0, to: relativeProgress)
                                .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .foregroundColor(nutrientType.color)
                                .frame(width: 70, height: 70)
                                .rotationEffect(Angle(degrees: -90))
                                .animation(.easeInOut(duration: 0.3), value: displayValue)
                            
                            // Icon
                            // Use square backgrounds with letters for all nutrients
                            RoundedRectangle(cornerRadius: 4)
                                .fill(nutrientType.color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: nutrientType.iconName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                        }
                        .padding(.leading, 25)
                        .padding(.vertical, 20)
                        
                        Spacer()
                        
                        // Display value
                        Text(displayValue.description)
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.trailing)
                            .padding(.trailing, 30)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: displayValue)
                    }
                }
                .frame(height: 120)
                .padding(.horizontal, 20)
                
                // Input field
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                        .background(RoundedRectangle(cornerRadius: 15).fill(Color.white))
                    
                    HStack {
                        Text(nutrientType.title)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color.gray.opacity(0.8))
                            .padding(.leading, 25)
                        
                        Spacer()
                        
                        // Input field
                        TextField("", text: $inputValue)
                            .keyboardType(.numberPad)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            .padding(.trailing, 30)
                            .focused($isInputFocused)
                            .onChange(of: inputValue) { newValue in
                                handleInputChange(newValue)
                            }
                            .onChange(of: isInputFocused) { focused in
                                if focused {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred(intensity: 0.4)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(isInputFocused ? Color.gray.opacity(0.1) : Color.clear)
                                    .animation(.easeInOut(duration: 0.2), value: isInputFocused)
                            )
                    }
                }
                .frame(height: 80)
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .onTapGesture {
                    isInputFocused = true
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 15) {
                    // Revert button
                    Button(action: {
                        // More noticeable vibration for Revert
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.prepare()
                        generator.impactOccurred(intensity: 0.8)
                        
                        // Reset to initial value
                        localValue = initialValue
                        inputValue = String(initialValue)
                    }) {
                        Text("Revert")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    .background(Capsule().fill(Color.white))
                            )
                    }
                    
                    // Done button
                    Button(action: {
                        if isNavigating { return }
                        isNavigating = true
                        
                        // Hide keyboard
                        isInputFocused = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        
                        saveChanges()
                    }) {
                        Text("Done")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                Capsule()
                                    .fill(Color.black)
                            )
                    }
                    .disabled(isNavigating)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .onAppear {
                isNavigating = false
                
                // Immediately focus the input field to show keyboard
                isInputFocused = true
                
                // Set initial values
                displayValue = localValue
            }
        }
    }
    
    // Handle input changes
    private func handleInputChange(_ newValue: String) {
        // Check if input is empty
        if newValue.isEmpty {
            inputValue = ""
            return
        }
        
        // Remove non-numeric characters
        let filtered = newValue.filter { "0123456789".contains($0) }
        
        // If something changed after filtering, update text
        if filtered != newValue {
            inputValue = filtered
            return
        }
        
        // Cap at maximum value
        if let intValue = Int(filtered), intValue > nutrientType.maxValue {
            inputValue = String(nutrientType.maxValue)
            
            // Light vibration when exceeding maximum
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred(intensity: 0.5)
            
            return
        }
        
        // Save entered value
        if let intValue = Int(filtered) {
            localValue = intValue
        }
    }
    
    // Recalculate nutrients when one changes
    private func recalculateNutrients() {
        // Check which nutrient type is being edited
        switch nutrientType {
        case .calories:
            // If the calories change, recalculate other nutrients maintaining the same proportions
            let newCalories = Double(localValue)
            
            if newCalories > 0 {
                // Calculate current proportions
                let proteinRatio = Double(initialValue) > 0.0 ? Double(proteinGoal) * 4 / Double(initialValue) : 0.3
                let carbsRatio = Double(initialValue) > 0.0 ? Double(carbsGoal) * 4 / Double(initialValue) : 0.45
                let fatRatio = Double(initialValue) > 0.0 ? Double(fatGoal) * 9 / Double(initialValue) : 0.25
                
                // Apply same proportions to new calories
                let newProteinCalories = newCalories * proteinRatio
                let newCarbsCalories = newCalories * carbsRatio
                let newFatCalories = newCalories * fatRatio
                
                // Convert back to grams
                proteinGoal = Int(round(newProteinCalories / 4))
                carbsGoal = Int(round(newCarbsCalories / 4))
                fatGoal = Int(round(newFatCalories / 9))
                calorieGoal = Int(newCalories)
            }
            
        case .protein:
            // If protein changes, adjust carbs and fat to maintain the same calorie total
            let oldProteinCalories = Double(initialValue) * 4
            let newProteinCalories = Double(localValue) * 4
            
            let oldCarbsCalories = Double(carbsGoal) * 4
            let oldFatCalories = Double(fatGoal) * 9
            
            // Calculate total calories
            let totalCalories = oldProteinCalories + oldCarbsCalories + oldFatCalories
            
            if totalCalories > 0 {
                // Calculate remaining calories after protein
                let remainingCalories = totalCalories - newProteinCalories
                
                // Maintain same proportions between carbs and fat
                var carbsToFatRatio: Double = 0.5 // Default to 50/50 if sum is zero
                if (oldCarbsCalories + oldFatCalories) > 0 {
                    carbsToFatRatio = oldCarbsCalories / (oldCarbsCalories + oldFatCalories)
                }
                
                // Adjust carbs and fat
                let newCarbsCalories = remainingCalories * carbsToFatRatio
                let newFatCalories = remainingCalories * (1 - carbsToFatRatio)
                
                // Convert to grams
                carbsGoal = Int(round(newCarbsCalories / 4))
                fatGoal = Int(round(newFatCalories / 9))
                calorieGoal = Int(round(newProteinCalories + newCarbsCalories + newFatCalories))
                proteinGoal = localValue
            }
            
        case .carbs:
            // If carbs change, adjust protein and fat to maintain the same calorie total
            let oldCarbsCalories = Double(initialValue) * 4
            let newCarbsCalories = Double(localValue) * 4
            
            let oldProteinCalories = Double(proteinGoal) * 4
            let oldFatCalories = Double(fatGoal) * 9
            
            // Calculate total calories
            let totalCalories = oldProteinCalories + oldCarbsCalories + oldFatCalories
            
            if totalCalories > 0 {
                // Calculate remaining calories after carbs
                let remainingCalories = totalCalories - newCarbsCalories
                
                // Maintain same proportions between protein and fat
                var proteinToFatRatio: Double = 0.6 // Default to 60/40 if sum is zero
                if (oldProteinCalories + oldFatCalories) > 0 {
                    proteinToFatRatio = oldProteinCalories / (oldProteinCalories + oldFatCalories)
                }
                
                // Adjust protein and fat
                let newProteinCalories = remainingCalories * proteinToFatRatio
                let newFatCalories = remainingCalories * (1 - proteinToFatRatio)
                
                // Convert to grams
                proteinGoal = Int(round(newProteinCalories / 4))
                fatGoal = Int(round(newFatCalories / 9))
                calorieGoal = Int(round(newProteinCalories + newCarbsCalories + newFatCalories))
                carbsGoal = localValue
            }
            
        case .fat:
            // If fat changes, adjust protein and carbs to maintain the same calorie total
            let oldFatCalories = Double(initialValue) * 9
            let newFatCalories = Double(localValue) * 9
            
            let oldProteinCalories = Double(proteinGoal) * 4
            let oldCarbsCalories = Double(carbsGoal) * 4
            
            // Calculate total calories
            let totalCalories = oldProteinCalories + oldCarbsCalories + oldFatCalories
            
            if totalCalories > 0 {
                // Calculate remaining calories after fat
                let remainingCalories = totalCalories - newFatCalories
                
                // Maintain same proportions between protein and carbs
                var proteinToCarbsRatio: Double = 0.4 // Default to 40/60 if sum is zero
                if (oldProteinCalories + oldCarbsCalories) > 0 {
                    proteinToCarbsRatio = oldProteinCalories / (oldProteinCalories + oldCarbsCalories)
                }
                
                // Adjust protein and carbs
                let newProteinCalories = remainingCalories * proteinToCarbsRatio
                let newCarbsCalories = remainingCalories * (1 - proteinToCarbsRatio)
                
                // Convert to grams
                proteinGoal = Int(round(newProteinCalories / 4))
                carbsGoal = Int(round(newCarbsCalories / 4))
                calorieGoal = Int(round(newProteinCalories + newCarbsCalories + newFatCalories))
                fatGoal = localValue
            }
        }
    }
    
    // Done button action helper
    private func saveChanges() {
        // Save value
        if let newValue = Int(inputValue), newValue >= nutrientType.minValue, newValue <= nutrientType.maxValue {
            localValue = newValue
            value = newValue
            displayValue = newValue
            
            // Calculate other nutrients based on the change
            recalculateNutrients()
        }
        
        // Success haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        
        // Dismiss view
        presentationMode.wrappedValue.dismiss()
    }
}

// Preview for NutrientEditView
struct NutrientEditView_Previews: PreviewProvider {
    static var previews: some View {
        NutrientEditView(
            nutrientType: .calories,
            value: .constant(1100),
            calorieGoal: .constant(1100),
            proteinGoal: .constant(130),
            carbsGoal: .constant(200),
            fatGoal: .constant(65)
        )
    }
}

