import SwiftUI
import Foundation
import CoreHaptics

// Оптимизированная версия кнопки назад
struct BackButton: View {
    var action: (() -> Void)? = nil
    @State private var animateButton = false
    
    var body: some View {
        Button(action: {
            // Упрощенная обратная связь - одна вибрация
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            if let action = action {
                action()
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .scaleEffect(animateButton ? 1.0 : 0.1)
                    .opacity(animateButton ? 1.0 : 0)
                
                Image(systemName: "chevron.left")
                    .foregroundColor(.black)
                    .font(.system(size: 14, weight: .medium))
                    .opacity(animateButton ? 1.0 : 0)
                    .scaleEffect(animateButton ? 1.0 : 0.5)
            }
        }
        .onAppear {
            // Отложенная анимация для уменьшения нагрузки при переходе на экран
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    animateButton = true
                }
            }
        }
    }
}

struct GoalOption: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let goal: UserProfile.Goal
}

struct GoalSelectionView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var userProfile = UserProfile.shared
    @State private var animateItems = false
    @State private var selectedGoal: UserProfile.Goal? = nil // Changed to optional with nil default
    @State private var hapticEngine: CHHapticEngine?
    @State private var isNavigating = false
    @AppStorage("hasVisitedGoalScreen") private var hasVisitedGoalScreen = false
    
    var onContinue: () -> Void
    var onBack: () -> Void
    
    private let goalOptions: [GoalOption] = [
        GoalOption(title: "Lose weight", description: "Reduce calorie intake to lose weight gradually", goal: .loseWeight),
        GoalOption(title: "Maintain weight", description: "Maintain your current composition", goal: .maintainWeight),
        GoalOption(title: "Gain muscle", description: "Increase calorie intake to build muscle mass", goal: .gainMuscle)
    ]
    
    var body: some View {
        ZStack {
            // Фон экрана - светло-голубой
            Color(red: 0.91, green: 0.97, blue: 1.0).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Верхняя панель с кнопкой назад и индикатором прогресса
                HStack(spacing: 0) {
                    // Кнопка назад
                    Button(action: {
                        if isNavigating { return } // Защита от повторных нажатий
                        isNavigating = true
                        
                        // Сохраняем выбранную цель
                        saveData()
                        
                        // Анимация исчезновения контента перед переходом
                        withAnimation(.easeOut(duration: 0.15)) {
                            animateItems = false
                        }
                        
                        // Легкая вибрация
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        // Переход с задержкой для завершения анимации исчезновения
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
                    .disabled(isNavigating) // Блокируем кнопку во время перехода
                    
                    // Прогресс бар
                    ProgressBarView(currentStep: 4, totalSteps: 8)
                        .padding(.leading, 16)
                        .padding(.trailing, 20)
                        .opacity(animateItems ? 1.0 : 0)
                }
                .padding(.top, 16)
                
                // Заголовок и подзаголовок
                VStack(alignment: .center, spacing: 0) {
                    Text("What is your goal?")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 32)
                        .multilineTextAlignment(.center)
                    
                    Text("This will be used to create your individual plan")
                        .font(.system(size: 16))
                        .foregroundColor(.black.opacity(0.6))
                        .padding(.top, 8)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: animateItems)
                
                // Увеличиваем высоту Spacer для более низкого расположения опций
                Spacer()
                    .frame(height: 130)
                
                // Опции выбора цели - увеличенные и по центру экрана
                VStack(spacing: 16) {
                    ForEach(Array(goalOptions.enumerated()), id: \.element.id) { index, option in
                        Button(action: {
                            if selectedGoal != option.goal {
                                // Легкая вибрация только при изменении выбора
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred(intensity: 0.6)
                                
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selectedGoal = option.goal
                                }
                            }
                        }) {
                            VStack(alignment: .center, spacing: 6) {
                                Text(option.title)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(selectedGoal == option.goal ? .white : .black)
                                
                                Text(option.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(selectedGoal == option.goal ? .white.opacity(0.8) : .black.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .frame(height: 68)
                            .padding(.horizontal, 22)
                            .background(selectedGoal == option.goal ? Color.black : Color.white)
                            .cornerRadius(16)
                            .animation(.easeOut(duration: 0.2), value: selectedGoal)
                            .opacity(animateItems ? 1 : 0)
                            .offset(y: animateItems ? 0 : 40)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3 + Double(index) * 0.1), value: animateItems)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Кнопка Continue
                Button(action: {
                    if isNavigating || selectedGoal == nil { return } // Add nil check
                    isNavigating = true
                    
                    // Сохраняем выбранную цель
                    saveData()
                    
                    // Анимация исчезновения контента перед переходом
                    withAnimation(.easeOut(duration: 0.15)) {
                        animateItems = false
                    }
                    
                    // Средняя вибрация при переходе вперед
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    // Переход с задержкой для завершения анимации исчезновения
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        onContinue()
                    }
                }) {
                    Text("Continue")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedGoal == nil ? Color.gray.opacity(0.5) : Color.black) // Gray when no selection
                        .cornerRadius(28)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 30)
                .disabled(isNavigating || selectedGoal == nil) // Disable when no selection
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            isNavigating = false
            
            // Check if returning from a subsequent screen
            if hasVisitedGoalScreen {
                // Try to get previously saved goal
                if let savedGoalString = UserDefaults.standard.string(forKey: "selectedGoal") {
                    // Convert the string to a goal enum
                    if savedGoalString == "Lose Weight" {
                        selectedGoal = .loseWeight
                    } else if savedGoalString == "Maintain Weight" {
                        selectedGoal = .maintainWeight
                    } else if savedGoalString == "Gain Muscle" {
                        selectedGoal = .gainMuscle
                    }
                } else if navigationCoordinator.userProfile.goal != .maintainWeight {
                    // Use profile as fallback (maintainWeight is often default)
                    selectedGoal = navigationCoordinator.userProfile.goal
                }
            } else {
                // First visit - no default selection
                selectedGoal = nil
            }
            
            // Анимация появления контента
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    animateItems = true
                }
            }
        }
    }
    
    private func saveData() {
        if let goal = selectedGoal {
            navigationCoordinator.userProfile.goal = goal
            
            // Also update fitnessGoal to match the goal for consistency
            switch goal {
            case .loseWeight:
                navigationCoordinator.userProfile.fitnessGoal = .loseWeight
            case .maintainWeight:
                navigationCoordinator.userProfile.fitnessGoal = .maintain
            case .gainMuscle:
                navigationCoordinator.userProfile.fitnessGoal = .gainMuscle
            }
            
            // Save to UserDefaults for persistence
            UserDefaults.standard.set(goal.rawValue, forKey: "selectedGoal")
            hasVisitedGoalScreen = true
        }
    }
    
    // Простая вибрация для выбора цели и нажатия кнопки назад
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.6)
    }
}

struct GoalSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GoalSelectionView(
                onContinue: {},
                onBack: {}
            )
                .environmentObject(NavigationCoordinator.shared)
        }
    }
} 