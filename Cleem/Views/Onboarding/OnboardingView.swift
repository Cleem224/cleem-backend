import SwiftUI
// Import our custom weight ruler views
import CoreHaptics
// Import HeightWeightSelectionView
import Foundation
// Basic imports
import Combine

// Remove problematic imports
// import GoogleSignInView - there's no such module

struct OnboardingView: View {
    @ObservedObject var navigationCoordinator = NavigationCoordinator.shared
    @ObservedObject var userProfile = NavigationCoordinator.shared.userProfile
    @State private var currentStep = 0
    
    // Переменные для анимации прогресса
    @State private var progressValue: Double = 0.0
    @State private var dotsCount: Int = 0
    @State private var caloriesChecked: Bool = false
    @State private var proteinChecked: Bool = false
    @State private var carbsChecked: Bool = false
    @State private var fatsChecked: Bool = false
    
    // Таймеры
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    let dotsTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    // Генератор тактильной обратной связи
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    // Onboarding steps
    let steps = [
        "Welcome",
        "Gender",
        "Date of Birth",
        "Height & Weight",
        "Fitness Goal",
        "Target Weight",
        "Activity Level",
        "Diet Selection",
        "Appreciation",
        "Plan Build",
        "Summary"
    ]
    
    @State private var glowAmount: CGFloat = 0
    @State private var pulsate = false
    @State private var showTagline = false
    @State private var showButton = false
    
    // Шаги онбординга
    let onboardingSteps = ["Welcome", "Gender", "Date of Birth", "Weight", "Height", "Weight Goal", "Diet", "Summary"]
    
    // Добавим состояние для показа экрана аутентификации
    @State private var showGoogleSignIn = false
    
    // Метод для завершения онбординга
    func onComplete() {
        userProfile.updateProfile()
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        // Вместо непосредственного перехода к главному экрану,
        // показываем экран Google Sign-In
        showGoogleSignIn = true
    }
    
    // Метод для завершения онбординга и перехода к главному экрану
    func completeOnboarding() {
        NavigationCoordinator.shared.isOnboarding = false
        NavigationCoordinator.shared.activeScreen = nil
        NotificationCenter.default.post(name: .navigateToHomeScreen, object: nil)
    }
    
    // Метод для завершения после Google Sign-In
    func completeAfterGoogleSignIn() {
        // Закрываем экран Google Sign-In
        showGoogleSignIn = false
        // Переходим к главному экрану
        completeOnboarding()
    }
    
    var body: some View {
        ZStack {
            // Фоновый цвет
            Color(red: 0.91, green: 0.97, blue: 1.0)
                .edgesIgnoringSafeArea(.all)
            
            // Основной контент зависит от шага
            VStack {
                // Индикатор прогресса
                HStack(spacing: 4) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 40)
                
                // Контент текущего шага
                ZStack {
                    if currentStep == 0 {
                        welcomeContent()
                            .opacity(currentStep == 0 ? 1 : 0)
                    } else if currentStep == 1 {
                        genderContent()
                            .opacity(currentStep == 1 ? 1 : 0)
                    } else if currentStep == 2 {
                        dateOfBirthContent()
                            .opacity(currentStep == 2 ? 1 : 0)
                    } else if currentStep == 3 {
                        heightWeightContent()
                            .opacity(currentStep == 3 ? 1 : 0)
                    } else if currentStep == 4 {
                        fitnessGoalContent()
                            .opacity(currentStep == 4 ? 1 : 0)
                    } else if currentStep == 5 {
                        targetWeightContent()
                            .opacity(currentStep == 5 ? 1 : 0)
                    } else if currentStep == 6 {
                        activityLevelContent()
                            .opacity(currentStep == 6 ? 1 : 0)
                    } else if currentStep == 7 {
                        dietSelectionContent()
                            .opacity(currentStep == 7 ? 1 : 0)
                    } else if currentStep == 8 {
                        appreciationContent()
                            .opacity(currentStep == 8 ? 1 : 0)
                    } else if currentStep == 9 {
                        planBuildContent()
                            .opacity(currentStep == 9 ? 1 : 0)
                    } else if currentStep == 10 {
                        summaryContent()
                            .opacity(currentStep == 10 ? 1 : 0)
                    } else {
                        Text("Unknown step")
                            .opacity(currentStep > 10 ? 1 : 0)
                    }
                }
                .animation(.easeInOut, value: currentStep)
            }
            
            // Экран загрузки персонализированного плана
            if showLoadingScreen() {
                loadingScreenView()
                    .animation(.easeInOut, value: showLoadingScreen())
            }
        }
        .onAppear {
            // Инициализируем генератор вибрации
            feedbackGenerator.prepare()
            // Всегда начинаем с первого экрана
            currentStep = 0
        }
        .fullScreenCover(isPresented: $showGoogleSignIn) {
            // Показываем экран входа через Google после завершения онбординга
            NavigationView {
                GoogleSignInBridgeView(onComplete: completeOnboarding)
            }
        }
    }
    
    // Проверка нужно ли показывать экран загрузки
    func showLoadingScreen() -> Bool {
        return currentStep == 11 // Теперь экран загрузки показывается после экрана Summary
    }
    
    // Перейти к определенному шагу
    func goToStep(_ step: Int) {
        if step >= 0 && step < onboardingSteps.count {
            currentStep = step
        }
    }
    
    // Следующий шаг
    func nextStep() {
        if currentStep < steps.count - 1 {
            withAnimation {
                currentStep += 1
            }
        }
    }
    
    // Предыдущий шаг
    func previousStep() {
        if currentStep > 0 {
            withAnimation {
                currentStep -= 1
            }
        }
    }
    
    // Запуск экрана расчета рекомендаций
    func loadRecommendations() {
        // Сначала увеличиваем индекс текущего шага
        currentStep = 10 // Переходим к экрану Summary
        
        // Запускаем полный расчет всех параметров
        let _ = navigationCoordinator.userProfile.calculateDailyTargets()
    }
    
    // MARK: - Onboarding Step Views
    
    // 0. Приветственный экран
    func welcomeContent() -> AnyView {
        return AnyView(
            WelcomeView(onContinue: nextStep)
        )
    }
    
    // 1. Выбор пола
    func genderContent() -> AnyView {
        return AnyView(
            GenderSelectionView(onContinue: nextStep, onBack: previousStep)
        )
    }
    
    // 2. Ввод даты рождения
    func dateOfBirthContent() -> AnyView {
        return AnyView(
            VStack(spacing: 24) {
                // Заголовок
                VStack(spacing: 8) {
                    Text("Date of birth")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("This will be used to create your individual plan")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Выбор даты рождения
                DatePicker(
                    "Select date",
                    selection: Binding<Date>(
                        get: { 
                            userProfile.dateOfBirth ?? Date().addingTimeInterval(-20 * 365 * 24 * 60 * 60) // ~20 лет
                        },
                        set: { 
                            userProfile.dateOfBirth = $0
                            userProfile.age = Calendar.current.dateComponents([.year], from: $0, to: Date()).year ?? 20
                        }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                
                Spacer()
                
                // Индикаторы прогресса
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle()
                            .fill(i <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding()
                
                // Кнопка продолжить
                Button(action: {
                    nextStep() // Переход к экрану роста и веса
                }) {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .padding()
            .background(Color(red: 0.91, green: 0.97, blue: 1.0).edgesIgnoringSafeArea(.all))
            .overlay(
                VStack {
                    HStack {
                        Button(action: {
                            previousStep() // Возврат к экрану выбора пола
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.leading, 16)
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                }
            )
        )
    }
    
    // 3. Ввод роста и веса (комбинированный экран)
    func heightWeightContent() -> AnyView {
        return AnyView(
            HeightWeightSelectionView(
                onContinue: { 
                    // При нажатии на Continue используем инкремент шага в OnboardingView
                    nextStep()
                },
                onBack: { 
                    // При нажатии на Back используем декремент шага в OnboardingView
                    previousStep()
                }
            )
            .environmentObject(navigationCoordinator)
        )
    }
    
    // 4. Выбор цели тренировок
    func fitnessGoalContent() -> AnyView {
        return AnyView(
            GoalSelectionView(
                onContinue: nextStep,
                onBack: previousStep
            )
            .environmentObject(navigationCoordinator)
        )
    }
    
    // 5. Целевой вес
    func targetWeightContent() -> AnyView {
        return AnyView(
            TargetWeightView(
                onContinue: {
                    // Proceed to the next step
                    self.nextStep()
                },
                onBack: {
                    // Go back to the previous step
                    self.previousStep()
                }
            )
            .environmentObject(navigationCoordinator)
        )
    }
    
    // 6. Уровень активности
    private func activityLevelContent() -> AnyView {
        AnyView(
            ActivityLevelView(
                userProfile: navigationCoordinator.userProfile,
                onContinue: {
                    // Update user profile and proceed to next step
                    self.nextStep()
                },
                onBack: {
                    self.previousStep()
                }
            )
            .environmentObject(navigationCoordinator)
        )
    }
    
    // 7. Выбор типа диеты
    private func dietSelectionContent() -> AnyView {
        AnyView(
            DietSelectionView(
                onContinue: {
                    // Теперь переходим на экран благодарности вместо следующего шага
                    currentStep = 8
                },
                onBack: {
                    self.previousStep()
                }
            )
            .environmentObject(navigationCoordinator)
        )
    }
    
    // 8. Экран благодарности
    private func appreciationContent() -> AnyView {
        AnyView(
            AppreciationView(
                onContinue: {
                    // После экрана благодарности переходим к экрану загрузки
                    loadRecommendations()
                },
                onBack: {
                    // Возврат к экрану выбора диеты
                    currentStep = 7
                }
            )
            .environmentObject(navigationCoordinator)
        )
    }
    
    // 9. Экран планирования плана
    private func planBuildContent() -> AnyView {
        AnyView(
            PlanBuildView(
                onContinue: {
                    // После экрана Build Plan переходим к загрузке рекомендаций
                    loadRecommendations()
                },
                onBack: {
                    // Возврат к экрану благодарности
                    currentStep = 8
                }
            )
            .environmentObject(navigationCoordinator)
        )
    }
    
    // 10. Итоговый экран
    func summaryContent() -> AnyView {
        return AnyView(
            ProfileSummaryView(
                onComplete: { 
                    completeOnboarding()
                },
                onBackToDietSelection: {
                    currentStep = 7
                }
            ).environmentObject(navigationCoordinator)
        )
    }
    
    // Экран загрузки персонализированного плана
    func loadingScreenView() -> some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Main title
            Text("Building recommendations\nbased on the data provided")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            
            // Progress ring
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white, lineWidth: 10)
                    .frame(width: 150, height: 150)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(progressValue))
                    .stroke(Color.black, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progressValue)
                
                // Percentage text
                Text("\(Int(progressValue * 100))%")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.black)
            }
            
            // Loading text with dots - анимируются только точки
            HStack(spacing: 0) {
                Text("Personalizing health plan")
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                
                Text(String(repeating: ".", count: dotsCount))
                    .font(.system(size: 16))
                    .foregroundColor(.black)
            }
            
            // Recommendations box - сразу видимый
            VStack(spacing: 20) {
                Text("Recommendation for")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.black)
                        Text("Calories")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black) 
                            .opacity(caloriesChecked ? 1 : 0)
                    }
                    
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.black)
                        Text("Protein")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .opacity(proteinChecked ? 1 : 0)
                    }
                    
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.black)
                        Text("Carbs")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .opacity(carbsChecked ? 1 : 0)
                    }
                    
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.black)
                        Text("Fats")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .opacity(fatsChecked ? 1 : 0)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(20)
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .onReceive(timer) { _ in
            // Update progress value over 6 seconds
            if progressValue < 1.0 {
                progressValue += 0.0033 // Approximately 6 seconds to reach 1.0
                
                // Show checkmarks at specific intervals
                if progressValue >= 0.25 && !caloriesChecked {
                    withAnimation {
                        caloriesChecked = true
                    }
                    feedbackGenerator.prepare()
                    feedbackGenerator.impactOccurred()
                }
                
                if progressValue >= 0.5 && !proteinChecked {
                    withAnimation {
                        proteinChecked = true
                    }
                    feedbackGenerator.prepare()
                    feedbackGenerator.impactOccurred()
                }
                
                if progressValue >= 0.75 && !carbsChecked {
                    withAnimation {
                        carbsChecked = true
                    }
                    feedbackGenerator.prepare()
                    feedbackGenerator.impactOccurred()
                }
                
                if progressValue >= 0.95 && !fatsChecked {
                    withAnimation {
                        fatsChecked = true
                    }
                    feedbackGenerator.prepare()
                    feedbackGenerator.impactOccurred()
                }
                
                // Complete onboarding when progress reaches 100%
                if progressValue >= 1.0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onComplete()
                    }
                }
            }
        }
        .onReceive(dotsTimer) { _ in
            // Animate the dots in "Personalizing health plan..."
            withAnimation {
                dotsCount = (dotsCount + 1) % 4
            }
        }
    }
}

// Карточка элемента питательного вещества с круговым прогрессом
struct OnboardingSummaryCard: View {
    let value: Int
    let label: String
    let color: Color
    var isMeasuredInGrams: Bool = false
    
    var body: some View {
        HStack(spacing: 15) {
            // Круг прогресса с центрированным значением
            ZStack {
                // Фоновый круг
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 75, height: 75)
                
                // Круг прогресса (заполнен на три четверти)
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 75, height: 75)
                    .rotationEffect(.degrees(-90))
                
                // Текст значения
                Text(isMeasuredInGrams ? "\(value)g" : "\(value)")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
            }
            
            // Название питательного вещества
            Text(label)
                .font(.system(size: 24))
                .foregroundColor(.black)
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color(white: 0.9))
        .cornerRadius(10)
    }
}
