import SwiftUI
import CoreHaptics
import UIKit  // Добавляем UIKit для работы с UIApplication

struct TargetWeightView_Original: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var targetWeight: Double = 70.0
    @Environment(\.presentationMode) var presentationMode
    @State private var animateItems = false
    @State private var isNavigating = false
    
    // Состояние для нового селектора веса
    @State private var isEditing = false
    @State private var weightInput = ""
    @State private var selectedSegment = 1 // 0: -5%, 1: Текущий, 2: +5%
    @State private var weightOffset: Double = 0
    @State private var hapticEngine: CHHapticEngine?
    @State private var segmentSetByGoal = false // Track when segment is set by goal
    
    // Константы
    private let minWeight: Double = 30.0
    private let maxWeight: Double = 250.0
    private let hapticNotch: Double = 0.1
    
    var onContinue: () -> Void
    var onBack: () -> Void
    
    // Вычисляемые свойства
    private var displayWeight: Double {
        return max(minWeight, min(maxWeight, targetWeight))
    }
    
    private var weightStatus: String {
        let currentWeight = navigationCoordinator.userProfile.weightInKg
        if abs(displayWeight - currentWeight) < 0.5 {
            return "Maintain weight"
        } else if displayWeight > currentWeight {
            return "Gain weight"
        } else {
            return "Lose weight"
        }
    }
    
    private var weightChangeText: String {
        let currentWeight = navigationCoordinator.userProfile.weightInKg
        let change = displayWeight - currentWeight
        if abs(change) < 0.5 {
            return "Maintain your current weight"
        }
        
        let absChange = abs(change).roundedOriginal(to: 1)
        if change > 0 {
            return "Gain \(absChange) kg"
        } else {
            return "Lose \(absChange) kg"
        }
    }
    
    private var weightChangePercentage: String {
        let currentWeight = navigationCoordinator.userProfile.weightInKg
        if currentWeight <= 0 { return "" }
        
        let change = displayWeight - currentWeight
        let percentage = (change / currentWeight * 100).roundedOriginal(to: 1)
        let absPercentage = abs(percentage)
        
        if abs(percentage) < 0.5 {
            return ""
        } else if percentage > 0 {
            return "+\(absPercentage)%"
        } else {
            return "-\(absPercentage)%"
        }
    }
    
    var body: some View {
        ZStack {
            // Background color
            Color(red: 0.91, green: 0.97, blue: 1.0).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Top bar with back button and progress indicator
                HStack(spacing: 0) {
                    // Back button - standard gray button
                    Button(action: {
                        if isNavigating { return }
                        isNavigating = true
                        
                        withAnimation(.easeOut(duration: 0.15)) {
                            animateItems = false
                        }
                        
                        saveData()
                        
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onBack()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .scaleEffect(animateItems ? 1.0 : 0.1)
                                .opacity(animateItems ? 1.0 : 0)
                            
                            Image(systemName: "chevron.left")
                                .foregroundColor(.black)
                                .font(.system(size: 14, weight: .medium))
                                .opacity(animateItems ? 1.0 : 0)
                                .scaleEffect(animateItems ? 1.0 : 0.5)
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1), value: animateItems)
                    }
                    .padding(.leading, 20)
                    .disabled(isNavigating)
                    
                    // Standard progress indicator
                    ProgressBarView(currentStep: 5, totalSteps: 8)
                        .padding(.leading, 16)
                        .padding(.trailing, 20)
                        .opacity(animateItems ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: animateItems)
                }
                .padding(.top, 16)
                
                // Header with title
                VStack(alignment: .center, spacing: 8) {
                    Text("What is your")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("target weight?")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("This will be used to create your individual plan")
                        .font(.system(size: 16))
                        .foregroundColor(Color.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .frame(maxWidth: .infinity)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: animateItems)
                
                Spacer().frame(height: 40)
                
                // Modern Weight Selector
                VStack(spacing: 30) {
                    // Weight Display
                    ZStack {
                        // Weight Value
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", displayWeight))
                                .font(.system(size: 46, weight: .bold))
                                .foregroundColor(.black)
                                .contentTransition(.numericText(value: displayWeight))
                            
                            Text("kg")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundColor(.black.opacity(0.8))
                                .offset(y: 2)
                        }
                        .frame(height: 60)
                        
                        // Tap to edit functionality
                        if isEditing {
                            TextField("", text: $weightInput)
                                .font(.system(size: 46, weight: .bold))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.8))
                                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                )
                                .cornerRadius(10)
                                .frame(width: 180)
                                .onAppear {
                                    weightInput = String(format: "%.1f", displayWeight)
                                    // Автоматический фокус на поле ввода
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
                                    }
                                }
                                .onSubmit {
                                    if let value = Double(weightInput.replacingOccurrences(of: ",", with: ".")) {
                                        targetWeight = max(minWeight, min(maxWeight, value))
                                        targetWeight = (targetWeight * 10).rounded() / 10 // Округление до 0.1
                                    }
                                    isEditing = false
                                }
                        }
                    }
                    .frame(height: 60)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            isEditing = true
                        }
                    }
                    .opacity(animateItems ? 1 : 0)
                    .offset(y: animateItems ? 0 : 15)
                    .animation(.easeOut(duration: 0.5).delay(0.5), value: animateItems)
                    
                    // Weight Change Info
                    HStack(spacing: 10) {
                        Text(weightChangeText)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black.opacity(0.7))
                        
                        if !weightChangePercentage.isEmpty {
                            Text(weightChangePercentage)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(weightChangePercentage.starts(with: "+") ? .green : .red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(weightChangePercentage.starts(with: "+") ? 
                                              Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                )
                        }
                    }
                    .frame(height: 30)
                    .opacity(animateItems ? 1 : 0)
                    .offset(y: animateItems ? 0 : 15)
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: animateItems)
                    
                    // Weight Adjustment Controls
                    VStack(spacing: 20) {
                        // Quick adjust segments
                        HStack(spacing: 0) {
                            quickAdjustButton(
                                title: "Lose weight",
                                isSelected: selectedSegment == 0,
                                color: .red.opacity(0.8)
                            ) {
                                selectedSegment = 0
                                adjustWeight(-0.05)
                            }
                            
                            quickAdjustButton(
                                title: "Maintain",
                                isSelected: selectedSegment == 1,
                                color: .blue.opacity(0.8)
                            ) {
                                selectedSegment = 1
                                resetWeight()
                            }
                            
                            quickAdjustButton(
                                title: "Gain weight",
                                isSelected: selectedSegment == 2,
                                color: .green.opacity(0.8)
                            ) {
                                selectedSegment = 2
                                adjustWeight(0.05)
                            }
                        }
                        .frame(height: 44)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        )
                        
                        // Fine adjustment buttons
                        HStack(spacing: 20) {
                            // Decrement button
                            Button(action: {
                                decrementWeight()
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Circle().fill(Color.black))
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            }
                            
                            // Custom slider
                            weightAdjustmentSlider
                                .padding(.top, 0) // Убираем верхний отступ для центрирования
                            
                            // Increment button
                            Button(action: {
                                incrementWeight()
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Circle().fill(Color.black))
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            }
                        }
                        .frame(height: 50) // Фиксированная высота для всего ряда
                    }
                    .opacity(animateItems ? 1 : 0)
                    .offset(y: animateItems ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.7), value: animateItems)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Continue button
                Button(action: {
                    if isNavigating { return }
                    isNavigating = true
                    
                    saveData()
                    
                    withAnimation(.easeOut(duration: 0.15)) {
                        animateItems = false
                    }
                    
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onContinue()
                    }
                }) {
                    Text("Continue")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Capsule()
                                .fill(Color.black)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 30)
                .animation(.easeOut(duration: 0.5).delay(0.8), value: animateItems)
                .disabled(isNavigating)
            }
        }
        .onAppear {
            prepareHaptics()
            initializeValues()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    animateItems = true
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onTapGesture {
            if isEditing {
                isEditing = false
                if let value = Double(weightInput.replacingOccurrences(of: ",", with: ".")) {
                    targetWeight = max(minWeight, min(maxWeight, value))
                }
            }
        }
    }
    
    // MARK: - UI Components
    
    private func quickAdjustButton(title: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(isSelected ? color.opacity(0.15) : Color.clear)
                .foregroundColor(isSelected ? color : .black.opacity(0.7))
                .animation(.easeOut(duration: 0.2), value: isSelected)
        }
    }
    
    private var weightAdjustmentSlider: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 6)
                
                // Fill
                let progress = (targetWeight - minWeight) / (maxWeight - minWeight)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black)
                    .frame(width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(progress))), height: 6)
                
                // Marks for 25%, 50%, 75%
                ForEach([0.25, 0.5, 0.75], id: \.self) { mark in
                    Circle()
                        .fill(progress > mark ? Color.black : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .position(x: geometry.size.width * mark, y: 3)
                        .opacity(0.7)
                }
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
                    .offset(x: max(0, min(geometry.size.width - 28, geometry.size.width * CGFloat(progress) - 14)))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let ratio = value.location.x / geometry.size.width
                                let newWeight = minWeight + (maxWeight - minWeight) * Double(max(0, min(1, ratio)))
                                
                                // Round to nearest 0.1
                                let roundedWeight = round(newWeight / hapticNotch) * hapticNotch
                                let formattedWeight = Double(String(format: "%.1f", roundedWeight)) ?? roundedWeight
                                
                                if formattedWeight != targetWeight {
                                    // Применяем плавную анимацию при движении слайдера
                                    withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.7, blendDuration: 0.1)) {
                                        targetWeight = formattedWeight
                                    }
                                    
                                    // Update the selected segment
                                    updateSelectedSegment()
                                    
                                    // Provide haptic feedback for whole numbers
                                    if targetWeight.truncatingRemainder(dividingBy: 1) == 0 {
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.impactOccurred(intensity: 0.7)
                                    } else if targetWeight.truncatingRemainder(dividingBy: 0.5) == 0 {
                                        // Less intense feedback for half numbers
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred(intensity: 0.5)
                                    }
                                }
                            }
                    )
                    .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.7), value: progress)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 50)
    }
    
    // MARK: - Helper Methods
    
    private func initializeValues() {
        isNavigating = false
        
        // Initialize with the user's current target weight if available
        if navigationCoordinator.userProfile.targetWeightInKg > 0 {
            targetWeight = navigationCoordinator.userProfile.targetWeightInKg
        } else if navigationCoordinator.userProfile.weightInKg > 0 {
            targetWeight = navigationCoordinator.userProfile.weightInKg
        }
        
        // Sync goal and fitnessGoal if needed
        syncGoalProperties()
        
        // Set segment based on the user's goal first
        setSegmentBasedOnGoal()
    }
    
    private func syncGoalProperties() {
        // Make sure goal and fitnessGoal are in sync
        let userGoal = navigationCoordinator.userProfile.goal
        
        // Update fitnessGoal based on goal if they don't match
        switch userGoal {
        case .loseWeight:
            navigationCoordinator.userProfile.fitnessGoal = .loseWeight
        case .maintainWeight:
            navigationCoordinator.userProfile.fitnessGoal = .maintain
        case .gainMuscle:
            navigationCoordinator.userProfile.fitnessGoal = .gainMuscle
            
            // If the user selected "Gain Muscle" goal, set targetWeight higher than current weight
            let currentWeight = navigationCoordinator.userProfile.weightInKg
            if targetWeight <= currentWeight {
                // Set to 5% higher than current weight by default
                targetWeight = (currentWeight * 1.05).roundedOriginal(to: hapticNotch)
            }
        }
    }
    
    private func setSegmentBasedOnGoal() {
        segmentSetByGoal = true
        
        // Set the segment based on the goal first
        switch navigationCoordinator.userProfile.goal {
        case .loseWeight:
            selectedSegment = 0 // Lose weight
            
            // Adjust target weight if needed
            let currentWeight = navigationCoordinator.userProfile.weightInKg
            if targetWeight >= currentWeight {
                targetWeight = (currentWeight * 0.95).roundedOriginal(to: hapticNotch)
            }
            
        case .maintainWeight:
            selectedSegment = 1 // Maintain
            targetWeight = navigationCoordinator.userProfile.weightInKg.roundedOriginal(to: hapticNotch)
            
        case .gainMuscle:
            selectedSegment = 2 // Gain weight
            
            // Adjust target weight if needed
            let currentWeight = navigationCoordinator.userProfile.weightInKg
            if targetWeight <= currentWeight {
                targetWeight = (currentWeight * 1.05).roundedOriginal(to: hapticNotch)
            }
        }
    }
    
    private func saveData() {
        navigationCoordinator.userProfile.targetWeightInKg = targetWeight
        
        // Also update goal based on selected segment for consistency
        if selectedSegment == 0 {
            navigationCoordinator.userProfile.goal = .loseWeight
            navigationCoordinator.userProfile.fitnessGoal = .loseWeight
        } else if selectedSegment == 1 {
            navigationCoordinator.userProfile.goal = .maintainWeight
            navigationCoordinator.userProfile.fitnessGoal = .maintain
        } else if selectedSegment == 2 {
            navigationCoordinator.userProfile.goal = .gainMuscle
            navigationCoordinator.userProfile.fitnessGoal = .gainMuscle
        }
    }
    
    private func updateSelectedSegment() {
        // If the segment was set automatically by the goal, don't override it with weight calculations
        if segmentSetByGoal {
            segmentSetByGoal = false
            return
        }
        
        let currentWeight = navigationCoordinator.userProfile.weightInKg
        if abs(targetWeight - currentWeight) < 0.5 {
            selectedSegment = 1 // Maintain
        } else if targetWeight > currentWeight {
            selectedSegment = 2 // Gain
        } else {
            selectedSegment = 0 // Lose
        }
    }
    
    private func adjustWeight(_ percentage: Double) {
        let currentWeight = navigationCoordinator.userProfile.weightInKg
        let change = currentWeight * percentage
        targetWeight = (currentWeight + change).roundedOriginal(to: hapticNotch)
        triggerHapticFeedback()
    }
    
    private func resetWeight() {
        targetWeight = navigationCoordinator.userProfile.weightInKg.roundedOriginal(to: hapticNotch)
        triggerHapticFeedback()
    }
    
    private func incrementWeight() {
        targetWeight += hapticNotch
        targetWeight = min(maxWeight, targetWeight)
        targetWeight = (targetWeight * 10).rounded() / 10
        updateSelectedSegment()
        triggerHapticFeedback()
    }
    
    private func decrementWeight() {
        targetWeight -= hapticNotch
        targetWeight = max(minWeight, targetWeight)
        targetWeight = (targetWeight * 10).rounded() / 10
        updateSelectedSegment()
        triggerHapticFeedback()
    }
    
    // MARK: - Haptic Feedback
    
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Error creating haptic engine: \(error.localizedDescription)")
        }
    }
    
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.6)
    }
}

// MARK: - Extensions

extension Double {
    func roundedOriginal(to places: Double) -> Double {
        let divisor = 1.0 / places
        return (self * divisor).rounded() / divisor
    }
}

struct TargetWeightView_Original_Previews: PreviewProvider {
    static var previews: some View {
        TargetWeightView_Original(
            onContinue: {},
            onBack: {}
        )
        .environmentObject(NavigationCoordinator.shared)
    }
} 