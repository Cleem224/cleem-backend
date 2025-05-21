import SwiftUI
import CoreHaptics
import UIKit
import Combine
// импортируем константы уведомлений
// Здесь нет необходимости импортировать отдельно, так как расширение Notification.Name 
// доступно глобально

struct ProfileSummaryView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var isLoading = false
    @State private var progressValue: Double = 0.0
    @State private var navigateToHome = false
    @Environment(\.presentationMode) var presentationMode
    @State private var engine: CHHapticEngine?
    
    // Local state variables
    @State private var dailyCalories: Int = 0
    @State private var proteinInGrams: Int = 0
    @State private var carbsInGrams: Int = 0
    @State private var fatsInGrams: Int = 0
    
    // Анимируемые значения для плавного обновления
    @State private var animatedCalories: Int = 0
    @State private var animatedProtein: Int = 0
    @State private var animatedCarbs: Int = 0
    @State private var animatedFats: Int = 0
    
    // Состояния для показа модальных окон редактирования
    @State private var showCaloriesEditView = false
    @State private var showProteinEditView = false
    @State private var showCarbsEditView = false
    @State private var showFatsEditView = false
    
    // Флаги для отслеживания изменений и запуска анимаций
    @State private var calValuesChanged = false
    @State private var proValuesChanged = false
    @State private var carbsValuesChanged = false
    @State private var fatsValuesChanged = false
    
    // Используем единый подход к анимации и защита от множественных нажатий
    @State private var animateItems = false
    @State private var isNavigating = false // Защита от множественных нажатий
    
    // Callback functions
    var onComplete: (() -> Void)?
    var onBackToDietSelection: (() -> Void)?
    
    // Добавляем подписку на уведомления - переделано в @State property для решения проблемы иммутабельности
    @State private var notificationSubscriptions = Set<AnyCancellable>()
    
    init(onComplete: (() -> Void)? = nil, onBackToDietSelection: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.onBackToDietSelection = onBackToDietSelection
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.91, green: 0.97, blue: 1.0).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Top bar with back button and progress indicator - фиксируем вверху
                HStack(spacing: 0) {
                    // Back button
                    Button(action: {
                        if isNavigating { return } // Предотвращаем повторные нажатия
                        isNavigating = true
                        
                        // Анимация исчезновения элементов для более гладкого перехода
                        withAnimation(.easeOut(duration: 0.15)) {
                            animateItems = false
                        }
                        
                        // Короткая вибрация без предварительной подготовки
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        // Небольшая задержка перед переходом для завершения анимации исчезновения
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onBackToDietSelection?()
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
                    
                    // Progress indicator
                    ProgressBarView(currentStep: 8, totalSteps: 8)
                        .padding(.leading, 16)
                        .padding(.trailing, 20)
                        .opacity(animateItems ? 1.0 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: animateItems)
                }
                .padding(.top, 16)
                .padding(.bottom, 10)
                .background(Color(red: 0.91, green: 0.97, blue: 1.0))
                .zIndex(1) // Убедимся, что верхний бар всегда поверх скроллинга
                
                // Главная область контента с фиксированной кнопкой внизу
                ZStack(alignment: .bottom) {
                    // ScrollView контент
                    ScrollView(showsIndicators: true) {
                        VStack(spacing: 0) {
                            // Header text
                            VStack(spacing: 4) {
                                Text("Well done!")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                                
                                Text("Your individual plan is ready")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    
                                // Добавляем расчет и отображение веса и даты достижения цели
                                VStack(spacing: 4) {
                                    // Показываем текст в зависимости от цели
                                    Text(navigationCoordinator.userProfile.goal == .gainMuscle ? 
                                         "You should gain:" : 
                                         "You should lose:")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.black)
                                        .multilineTextAlignment(.center)
                                        .padding(.top, 8)
                                    
                                    // Контейнер для показа веса и даты
                                    ZStack {
                                        Capsule()
                                            .fill(Color.white)
                                            .frame(height: 50)
                                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                                        
                                        // Получаем вес и дату
                                        if let (weightDiff, targetDate) = calculateWeightGoalInfo() {
                                            // Получаем компоненты даты напрямую из календаря
                                            let calendar = Calendar.current
                                            let month = calendar.component(.month, from: targetDate) 
                                            let day = calendar.component(.day, from: targetDate)
                                            
                                            // Названия месяцев вручную
                                            let monthNames = ["january", "february", "march", "april", "may", "june", 
                                                              "july", "august", "september", "october", "november", "december"]
                                            let monthName = monthNames[month - 1] // массивы индексируются с 0
                                            
                                            // Создаем итоговую строку
                                            let weightString = "\(Int(weightDiff)) kg by \(monthName) \(day)"
                                            Text(weightString)
                                                .font(.system(size: 20, weight: .medium))
                                                .foregroundColor(.black)
                                        }
                                    }
                                    .padding(.horizontal, 40)
                                    .padding(.bottom, 5)
                                }
                            }
                            .padding(.top, 5)
                            .padding(.horizontal, 20)
                            .opacity(animateItems ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.3), value: animateItems)
                            
                            // Nutrition cards с более компактным размещением
                            VStack(spacing: 16) {
                                // Calories
                                ZStack {
                                    // Карточка как фон кнопки
                                    NutritionCard(value: "\(animatedCalories)", 
                                                 label: "Calories", 
                                                 progress: calcProgress(value: animatedCalories, forType: .calories), 
                                                 color: .black,
                                                 delay: 0.0,
                                                 animate: calValuesChanged)
                                    
                                    // Прозрачная кнопка поверх карточки
                                    Button(action: {
                                        if isNavigating { return }
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred(intensity: 0.5)
                                        animatedCalories = dailyCalories
                                        showCaloriesEditView = true
                                    }) {
                                        Rectangle()
                                            .fill(Color.clear)
                                            .contentShape(Rectangle())
                                    }
                                }
                                .frame(height: 80) // Уменьшаем высоту карточки
                                .opacity(animateItems ? 1 : 0)
                                .animation(.easeOut(duration: 0.5).delay(0.5), value: animateItems)
                                .buttonStyle(ScaleButtonStyle())
                                .sheet(isPresented: $showCaloriesEditView) {
                                    NutritionParameterEditView(
                                        parameterType: .calories,
                                        value: $dailyCalories
                                    )
                                    .environmentObject(navigationCoordinator)
                                }
                                
                                // Protein
                                ZStack {
                                    NutritionCard(value: "\(animatedProtein)g", 
                                                 label: "Protein", 
                                                 progress: calcProgress(value: animatedProtein, forType: .protein), 
                                                 color: Color.red,
                                                 delay: 0.1,
                                                 animate: proValuesChanged)
                                    
                                    Button(action: {
                                        if isNavigating { return }
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred(intensity: 0.5)
                                        animatedProtein = proteinInGrams
                                        showProteinEditView = true
                                    }) {
                                        Rectangle()
                                            .fill(Color.clear)
                                            .contentShape(Rectangle())
                                    }
                                }
                                .frame(height: 80) // Уменьшаем высоту карточки
                                .opacity(animateItems ? 1 : 0)
                                .animation(.easeOut(duration: 0.5).delay(0.6), value: animateItems)
                                .buttonStyle(ScaleButtonStyle())
                                .sheet(isPresented: $showProteinEditView) {
                                    NutritionParameterEditView(
                                        parameterType: .protein,
                                        value: $proteinInGrams
                                    )
                                    .environmentObject(navigationCoordinator)
                                }
                                
                                // Carbs
                                ZStack {
                                    NutritionCard(value: "\(animatedCarbs)g", 
                                                 label: "Carbs", 
                                                 progress: calcProgress(value: animatedCarbs, forType: .carbs), 
                                                 color: Color.blue,
                                                 delay: 0.2,
                                                 animate: carbsValuesChanged)
                                    
                                    Button(action: {
                                        if isNavigating { return }
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred(intensity: 0.5)
                                        animatedCarbs = carbsInGrams
                                        showCarbsEditView = true
                                    }) {
                                        Rectangle()
                                            .fill(Color.clear)
                                            .contentShape(Rectangle())
                                    }
                                }
                                .frame(height: 80) // Уменьшаем высоту карточки
                                .opacity(animateItems ? 1 : 0)
                                .animation(.easeOut(duration: 0.5).delay(0.7), value: animateItems)
                                .buttonStyle(ScaleButtonStyle())
                                .sheet(isPresented: $showCarbsEditView) {
                                    NutritionParameterEditView(
                                        parameterType: .carbs,
                                        value: $carbsInGrams
                                    )
                                    .environmentObject(navigationCoordinator)
                                }
                                
                                // Fats
                                ZStack {
                                    NutritionCard(value: "\(animatedFats)g", 
                                                 label: "Fats", 
                                                 progress: calcProgress(value: animatedFats, forType: .fats), 
                                                 color: Color.orange,
                                                 delay: 0.3,
                                                 animate: fatsValuesChanged)
                                    
                                    Button(action: {
                                        if isNavigating { return }
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred(intensity: 0.5)
                                        animatedFats = fatsInGrams
                                        showFatsEditView = true
                                    }) {
                                        Rectangle()
                                            .fill(Color.clear)
                                            .contentShape(Rectangle())
                                    }
                                }
                                .frame(height: 80) // Уменьшаем высоту карточки
                                .opacity(animateItems ? 1 : 0)
                                .animation(.easeOut(duration: 0.5).delay(0.8), value: animateItems)
                                .buttonStyle(ScaleButtonStyle())
                                .sheet(isPresented: $showFatsEditView) {
                                    NutritionParameterEditView(
                                        parameterType: .fats,
                                        value: $fatsInGrams
                                    )
                                    .environmentObject(navigationCoordinator)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8) // Уменьшаем отступ сверху еще больше
                            
                            // Информация об источниках внизу
                            VStack(spacing: 6) {
                                Text("Created with input from the sources below and other validated medical studies:")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.black.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 12)
                                    .padding(.bottom, 4)
                                    .padding(.horizontal, 20)
                                
                                // Список источников
                                VStack(alignment: .leading, spacing: 6) {
                                    SourceItem(text: "USDA (U.S Departament of Agriculture)", url: URL(string: "https://www.usda.gov"))
                                    SourceItem(text: "EFSA (European Food Safety Authority)", url: URL(string: "https://www.efsa.europa.eu/en"))
                                    SourceItem(text: "WHO (World Health Organization)", url: URL(string: "https://www.who.int"))
                                }
                                .padding(.horizontal, 30)
                                .padding(.bottom, 100) // Отступ снизу для кнопки Continue
                            }
                            .opacity(animateItems ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.9), value: animateItems)
                        }
                        .padding(.bottom, 0)
                    }
                    
                    // Фиксированная кнопка Continue внизу
                    VStack {
                        Button(action: {
                            if isNavigating { return }
                            isNavigating = true
                            
                            withAnimation(.easeOut(duration: 0.15)) {
                                animateItems = false
                            }
                            
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                completeOnboarding()
                            }
                        }) {
                            Text("Continue")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(
                                    Capsule()
                                        .fill(Color.black)
                                )
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    }
                    .background(Color(red: 0.91, green: 0.97, blue: 1.0))
                    .opacity(animateItems ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.8), value: animateItems)
                    .disabled(isNavigating)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showCaloriesEditView) {
            NutritionParameterEditView(
                parameterType: .calories,
                value: $dailyCalories
            )
            .environmentObject(navigationCoordinator)
        }
        .sheet(isPresented: $showProteinEditView) {
            NutritionParameterEditView(
                parameterType: .protein,
                value: $proteinInGrams
            )
            .environmentObject(navigationCoordinator)
        }
        .sheet(isPresented: $showCarbsEditView) {
            NutritionParameterEditView(
                parameterType: .carbs,
                value: $carbsInGrams
            )
            .environmentObject(navigationCoordinator)
        }
        .sheet(isPresented: $showFatsEditView) {
            NutritionParameterEditView(
                parameterType: .fats,
                value: $fatsInGrams
            )
            .environmentObject(navigationCoordinator)
        }
        .onAppear {
            isNavigating = false
            loadProfileData()
            prepareHaptics()
            
            // Подписываемся на уведомления об обновлении значений питания
            NotificationCenter.default.publisher(for: .nutritionValuesUpdated)
                .sink { notification in
                    // Обновляем значения из профиля пользователя
                    self.loadProfileData()
                    
                    // Анимируем изменение всех значений
                    self.animateAllNutritionValues()
                }
                .store(in: &self.notificationSubscriptions)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.3)) {
                    animateItems = true
                }
            }
        }
        .onDisappear {
            // Отменяем подписки на уведомления
            self.notificationSubscriptions.removeAll()
        }
    }
    
    // Method to load data from user profile
    private func loadProfileData() {
        // Update metrics
        let userProfile = navigationCoordinator.userProfile
        
        // Не пересчитываем значения, чтобы не перезаписать изменения
        // userProfile.calculateDailyTargets()
        
        // Save values to local State variables
        dailyCalories = Int(userProfile.dailyCalories)
        proteinInGrams = Int(userProfile.proteinInGrams)
        carbsInGrams = Int(userProfile.carbsInGrams)
        fatsInGrams = Int(userProfile.fatsInGrams)
        
        // Если это первая загрузка, инициализируем анимируемые значения
        if animatedCalories == 0 {
            animatedCalories = dailyCalories
            animatedProtein = proteinInGrams
            animatedCarbs = carbsInGrams
            animatedFats = fatsInGrams
        }
        
        // Выводим в консоль для отладки
        print("Loaded profile data: calories=\(dailyCalories), protein=\(proteinInGrams)g, carbs=\(carbsInGrams)g, fats=\(fatsInGrams)g")
    }
    
    // Method to update user profile with current nutrition values
    private func updateUserProfile() {
        // Обновляем значения в профиле пользователя
        navigationCoordinator.userProfile.dailyCalories = Double(dailyCalories)
        navigationCoordinator.userProfile.proteinInGrams = Double(proteinInGrams)
        navigationCoordinator.userProfile.carbsInGrams = Double(carbsInGrams)
        navigationCoordinator.userProfile.fatsInGrams = Double(fatsInGrams)
        
        // Сохраняем обновления в профиль
        navigationCoordinator.userProfile.updateProfile()
    }
    
    // Method to complete onboarding
    func completeOnboarding() {
        // Упрощенная вибрация успеха
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Обновляем профиль последними значениями перед завершением
        updateUserProfile()
        
        // Save user profile
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // Complete onboarding and navigate to main screen
        navigationCoordinator.isOnboarding = false
        
        // Call callback function if provided
        onComplete?()
    }
    
    // Method to prepare haptic feedback
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptic engine error: \(error.localizedDescription)")
        }
    }
    
    // Методы для анимированного изменения значений
    private func animateCaloriesChange() {
        // Проверяем, изменилось ли значение
        if animatedCalories != dailyCalories {
            calValuesChanged = true
            
            // Анимируем изменение значений
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedCalories = dailyCalories
            }
            
            // Сбрасываем флаг после задержки
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                calValuesChanged = false
            }
        }
    }
    
    private func animateProteinChange() {
        // Проверяем, изменилось ли значение
        if animatedProtein != proteinInGrams {
            proValuesChanged = true
            
            // Анимируем изменение значений
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedProtein = proteinInGrams
            }
            
            // Сбрасываем флаг после задержки
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                proValuesChanged = false
            }
        }
    }
    
    private func animateCarbsChange() {
        // Проверяем, изменилось ли значение
        if animatedCarbs != carbsInGrams {
            carbsValuesChanged = true
            
            // Анимируем изменение значений
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedCarbs = carbsInGrams
            }
            
            // Сбрасываем флаг после задержки
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                carbsValuesChanged = false
            }
        }
    }
    
    private func animateFatsChange() {
        // Проверяем, изменилось ли значение
        if animatedFats != fatsInGrams {
            fatsValuesChanged = true
            
            // Анимируем изменение значений
            withAnimation(.easeInOut(duration: 0.8)) {
                animatedFats = fatsInGrams
            }
            
            // Сбрасываем флаг после задержки
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                fatsValuesChanged = false
            }
        }
    }
    
    // Метод для одновременной анимации всех значений питания
    private func animateAllNutritionValues() {
        // Устанавливаем флаги изменения для всех значений
        self.calValuesChanged = true
        self.proValuesChanged = true
        self.carbsValuesChanged = true
        self.fatsValuesChanged = true
        
        // Анимируем изменение всех значений
        withAnimation(.easeInOut(duration: 0.8)) {
            self.animatedCalories = self.dailyCalories
            self.animatedProtein = self.proteinInGrams
            self.animatedCarbs = self.carbsInGrams
            self.animatedFats = self.fatsInGrams
        }
        
        // Сбрасываем флаги после задержки
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.calValuesChanged = false
            self.proValuesChanged = false
            self.carbsValuesChanged = false
            self.fatsValuesChanged = false
        }
    }
    
    // Функция для расчета прогресса для различных типов питания
    private func calcProgress(value: Int, forType type: NutritionParameterType) -> CGFloat {
        switch type {
        case .calories:
            // Прогресс для калорий (500-4000)
            let minValue: CGFloat = 500
            let maxValue: CGFloat = 4000
            let range = maxValue - minValue
            let normalizedValue = CGFloat(value) - minValue
            let progress = Swift.max(0, Swift.min(normalizedValue / range, 1))
            return 0.1 + 0.9 * progress
        case .protein:
            // Прогресс для белка (20-300)
            let minValue: CGFloat = 20
            let maxValue: CGFloat = 300
            let range = maxValue - minValue
            let normalizedValue = CGFloat(value) - minValue
            let progress = Swift.max(0, Swift.min(normalizedValue / range, 1))
            return 0.1 + 0.9 * progress
        case .carbs:
            // Прогресс для углеводов (20-500)
            let minValue: CGFloat = 20
            let maxValue: CGFloat = 500
            let range = maxValue - minValue
            let normalizedValue = CGFloat(value) - minValue
            let progress = Swift.max(0, Swift.min(normalizedValue / range, 1))
            return 0.1 + 0.9 * progress
        case .fats:
            // Прогресс для жиров (10-200)
            let minValue: CGFloat = 10
            let maxValue: CGFloat = 200
            let range = maxValue - minValue
            let normalizedValue = CGFloat(value) - minValue
            let progress = Swift.max(0, Swift.min(normalizedValue / range, 1))
            return 0.1 + 0.9 * progress
        }
    }
    
    // Новый метод для расчета веса и даты достижения цели
    private func calculateWeightGoalInfo() -> (Double, Date)? {
        let userProfile = navigationCoordinator.userProfile
        
        // Проверяем, что у нас есть все необходимые данные
        guard userProfile.weightInKg > 0, userProfile.targetWeightInKg > 0 else {
            return nil
        }
        
        // Разница в весе (всегда берем абсолютное значение)
        let weightDifference = abs(userProfile.targetWeightInKg - userProfile.weightInKg)
        
        // Если разница незначительная, считаем что цель уже достигнута
        if weightDifference < 0.5 {
            return (0, Date())
        }
        
        // Определяем скорость изменения веса
        // Безопасная скорость потери веса: ~0.5 кг в неделю
        // Безопасная скорость набора веса: ~0.25 кг в неделю
        let weeklyRateKg = userProfile.goal == .gainMuscle ? 0.25 : 0.5
        
        // Расчет количества недель
        let numberOfWeeks = weightDifference / weeklyRateKg
        
        // Рассчитываем дату достижения цели
        let targetDate = Calendar.current.date(byAdding: .day, 
                                               value: Int(ceil(numberOfWeeks * 7)), 
                                               to: Date()) ?? Date()
        
        return (weightDifference, targetDate)
    }
    
    // При необходимости можно оставить этот метод для использования в других местах
    private func calculateTimeToReachGoalWeight() -> String? {
        let userProfile = navigationCoordinator.userProfile
        
        // Проверяем, что у нас есть все необходимые данные
        guard userProfile.weightInKg > 0, userProfile.targetWeightInKg > 0 else {
            return nil
        }
        
        // Разница в весе (может быть положительной или отрицательной)
        let weightDifference = userProfile.targetWeightInKg - userProfile.weightInKg
        
        // Если разница незначительная, считаем что цель уже достигнута
        if abs(weightDifference) < 0.5 {
            return "You already reached your goal weight!"
        }
        
        // Определяем цель на основе разницы в весе
        let isWeightLoss = weightDifference < 0
        
        // Определяем рекомендуемую скорость изменения веса
        // Безопасная скорость потери веса: ~0.5 кг в неделю
        // Безопасная скорость набора веса: ~0.25 кг в неделю
        let weeklyRateKg = isWeightLoss ? 0.5 : 0.25
        
        // Расчет количества недель
        let numberOfWeeks = abs(weightDifference) / weeklyRateKg
        
        // Округляем до целого числа недель
        let roundedWeeks = ceil(numberOfWeeks)
        
        // Конвертируем в месяцы и недели всегда
        let months = Int(roundedWeeks / 4)
        let remainingWeeks = Int(roundedWeeks.truncatingRemainder(dividingBy: 4))
        
        // Форматируем в виде "Estimated time to reach your goal: X months and Y weeks"
        var resultText = "Estimated time to reach your goal: "
        
        if months > 0 {
            let monthText = months == 1 ? "month" : "months"
            resultText += "\(months) \(monthText)"
            
            if remainingWeeks > 0 {
                resultText += " and "
            }
        }
        
        if remainingWeeks > 0 || months == 0 {
            let weekText = remainingWeeks == 1 ? "week" : "weeks"
            resultText += "\(remainingWeeks) \(weekText)"
        }
        
        return resultText
    }
}

// Nutrition card component 
struct NutritionCard: View {
    let value: String
    let label: String
    let progress: CGFloat
    let color: Color
    let delay: Double // Добавлен параметр задержки
    var animate: Bool = false // Параметр для активации анимации изменения
    
    // Состояние для анимации прогресса
    @State private var animateProgress: CGFloat = 0
    @State private var showCheckmark: Bool = false
    @State private var isAnimating: Bool = false // Для отслеживания анимации
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
            
            HStack(spacing: 20) {
                // Progress circle with value
                ZStack {
                    // Белый круглый контейнер с легкой тенью
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                    // Background circle
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 64, height: 64)
                    
                    // Progress arc с анимацией
                    Circle()
                        .trim(from: 0, to: animateProgress)
                        .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .foregroundColor(color)
                        .frame(width: 64, height: 64)
                        .rotationEffect(Angle(degrees: -90))
                    
                    // Value text с анимацией
                    Text(value)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        // Добавляем эффект масштабирования при изменении значения
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                }
                .padding(.leading, 16)
                
                // Label with improved style
                Text(label)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black)
                
                Spacer()
                
                // Edit icon вместо галочки для обозначения возможности редактирования
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray.opacity(0.7))
                    .padding(.trailing, 20)
                    .opacity(showCheckmark ? 1 : 0)
                    .scaleEffect(showCheckmark ? 1 : 0.5)
            }
        }
        .frame(height: 90)
        .padding(.horizontal, 4)
        .onAppear {
            // Сначала устанавливаем 0, затем анимируем до целевого значения
            // Анимация прогресса начинается с учетом переданной задержки
            animateProgress = 0
            withAnimation(.easeOut(duration: 1.0).delay(0.3 + delay)) {
                animateProgress = progress
            }
            
            // Показываем иконку редактирования после завершения анимации прогресса
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4 + delay) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showCheckmark = true
                }
            }
        }
        .onChange(of: animate) { isAnimating in
            if isAnimating {
                // Активируем анимацию изменения значения
                activateChangeAnimation()
            }
        }
        .onChange(of: progress) { newProgress in
            // Анимируем изменение прогресса при изменении значения
            if showCheckmark { // Анимируем только если начальная анимация уже завершилась
                withAnimation(.easeInOut(duration: 0.8)) {
                    animateProgress = newProgress
                }
            } else {
                animateProgress = newProgress // Просто устанавливаем, если еще не было начальной анимации
            }
        }
    }
    
    // Функция для активации анимации изменения значений
    private func activateChangeAnimation() {
        // Запускаем эффект масштабирования значения
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isAnimating = true
        }
        
        // Возвращаем нормальный размер через небольшую задержку
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isAnimating = false
            }
        }
    }
}

// Стиль кнопки с анимацией нажатия
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Компонент для отображения элемента списка источников
struct SourceItem: View {
    let text: String
    var url: URL? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
            
            if let url = url {
                Link(destination: url) {
                    Text(text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                        .fixedSize(horizontal: false, vertical: true)
                        .underline()
                }
            } else {
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ProfileSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSummaryView()
            .environmentObject(NavigationCoordinator.shared)
    }
} 