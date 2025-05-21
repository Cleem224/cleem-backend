import SwiftUI
import UIKit
import Combine
import HealthKit

// Class to handle mutable state for HomeView
class HomeViewState: ObservableObject {
    @Published var navigationCoordinator: NavigationCoordinator
    @Published var healthManager: HealthKitManager
    @Published var refreshID = UUID()
    
    init(navigationCoordinator: NavigationCoordinator, healthManager: HealthKitManager) {
        self.navigationCoordinator = navigationCoordinator
        self.healthManager = healthManager
    }
    
    func updateWithTemporaryData(profile: UserProfile, manager: HealthKitManager) {
        // Store original references
        let originalProfile = self.navigationCoordinator.userProfile
        let originalManager = self.healthManager
        
        // Update with temporary data
        self.navigationCoordinator.userProfile = profile
        self.healthManager = manager
        self.refreshID = UUID()
        
        // Schedule restoring original data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.navigationCoordinator.userProfile = originalProfile
            self.healthManager = originalManager
            self.refreshID = UUID()
        }
    }
}

// Обработчик для событий жизненного цикла приложения
class AppLifecycleHandler {
    static let shared = AppLifecycleHandler()
    
    // Замыкание, которое будет вызвано при переходе приложения в фоновый режим
    var onBackground: (() -> Void)?
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        // Подписываемся на уведомления о переходе приложения в фоновый режим
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Подписываемся на уведомления о закрытии приложения
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        print("Приложение перешло в фоновый режим, сохраняем данные")
        onBackground?()
    }
    
    @objc private func appWillTerminate() {
        print("Приложение закрывается, сохраняем данные")
        onBackground?()
    }
}

// Add a struct to make training data Identifiable for ForEach
struct TrainingHistoryItem: Identifiable, Hashable {
    let id = UUID()
    let activityId: String  // Уникальный идентификатор из базы данных
    let activity: String
    let calories: Double
    let duration: Int
    let timeString: String
    
    // Required for Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TrainingHistoryItem, rhs: TrainingHistoryItem) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Create from dictionary
    static func from(dictionary: [String: Any]) -> TrainingHistoryItem? {
        guard let activity = dictionary["activity"] as? String,
              let calories = dictionary["calories"] as? Double,
              let duration = dictionary["duration"] as? Int,
              let timeString = dictionary["time"] as? String else {
            return nil
        }
        
        // Получаем идентификатор, если он есть, или генерируем новый
        let activityId = dictionary["id"] as? String ?? UUID().uuidString
        
        return TrainingHistoryItem(
            activityId: activityId,
            activity: activity,
            calories: calories,
            duration: duration,
            timeString: timeString
        )
    }
}

struct HomeView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @StateObject private var viewState: HomeViewState = HomeViewState(
        navigationCoordinator: NavigationCoordinator.shared,
        healthManager: HealthKitManager.shared
    )
    @State private var selectedDate = Date()
    @State private var currentWeekStartDate = Date()
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var animateTransition = false
    @State private var currentPage = 0
    @State private var animateProgress = false
    @State private var isShowingQuickActions = false
    @State private var isShowingNutrientsModal = false
    @State private var isShowingFullCalendar = false
    @State private var isShowingQuickMenu = false
    
    // Флаг для отслеживания вывода логов по датам
    private static var hasLoggedCurrentWeek = false
    
    // Target values for nutrients - we'll use bindings to these in the modal
    @State private var calorieGoal = 1100
    @State private var proteinGoal = 130
    @State private var carbsGoal = 200
    @State private var fatGoal = 65
    
    // Для обработки уведомлений об обновлении значений
    @State private var notificationSubscriptions = Set<AnyCancellable>()
    
    // Дата последнего обновления для отслеживания смены дня
    @AppStorage("lastUpdateDate") private var lastUpdateDateString: String = ""
    
    // Для ограничения частоты обновлений
    @State private var lastHealthKitCheckTime: Date = Date(timeIntervalSince1970: 0)
    private let minHealthKitCheckInterval: TimeInterval = 60
    
    // Ключ для хранения кэша данных в UserDefaults
    private let dailyDataCacheKey = "com.cleem.dailyDataCache"
    
    // Словарь для хранения данных по дням
    @State private var dailyDataCache: [String: DailyData] = [:]
    
    // Структура для хранения данных по дням
    struct DailyData: Codable {
        var consumedCalories: Double = 0
        var consumedProtein: Double = 0
        var consumedCarbs: Double = 0
        var consumedFat: Double = 0
        var caloriesBurned: Double = 0
        var steps: Int = 0
        var waterIntake: Int = 0
    }
    
    // Создаем константный массив с днями недели на английском, правильного порядка
    private let weekDaysEN = ["S", "M", "T", "W", "T", "F", "S"] // Воскресенье, Понедельник и т.д.
    
    // Вычисляем правильные буквы дней недели для отображения на основе сгенерированных дат
    private var weekDaysForDisplay: [String] {
        var days: [String] = []
        
        for date in currentWeekDates {
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: date) - 1 // 0-6, где 0 - воскресенье
            days.append(weekDaysEN[weekday])
        }
        
        return days
    }
    
    // Add this property for water settings
    @ObservedObject private var waterSettings = WaterSettings.shared
    @State private var isShowingWaterSettings = false
    
    // Состояния для анимации кнопок воды
    @State private var isMinusPressed = false
    @State private var isPlusPressed = false
    
    // Add this property for HealthKitManager
    @ObservedObject private var healthManager = HealthKitManager.shared
    
    // Computed properties
    private var currentWeekDates: [Date] {
        generateDatesForWeek(startingFrom: currentWeekStartDate)
    }
    
    private var formattedMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentWeekStartDate)
    }
    
    // Helper functions and bindings that use navigationCoordinator or healthManager
    private var userCalorieTarget: Int {
        viewState.navigationCoordinator.userProfile.dailyCalorieTarget
    }
    
    private var caloriesLeft: Int {
        // Возвращаем только целевые калории без вычитания сожженных
        return viewState.navigationCoordinator.userProfile.dailyCalorieTarget
    }
    
    // Calculate percentages for progress circles
    private var caloriePercentage: Double {
        // Получаем значения для расчета
        let consumedCalories = viewState.navigationCoordinator.userProfile.consumedCalories
        let targetCalories = Double(viewState.navigationCoordinator.userProfile.dailyCalorieTarget)
        
        // Для отладки
        print("Расчет прогресса: потреблено=\(consumedCalories), цель=\(targetCalories)")
        
        if targetCalories > 0 {
            // Рассчитываем прогресс только на основе потребленных калорий
            // НЕ учитываем сожженные калории для индикатора
            let progress = consumedCalories / targetCalories
            
            // Ограничиваем прогресс от минимального значения 0.03 (3%) до 1.0 (100%)
            let result = animateProgress ? min(max(progress, 0.03), 1.0) : 0.03
            print("Итоговый прогресс для индикатора калорий: \(result)")
            return result
        } else {
            return 0.03 // Минимальное значение для отображения базовой линии
        }
    }
    
    private var proteinTarget: Int {
        viewState.navigationCoordinator.userProfile.proteinGramsTarget
    }
    
    private var carbsTarget: Int {
        viewState.navigationCoordinator.userProfile.carbsGramsTarget
    }
    
    private var fatTarget: Int {
        viewState.navigationCoordinator.userProfile.fatGramsTarget
    }
    
    // Demo values to match reference image
    private var proteinLeft: Int {
        // Используем значение из профиля пользователя
        return viewState.navigationCoordinator.userProfile.proteinGramsTarget
    }
    
    private var carbsLeft: Int {
        // Используем значение из профиля пользователя
        return viewState.navigationCoordinator.userProfile.carbsGramsTarget
    }
    
    private var fatLeft: Int {
        // Используем значение из профиля пользователя
        return viewState.navigationCoordinator.userProfile.fatGramsTarget
    }
    
    private var proteinPercentage: Double {
        // Используем прогресс на основе фактически потребленного белка
        let consumedProtein = viewState.navigationCoordinator.userProfile.consumedProtein
        let targetProtein = Double(viewState.navigationCoordinator.userProfile.proteinGramsTarget)
        
        if targetProtein > 0 {
            return animateProgress ? min(consumedProtein / targetProtein, 1.0) : 0
        } else {
            return 0
        }
    }
    
    private var carbsPercentage: Double {
        // Используем прогресс на основе фактически потребленных углеводов
        let consumedCarbs = viewState.navigationCoordinator.userProfile.consumedCarbs
        let targetCarbs = Double(viewState.navigationCoordinator.userProfile.carbsGramsTarget)
        
        if targetCarbs > 0 {
            return animateProgress ? min(consumedCarbs / targetCarbs, 1.0) : 0
        } else {
            return 0
        }
    }
    
    private var fatPercentage: Double {
        // Используем прогресс на основе фактически потребленных жиров
        let consumedFat = viewState.navigationCoordinator.userProfile.consumedFat
        let targetFat = Double(viewState.navigationCoordinator.userProfile.fatGramsTarget)
        
        if targetFat > 0 {
            return animateProgress ? min(consumedFat / targetFat, 1.0) : 0
        } else {
            return 0
        }
    }
    
    // Dictionary to store swipe offsets for each item
    @State private var swipeOffsets: [UUID: CGFloat] = [:]
    
    var body: some View {
        ZStack {
            // Main background - white
            Color.white
                .edgesIgnoringSafeArea(.all)
            
            // Implement a GeometryReader to create a scrolling effect that overlaps with the header
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    // Main background - white (moved inside ZStack)
                    Color.white
                        .edgesIgnoringSafeArea(.all)
                        .zIndex(0)
                    
                    // Content scroll area - position below everything else
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 15) {
                            // Spacer to position content at the bottom of the blue panel
                            Spacer()
                                .frame(height: 110) // Adjusted for blue panel's bottom edge
                            
                            // Calendar card
                            calendarCard
                                .padding(.horizontal, 20)
                            
                            // Nutrition card with circular indicators
                            nutritionCard
                                .padding(.horizontal, 20)
                                .padding(.top, 5)
                            
                            // Pagination dots
                            paginationDots
                                .padding(.top, 5)
                            
                            // "Recently logged" section
                            recentlyLoggedSection
                                .padding(.top, 10)
                        }
                        .padding(.bottom, 120) // Extra padding for tab bar
                    }
                    .zIndex(1)
                    
                    // Top blue panel with Cleem logo - stays on top
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color(red: 0, green: 0.27, blue: 0.24))
                            .frame(height: 180)
                            .padding(.top, -70)
                            .cornerRadius(25, corners: [.bottomLeft, .bottomRight])
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                                    .cornerRadius(25, corners: [.bottomLeft, .bottomRight])
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                            .edgesIgnoringSafeArea(.top)
                        
                        Spacer()
                    }
                    .zIndex(2)
                    
                    // Logo in its own layer - stays on top of everything
                    VStack {
                        HStack {
                            Image("Cleem2")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                                .padding(.leading, 30)
                                .padding(.top, 30)
                            
                            Spacer()
                        }
                        
                        Spacer()
                    }
                    .zIndex(3)
                    
                    // Add floating button at the bottom
                    VStack {
                        Spacer()
                        
                        Button(action: {
                            // Add haptic feedback - simple tap
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            
                            // Вместо показа старого меню, показываем новое
                            isShowingQuickMenu = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 55, height: 55)
                                .background(Color(red: 0.89, green: 0.19, blue: 0.18))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.bottom, 85) // Увеличил с 55 до 85 для поднятия кнопки выше
                    .padding(.horizontal, 0) // Убираем горизонтальный отступ для центровки
                    .frame(maxWidth: .infinity, alignment: .center) // Выравниваем по центру, как иконка Cleem
                    .zIndex(4)
                }
            }
            .edgesIgnoringSafeArea(.top)
            
            // Показываем меню быстрых действий поверх всего при надобности
            if isShowingQuickMenu {
                // Затемненный фон, действующий как кнопка закрытия
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        isShowingQuickMenu = false
                    }
                    .zIndex(6)
                
                // Само меню (внизу экрана)
                VStack {
                    Spacer()
                    QuickMenuPopup(isPresented: $isShowingQuickMenu)
                        .environmentObject(viewState.navigationCoordinator)
                        .padding(.bottom, 100) // Отступ от нижней части экрана
                }
                .zIndex(7)
            }
        }
        .onAppear {
            // Загружаем кэш данных из UserDefaults
            loadDailyDataCache()
            
            // Загружаем актуальные значения из UserProfile
            loadNutritionGoalsFromUserProfile()
            
            // Проверяем необходимость сброса значений потребления
            checkAndResetConsumption()
            
            // Подписываемся на уведомления об изменении питательных веществ
            setupNotificationHandlers()
            
            // Загружаем данные для выбранной даты (если она не сегодня)
            if !Calendar.current.isDateInToday(selectedDate) {
                loadDataForSelectedDate()
            }
            
            // Animate circular indicators on appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    animateProgress = true
                }
            }
            
            // Fetch health data when the view appears
            if !viewState.healthManager.isAuthorized {
                // Check if authorization can be requested or already exists
                checkHealthKitAuthorization()
            } else {
                // If already authorized, refresh data
                viewState.healthManager.startFetchingHealthData()
            }
            
            // Подписываемся на уведомления о временном обновлении данных
            // Правильный способ добавления обработчика без использования .store
            let publisher = NotificationCenter.default.publisher(for: .init("HomeViewTemporaryDataUpdate"))
            publisher
                .sink { notification in
                    if let userInfo = notification.userInfo,
                       let tempProfile = userInfo["profile"] as? UserProfile,
                       let tempHealthManager = userInfo["healthManager"] as? HealthKitManager {
                        
                        // Обновляем данные используя метод ViewState
                        viewState.updateWithTemporaryData(profile: tempProfile, manager: tempHealthManager)
                    }
                }
                .store(in: &notificationSubscriptions)
                
            // Устанавливаем обработчик для сохранения данных при переходе приложения в фоновый режим
            AppLifecycleHandler.shared.onBackground = {
                // Сохраняем текущие данные перед выходом из приложения
                print("Сохраняем данные из HomeView при уходе приложения в фон")
                saveDataForCurrentDate()
            }
        }
        .onDisappear {
            // Сохраняем данные при исчезновении экрана
            saveDataForCurrentDate()
            
            // Очищаем подписки на уведомления
            notificationSubscriptions.removeAll()
        }
        // Оставляем старый sheet для обратной совместимости
        .sheet(isPresented: $isShowingQuickActions) {
            QuickActionsView()
                .environmentObject(viewState.navigationCoordinator)
        }
        // Sheet for nutrients modal
        .sheet(isPresented: $isShowingNutrientsModal) {
            NutrientsModalView(
                calorieGoal: $calorieGoal,
                proteinGoal: $proteinGoal,
                carbsGoal: $carbsGoal,
                fatGoal: $fatGoal,
                isPresented: $isShowingNutrientsModal,
                onSave: updateUserProfileWithNewValues
            )
            .presentationDetents([.fraction(0.7)])
            .presentationDragIndicator(.visible)
        }
        // Sheet для отображения полного календаря
        .sheet(isPresented: $isShowingFullCalendar) {
            FullCalendarView(selectedDate: $selectedDate, currentMonthDate: $currentWeekStartDate)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingWaterSettings) {
            WaterSettingsView(isPresented: $isShowingWaterSettings)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        // Добавляем sheet для трекера тренировок
        .sheet(isPresented: $viewState.navigationCoordinator.showTrainingMonitorView) {
            NavigationView {
                TrainingMonitorView(isPresented: $viewState.navigationCoordinator.showTrainingMonitorView)
                    .environmentObject(viewState.navigationCoordinator)
                    .environmentObject(viewState.healthManager)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            // Сначала сохраняем текущие данные
            saveDataForCurrentDate()
            
            // Затем загружаем данные для новой выбранной даты и обновляем UI
            withAnimation(.easeInOut) {
                loadDataForSelectedDate()
            }
        }
        .onChange(of: currentPage) { oldValue, newValue in
            print("Page changed to: \(newValue)")
            // Force UI refresh when page changes
            viewState.refreshID = UUID()
        }
    }
    
    // MARK: - UI Components
    
    // Function to switch between TabView pages
    private func switchToPage(_ page: Int) {
        withAnimation {
            currentPage = page
        }
        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        print("Manually switched to page: \(page)")
    }
    
    // Calendar card
    private var calendarCard: some View {
        VStack(spacing: 6) {
            HStack {
                Button(action: {
                    // Показать полный календарь для выбора даты
                    isShowingFullCalendar = true
                    
                    // Добавляем тактильный отклик
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    Text(formattedMonthYear)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(Color(red: 0, green: 0.27, blue: 0.24)) // Цвет как у кнопки Today
                        .cornerRadius(8)
                }
                
                Spacer()
                
                Button(action: {
                    resetToCurrentWeek()
                    // Add haptic feedback when pressing Today
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    Text("Today")
                        .foregroundColor(.white)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(red: 0, green: 0.27, blue: 0.24))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 15)
            .padding(.top, 10)
            
            // Calendar week view with wider selection
            calendarWeekView
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            isDragging = true
                            dragOffset = gesture.translation.width
                        }
                        .onEnded { gesture in
                            isDragging = false
                            
                            if gesture.translation.width < -50 {
                                moveToNextWeek()
                            } else if gesture.translation.width > 50 {
                                moveToPreviousWeek()
                            }
                            
                            dragOffset = 0
                        }
                )
        }
        .background(Color(UIColor.systemGray4)) // Возвращаем исходный цвет
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
        )
    }
    
    // Функция для проверки, является ли дата будущей
    private func isFutureDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let compareDate = calendar.startOfDay(for: date)
        return compareDate > today
    }
    
    // Week calendar component
    private var calendarWeekView: some View {
        HStack(spacing: 0) {
            ForEach(0..<7) { index in
                let date = currentWeekDates[index]
                let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                let day = Calendar.current.component(.day, from: date)
                let isFuture = isFutureDate(date)
                
                VStack(spacing: 6) {
                    // Day letter (S, M, T, etc.)
                    Text(weekDaysForDisplay[index])
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(
                            isFuture ? Color.gray.opacity(0.5) :
                            isSelected ? .white : .black
                        )
                    
                    // Day number
                    Text("\(day)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(
                            isFuture ? Color.gray.opacity(0.5) :
                            isSelected ? .white : .black
                        )
                }
                .frame(width: 42, height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(isSelected ? Color(red: 0.89, green: 0.19, blue: 0.18) : Color.clear)
                        .opacity(isFuture ? 0.3 : 1.0)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    // Проверяем, не является ли дата будущей
                    if !isFuture {
                        // Убираем анимацию при выборе дня
                        selectedDate = date
                        
                        // Add haptic feedback when selecting a day
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } else {
                        // Используем одиночную вибрацию вместо паттерна ошибки
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 10)
    }
    
    // Nutrition card with progress indicators
    private var nutritionCard: some View {
        // TabView for swipeable pages
        TabView(selection: $currentPage) {
            // Page 1: Nutrition info (existing)
            nutritionInfoPage
                .tag(0)
            
            // Page 2: Activity and water tracking
            activityAndWaterPage
                .tag(1)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // Hide built-in indicators
        .animation(.easeInOut, value: currentPage)
        .frame(height: 280)
        .background(Color(UIColor.systemGray4))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
        )
    }
    
    // Pagination dots indicator - this will be used in the main content area
    private var paginationDots: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(currentPage == 0 ? Color.black : Color.gray.opacity(0.5))
                .frame(width: 8, height: 8)
                .onTapGesture {
                    switchToPage(0)
                }
            
            Circle()
                .fill(currentPage == 1 ? Color.black : Color.gray.opacity(0.5))
                .frame(width: 8, height: 8)
                .onTapGesture {
                    switchToPage(1)
                }
        }
    }
    
    // Page 1: Nutrition info (existing content from nutritionCard)
    private var nutritionInfoPage: some View {
        VStack(spacing: 15) {
            // Main calorie information
            HStack(alignment: .center) {
                // Centered layout for calorie information
                Spacer() // Push content to center
                
                // Main calorie indicator
                ZStack {
                    // White background circle
                    Circle()
                        .stroke(lineWidth: 5)
                        .foregroundColor(.white)
                    
                    // Минимальный индикатор (базовая линия 0%)
                    Circle()
                        .trim(from: 0.0, to: 0.03) // Очень маленький сегмент для обозначения 0%
                        .stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                        .foregroundColor(.black)
                        .rotationEffect(Angle(degrees: 270.0))
                    
                    // Black progress circle
                    Circle()
                        .trim(from: 0.0, to: caloriePercentage)
                        .stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                        .foregroundColor(.black)
                        .rotationEffect(Angle(degrees: 270.0))
                        .animation(.spring(response: 1.0, dampingFraction: 0.6), value: caloriePercentage)
                    
                    // Black square with white flame icon
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "flame.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 70, height: 70)
                
                // Calorie count - показываем оставшиеся калории с учетом сожженных
                VStack(alignment: .center) { // Center align the text
                    Text("\(caloriesLeft)")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.black)
                        .id("calories-\(caloriesLeft)-\(viewState.refreshID)") // Для принудительного обновления
                        .transition(.scale.combined(with: .opacity)) // Добавляем переход для анимации
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: caloriesLeft)
                    
                    Text("Calories left")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                }
                .padding(.leading, 15)
                
                Spacer() // Push content to center
            }
            .padding(.top, 8)
            
            // Daily goal slider
            VStack(alignment: .leading, spacing: 6) {
                Text("Daily goal")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(height: 6)
                        .foregroundColor(Color.gray.opacity(0.15))
                        .cornerRadius(3)
                    
                    // Progress indicator - показываем фактический прогресс потребления
                    Rectangle()
                        .frame(width: max(8, UIScreen.main.bounds.width * 0.8 * CGFloat(caloriePercentage)), height: 6)
                        .foregroundColor(.black)
                        .cornerRadius(3)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: caloriePercentage)
                }
            }
            .padding(.horizontal, 20)
            
            // Macro nutrients (Protein, Carbs, Fat)
            HStack(spacing: 0) {
                // Protein
                nutrientCircle(
                    letter: "P",
                    color: .red.opacity(0.8),
                    value: proteinTarget,
                    unit: "g",
                    label: "Protein left",
                    progress: proteinPercentage
                )
                
                // Carbs
                nutrientCircle(
                    letter: "C",
                    color: .blue.opacity(0.7),
                    value: carbsTarget,
                    unit: "g",
                    label: "Carbs left",
                    progress: carbsPercentage
                )
                
                // Fat
                nutrientCircle(
                    letter: "F",
                    color: .orange.opacity(0.8),
                    value: fatTarget,
                    unit: "g",
                    label: "Fat left",
                    progress: fatPercentage
                )
            }
            .padding(.bottom, 12)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle()) // Make entire view tappable
        .onTapGesture {
            // First dismiss keyboard if it's showing
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                          to: nil,
                                          from: nil,
                                          for: nil)
            
            // Show the nutrients modal with haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Загружаем актуальные значения перед открытием модального окна
            loadNutritionGoalsFromUserProfile()
            
            isShowingNutrientsModal = true
        }
    }
    
    // New page for activity and water tracking
    private var activityAndWaterPage: some View {
        VStack(spacing: 10) {
            if !viewState.healthManager.isAuthorized {
                // Not connected - show full Connect+ panel with heart
                StepsPanel()
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .id("steps-panel-\(viewState.healthManager.isAuthorized)-\(viewState.refreshID)")
            } else {
                // Connected - show health metrics with 3 panels
                HStack(spacing: 12) {
                    // Calories burned section
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.black)
                            
                            Text("\(Int(viewState.healthManager.caloriesBurned))")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.black)
                                .id("burned-calories-\(Int(viewState.healthManager.caloriesBurned))-\(viewState.refreshID)")
                        }
                        
                        Text("Calories burned")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                            .padding(.bottom, 4)
                        
                        // Activity list with ScrollView
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 6) {
                                // Step icon in gray circle
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 32, height: 32)
                                        
                                        Image(systemName: "figure.walk")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 14, height: 14)
                                            .foregroundColor(.black)
                                    }
                                    
                                    Text("Steps")
                                        .font(.system(size: 14))
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                    
                                    // Используем расчет калорий от шагов из HealthKitManager
                                    Text("+\(Int(viewState.healthManager.stepsCalories))")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.black)
                                        .id("steps-calories-\(Int(viewState.healthManager.stepsCalories))-\(viewState.refreshID)")
                                }
                                .padding(.vertical, 2)
                                
                                // Получаем историю тренировок (новые уже сверху)
                                if let trainingsHistory = UserDefaults.standard.array(forKey: "trainingsHistory") as? [[String: Any]], !trainingsHistory.isEmpty {
                                    // Create mini training items for the small panel (just need activity and calories)
                                    let miniTrainingItems = trainingsHistory.prefix(5).compactMap { dict -> (id: UUID, activityId: String, activity: String, calories: Double)? in
                                        guard let activity = dict["activity"] as? String,
                                              let calories = dict["calories"] as? Double else {
                                            return nil
                                        }
                                        // Получаем идентификатор активности из словаря или генерируем новый
                                        let activityId = dict["id"] as? String ?? UUID().uuidString
                                        return (UUID(), activityId, activity, calories)
                                    }
                                    
                                    ForEach(miniTrainingItems, id: \.id) { item in
                                        HStack {
                                            // Run icon in gray circle
                                            ZStack {
                                                Circle()
                                                    .fill(Color.gray.opacity(0.2))
                                                    .frame(width: 32, height: 32)
                                                
                                                Image(systemName: item.activity == "Run" ? "figure.run" : (item.activity == "Strength training" ? "dumbbell.fill" : "flame.fill"))
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 14, height: 14)
                                                    .foregroundColor(.black)
                                            }
                                            
                                            Text(item.activity)
                                                .font(.system(size: item.activity == "Strength training" ? 12 : (item.activity == "Manual" ? 13 : 14)))
                                                .foregroundColor(.black)
                                            
                                            Spacer()
                                            
                                            Text("+\(Int(item.calories))")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.black)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                } else {
                                    // Show empty state when no training history exists
                                    VStack(spacing: 8) { // Уменьшаем spacing с 15 до 8
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 26)) // Уменьшаем размер с 30 до 26
                                            .foregroundColor(.gray.opacity(0.5))
                                        
                                        
                                        Text("No food and training activities for this date")
                                            .font(.system(size: 14, weight: .medium)) // Уменьшаем шрифт с 16 до 14
                                            .foregroundColor(.gray)
                                        
                                        if Calendar.current.isDateInToday(selectedDate) {
                                            Text("Add your first food and activities by tapping the + button")
                                                .font(.system(size: 12)) // Уменьшаем шрифт с 14 до 12
                                                .foregroundColor(.gray.opacity(0.8))
                                                .multilineTextAlignment(.center)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20) // Уменьшаем отступ с 40 до 20
                                    .padding(.horizontal, 15) // Уменьшаем горизонтальный отступ
                                }
                            }
                        }
                        .frame(height: 100) // Максимальная высота для скрола
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(14)
                    .frame(width: UIScreen.main.bounds.width * 0.36) // Slightly smaller
                    
                    // Steps panel - connected view
                    StepsPanel()
                        .frame(width: UIScreen.main.bounds.width * 0.5)
                        .id("steps-panel-\(viewState.healthManager.isAuthorized)-\(viewState.refreshID)")
                }
                .padding(.horizontal, 10)
                .padding(.top, 5) // Уменьшаем отступ сверху на 3 пункта для приближения водной панели к шагам
                
                // Water tracking section - only show when connected
                waterTrackingPanel
            }
        }
        .padding(.vertical, 5)
        .animation(.easeInOut(duration: 0.3), value: viewState.healthManager.isAuthorized)
        .onAppear {
            print("ActivityAndWaterPage appeared, HealthKit authorized: \(viewState.healthManager.isAuthorized)")
            
            // Только обновляем UI, не делая дополнительных проверок
            viewState.refreshID = UUID()
            
            // Запускаем загрузку данных, если авторизованы (безопасно, так как внутри есть проверка на одноразовость)
            if viewState.healthManager.isAuthorized {
                viewState.healthManager.startFetchingHealthData()
            }
        }
    }
    
    // Separate water tracking panel
    private var waterTrackingPanel: some View {
        HStack(spacing: 15) {
            // Water glass icon
            Image("Water")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .padding(.leading, 5)
            
            // Water text
            VStack(alignment: .leading, spacing: 2) {
                Text("Water")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                
                Text("\(waterSettings.totalWaterIntake) ml")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
            }
            
            Spacer()
            
            // Minus button
            Button(action: {
                // Decrease water amount
                waterSettings.removeWater()
                
                // Анимировать кнопку
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isMinusPressed = true
                }
                
                // Вернуть в нормальный размер через короткое время
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isMinusPressed = false
                    }
                }
                
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
                    .frame(width: 36, height: 36)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Circle())
                    .scaleEffect(isMinusPressed ? 1.2 : 1.0)
            }
            .padding(.trailing, 2)
            
            // Plus button
            Button(action: {
                // Increase water amount
                waterSettings.addWater()
                
                // Анимировать кнопку
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isPlusPressed = true
                }
                
                // Вернуть в нормальный размер через короткое время
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPlusPressed = false
                    }
                }
                
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
                    .frame(width: 36, height: 36)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Circle())
                    .scaleEffect(isPlusPressed ? 1.2 : 1.0)
            }
            .padding(.trailing, 5)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10) // Уменьшаем отступ с 12 до 10 для более компактного отображения
        .background(Color.white)
        .cornerRadius(14)
        .padding(.horizontal, 12)
        .padding(.top, -2) // Уменьшаем отступ сверху, чтобы поднять панель выше
        .onTapGesture {
            // Show water settings when tapping the panel (not the buttons)
            isShowingWaterSettings = true
            
            // Add stronger haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.prepare()
            impactFeedback.impactOccurred(intensity: 1.0)
        }
    }
    
    // "Recently logged" section
    private var recentlyLoggedSection: some View {
        RecentlyLoggedView(
            hasLoggedFood: viewState.navigationCoordinator.recentlyScannedFood != nil,
            isScanning: viewState.navigationCoordinator.isFoodScanning,
            isAnalyzing: viewState.navigationCoordinator.isFoodAnalyzing,
            analyzedFood: viewState.navigationCoordinator.recentlyScannedFood
        )
    }
    
    // Activity panel component
    private struct ActivityPanel: View {
        let item: TrainingHistoryItem
        
        var body: some View {
            HStack(spacing: 0) {
                // Activity icon in white circle
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 42, height: 42)
                    
                    Image(systemName: item.activity == "Run" ? "figure.run" : (item.activity == "Strength training" ? "dumbbell.fill" : "flame.fill"))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 15)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.activity)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    HStack(spacing: 8) {
                        // Flame icon for calories
                        Image(systemName: "flame.fill")
                            .foregroundColor(.black)
                            .font(.system(size: 12))
                        
                        Text("\(Int(item.calories)) calories")
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                    }
                    
                    HStack(spacing: 8) {
                        // Clock icon for duration
                        Image(systemName: "clock")
                            .foregroundColor(.black)
                            .font(.system(size: 12))
                        
                        Text("\(item.duration) mins")
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                    }
                }
                .padding(.leading, 5)
                
                Spacer()
                
                Text(item.timeString)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.trailing, 15)
            }
            .padding(.vertical, 12)
        }
    }
    
    // Function to delete an activity
    private func deleteActivity(item: TrainingHistoryItem) {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Используем новый метод удаления по идентификатору
        viewState.healthManager.deleteActivityById(activityId: item.activityId)
        
        // Force UI refresh
        viewState.refreshID = UUID()
    }
    
    // Helper function for nutrient circles
    private func nutrientCircle(letter: String, color: Color, value: Int, unit: String, label: String, progress: Double) -> some View {
        VStack(spacing: 5) {
            // Circular progress with square indicator
            ZStack {
                // White background circle
                Circle()
                    .stroke(lineWidth: 5)
                    .foregroundColor(.white)
                
                // Минимальный индикатор (базовая линия 0%)
                Circle()
                    .trim(from: 0.0, to: 0.03) // Очень маленький сегмент для обозначения 0%
                    .stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    .foregroundColor(getCircleColor(for: letter))
                    .rotationEffect(Angle(degrees: 270.0))
                
                // Colored progress circle
                Circle()
                    .trim(from: 0.0, to: progress)
                    .stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    .foregroundColor(getCircleColor(for: letter))
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.spring(response: 1.0, dampingFraction: 0.6), value: progress)
                
                // Square with letter indicator - smaller size
                RoundedRectangle(cornerRadius: 4)
                    .fill(getCircleColor(for: letter))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text(letter)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 50, height: 50)
            .scaleEffect(animateProgress ? 1.0 : 0.9)
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: animateProgress)
            
            // Value and label
            Text("\(value)\(unit)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .id("\(letter)-\(value)-\(viewState.refreshID)") // Force redraw when value or refreshID changes
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: value)
            
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
    
    // Helper function to get the correct color for each nutrient
    private func getCircleColor(for letter: String) -> Color {
        switch letter {
        case "P":
            return Color(red: 0.89, green: 0.19, blue: 0.18) // E4312F - red for protein
        case "C":
            return Color(red: 0.29, green: 0.51, blue: 0.96) // 4A82F5 - blue for carbs
        case "F":
            return Color(red: 0.94, green: 0.61, blue: 0.31) // F09C4F - orange for fat
        default:
            return Color.gray
        }
    }
    
    // MARK: - Helper Functions
    
    // Calendar management functions
    func generateDatesForWeek(startingFrom: Date) -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        
        // Находим начало недели (воскресенье) для заданной даты
        let startOfWeekComponents = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: startingFrom)
        guard var startOfWeek = calendar.date(from: startOfWeekComponents) else {
            return []
        }
        
        // Определим день недели для startOfWeek (1-воскресенье, 2-понедельник, и т.д.)
        let weekday = calendar.component(.weekday, from: startOfWeek)
        
        // Если это не воскресенье, вычитаем дни до предыдущего воскресенья
        if weekday != 1 {
            let daysToSubtract = (weekday - 1) % 7
            startOfWeek = calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfWeek) ?? startOfWeek
        }
        
        // Теперь генерируем 7 дней, начиная с воскресенья
        for day in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: day, to: startOfWeek) {
                dates.append(date)
            }
        }
        
        // Используем флаг из структуры для контроля вывода логов
        if !HomeView.hasLoggedCurrentWeek {
            print("Даты на неделе:")
            for (index, date) in dates.enumerated() {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, d MMMM"
                let weekdayNum = calendar.component(.weekday, from: date)
                print("День \(index): \(formatter.string(from: date)), день недели: \(weekdayNum)")
            }
            // Отмечаем, что логи уже были выведены
            HomeView.hasLoggedCurrentWeek = true
        }
        
        return dates
    }
    
    func moveToNextWeek() {
        // Сохраняем данные для текущей даты перед переключением
        saveDataForCurrentDate()
        
        // Убираем анимацию для мгновенного перехода
        animateTransition = false
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentWeekStartDate) {
            currentWeekStartDate = newDate
            
            // Сбрасываем флаг логов при смене недели
            HomeView.hasLoggedCurrentWeek = false
            
            // Проверяем, чтобы selectedDate не был будущим
            let possibleSelectedDate = currentWeekDates.first!
            if !isFutureDate(possibleSelectedDate) {
                selectedDate = possibleSelectedDate
                loadDataForSelectedDate()
            }
        }
    }
    
    func moveToPreviousWeek() {
        // Сохраняем данные для текущей даты перед переключением
        saveDataForCurrentDate()
        
        // Убираем анимацию для мгновенного перехода
        animateTransition = false
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentWeekStartDate) {
            currentWeekStartDate = newDate
            
            // Сбрасываем флаг логов при смене недели
            HomeView.hasLoggedCurrentWeek = false
            
            // Выбираем первый день новой недели
            selectedDate = currentWeekDates.first!
            loadDataForSelectedDate()
        }
    }
    
    func resetToCurrentWeek() {
        // Сохраняем данные для текущей даты перед переключением
        saveDataForCurrentDate()
        
        // Убираем анимацию для мгновенного перехода
        animateTransition = false
        currentWeekStartDate = Date()
        selectedDate = Date()
        
        // Сбрасываем флаг логов при сбросе недели
        HomeView.hasLoggedCurrentWeek = false
        
        // Загружаем данные для новой даты (сегодня)
        loadDataForSelectedDate()
    }
    
    // MARK: - Helper Functions for Nutrition Values
    
    // Загрузка значений из UserProfile
    private func loadNutritionGoalsFromUserProfile() {
        let oldCalorieGoal = calorieGoal
        let oldProteinGoal = proteinGoal
        let oldCarbsGoal = carbsGoal
        let oldFatGoal = fatGoal
        
        calorieGoal = navigationCoordinator.userProfile.dailyCalorieTarget
        proteinGoal = navigationCoordinator.userProfile.proteinGramsTarget
        carbsGoal = navigationCoordinator.userProfile.carbsGramsTarget
        fatGoal = navigationCoordinator.userProfile.fatGramsTarget
        
        // Показываем изменения значений для отладки
        if oldCalorieGoal != calorieGoal || oldProteinGoal != proteinGoal ||
           oldCarbsGoal != carbsGoal || oldFatGoal != fatGoal {
            print("Значения изменились: calories: \(oldCalorieGoal) -> \(calorieGoal), protein: \(oldProteinGoal) -> \(proteinGoal), carbs: \(oldCarbsGoal) -> \(carbsGoal), fat: \(oldFatGoal) -> \(fatGoal)")
            
            // Генерируем новый ID для обновления интерфейса
            viewState.refreshID = UUID()
            
            // Запускаем анимацию обновления прогресса
            animateProgressUpdate()
            
            // Добавляем тактильный отклик при обновлении значений
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
    
    // Функция для анимации обновления прогресса
    private func animateProgressUpdate() {
        // Вначале сбрасываем анимацию, чтобы затем плавно обновить значения
        withAnimation(.easeOut(duration: 0.2)) {
            animateProgress = false
        }
        
        // Затем с задержкой плавно анимируем обновление значений
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.6)) {
                self.animateProgress = true
            }
        }
    }
    
    // Обновление UserProfile новыми значениями
    private func updateUserProfileWithNewValues() {
        // Выводим текущие значения
        print("Текущие значения перед обновлением: calories=\(navigationCoordinator.userProfile.dailyCalorieTarget), protein=\(navigationCoordinator.userProfile.proteinGramsTarget)g, carbs=\(navigationCoordinator.userProfile.carbsGramsTarget)g, fat=\(navigationCoordinator.userProfile.fatGramsTarget)g")
        
        // Обновляем значения в UserProfile
        navigationCoordinator.userProfile.dailyCalorieTarget = calorieGoal
        navigationCoordinator.userProfile.proteinGramsTarget = proteinGoal
        navigationCoordinator.userProfile.carbsGramsTarget = carbsGoal
        navigationCoordinator.userProfile.fatGramsTarget = fatGoal
        
        // Обновляем также значения для расчета
        navigationCoordinator.userProfile.dailyCalories = Double(calorieGoal)
        navigationCoordinator.userProfile.proteinInGrams = Double(proteinGoal)
        navigationCoordinator.userProfile.carbsInGrams = Double(carbsGoal)
        navigationCoordinator.userProfile.fatsInGrams = Double(fatGoal)
        
        // Генерируем новый ID для обновления интерфейса
        viewState.refreshID = UUID()
        
        // Отправляем уведомление об обновлении значений
        NotificationCenter.default.post(
            name: .nutritionValuesUpdated,
            object: nil,
            userInfo: [
                "calories": navigationCoordinator.userProfile.dailyCalories,
                "protein": navigationCoordinator.userProfile.proteinInGrams,
                "carbs": navigationCoordinator.userProfile.carbsInGrams,
                "fats": navigationCoordinator.userProfile.fatsInGrams
            ]
        )
        
        print("Обновлены значения в UserProfile: calories=\(calorieGoal), protein=\(proteinGoal)g, carbs=\(carbsGoal)g, fat=\(fatGoal)g")
    }
    
    // Настройка обработчиков уведомлений
    private func setupNotificationHandlers() {
        // Очищаем существующие подписки
        notificationSubscriptions.removeAll()
        
        // Подписываемся на уведомления об изменении питательных веществ
        NotificationCenter.default.publisher(for: .nutritionValuesUpdated)
            .sink { notification in
                // Обновляем состояние из UserProfile
                DispatchQueue.main.async {
                    // Загружаем новые значения из UserProfile
                    print("Получено уведомление об обновлении питательных веществ")
                    self.loadNutritionGoalsFromUserProfile()
                    
                    // Генерируем новый ID для обновления интерфейса
                    self.viewState.refreshID = UUID()
                    
                    // Анимация запускается в loadNutritionGoalsFromUserProfile при необходимости
                }
            }
            .store(in: &notificationSubscriptions)
            
        // Подписываемся на изменения в HealthKitManager
        viewState.healthManager.objectWillChange
            .sink { _ in
                // Обновляем интерфейс когда изменяются данные HealthKit
                DispatchQueue.main.async {
                    print("Обновление данных HealthKit: сожжено калорий \(Int(self.viewState.healthManager.caloriesBurned))")
                    
                    // Сначала сбрасываем анимацию, затем плавно включаем её снова
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.animateProgress = false
                    }
                    
                    // Затем с небольшой задержкой включаем анимацию снова
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                            self.animateProgress = true
                        }
                    }
                    
                    // Обновляем ID для принудительного обновления компонентов
                    self.viewState.refreshID = UUID()
                }
            }
            .store(in: &notificationSubscriptions)
    }
    
    // Проверка и сброс значений потребления при смене дня
    private func checkAndResetConsumption() {
        // Получаем текущую дату в формате строки
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())
        
        
        // Если дата изменилась или приложение запускается впервые, сбрасываем значения
        if lastUpdateDateString != todayString {
            // Сбрасываем значения потребления в UserProfile
            navigationCoordinator.userProfile.resetConsumedValues()
            
            // Also reset water intake
            waterSettings.resetWaterIntake()
            
            // Обновляем дату последнего обновления
            lastUpdateDateString = todayString
            
            print("Сброс значений потребления для нового дня: \(todayString)")
        }
    }
    
    // Helper function to check HealthKit authorization
    private func checkHealthKitAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }
        
        // If already authorized, start fetching
        if viewState.healthManager.isAuthorized {
            viewState.healthManager.startFetchingHealthData()
        }
    }
    
    // Функция для форматирования даты в строковый ключ
    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // Сохранение кэша данных в UserDefaults
    private func saveDailyDataCache() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(dailyDataCache)
            UserDefaults.standard.set(data, forKey: dailyDataCacheKey)
            UserDefaults.standard.synchronize()
            print("Кэш данных сохранен в UserDefaults, размер: \(dailyDataCache.count) дней")
        } catch {
            print("Ошибка при сохранении кэша данных: \(error.localizedDescription)")
        }
    }
    
    // Загрузка кэша данных из UserDefaults
    private func loadDailyDataCache() {
        if let data = UserDefaults.standard.data(forKey: dailyDataCacheKey) {
            do {
                let decoder = JSONDecoder()
                let loadedCache = try decoder.decode([String: DailyData].self, from: data)
                dailyDataCache = loadedCache
                print("Кэш данных загружен из UserDefaults, размер: \(dailyDataCache.count) дней")
            } catch {
                print("Ошибка при загрузке кэша данных: \(error.localizedDescription)")
            }
        }
    }
    
    // Сохранение текущих данных для выбранной даты
    private func saveDataForCurrentDate() {
        // Получаем ключ для текущей выбранной даты
        let key = dateKey(for: selectedDate)
        
        // Создаем объект с текущими данными для сохранения
        var currentData = DailyData()
        
        // Определяем, какие данные сохранять в зависимости от того, текущий ли это день
        if Calendar.current.isDateInToday(selectedDate) {
            // Для сегодняшнего дня сохраняем актуальные данные из моделей
            currentData.consumedCalories = viewState.navigationCoordinator.userProfile.consumedCalories
            currentData.consumedProtein = viewState.navigationCoordinator.userProfile.consumedProtein
            currentData.consumedCarbs = viewState.navigationCoordinator.userProfile.consumedCarbs
            currentData.consumedFat = viewState.navigationCoordinator.userProfile.consumedFat
            currentData.caloriesBurned = viewState.healthManager.caloriesBurned
            currentData.steps = viewState.healthManager.steps
            currentData.waterIntake = waterSettings.totalWaterIntake
            
            print("Сохраняем актуальные данные для текущего дня (\(key)): шаги=\(currentData.steps), калории=\(currentData.caloriesBurned)")
        } else {
            // Для других дат, если мы уже показываем какие-то данные, сохраняем их
            // Это обеспечит, что мы не потеряем данные при переключении дат
            if let existingData = dailyDataCache[key] {
                // Если в кэше есть данные, используем их как основу
                currentData = existingData
                print("Используем существующие данные из кэша для \(key): шаги=\(currentData.steps), калории=\(currentData.caloriesBurned)")
            }
        }
        
        // Сохраняем в кэш
        dailyDataCache[key] = currentData
        
        // Сохраняем обновленный кэш в UserDefaults
        saveDailyDataCache()
        
        print("Данные для \(key) сохранены: калории=\(currentData.consumedCalories), шаги=\(currentData.steps)")
    }
    
    // Загрузка данных для выбранной даты
    private func loadDataForSelectedDate() {
        let key = dateKey(for: selectedDate)
        let today = dateKey(for: Date())
        
        print("Загружаем данные для даты: \(key), сегодня: \(today)")
        
        if key == today {
            // Для сегодняшнего дня используем текущие данные
            print("Выбран текущий день, используем актуальные данные")
            
            // Обновляем данные в HealthKit, если это необходимо
            viewState.healthManager.startFetchingHealthData()
            
            // Refresh UI
            viewState.refreshID = UUID()
        } else if let cachedData = dailyDataCache[key] {
            // Загружаем данные из кэша для выбранной даты
            print("Загружаем данные для \(key) из кэша: шаги=\(cachedData.steps), калории=\(cachedData.caloriesBurned)")
            
            // Создаем временный объект navigationCoordinator.userProfile
            let tempProfile = viewState.navigationCoordinator.userProfile.copy()
            tempProfile.consumedCalories = cachedData.consumedCalories
            tempProfile.consumedProtein = cachedData.consumedProtein
            tempProfile.consumedCarbs = cachedData.consumedCarbs
            tempProfile.consumedFat = cachedData.consumedFat
            
            // Получаем историю тренировок для этой даты
                    let dateTrainings = getTrainingsForDate(selectedDate)
            print("Получено \(dateTrainings.count) тренировок для выбранной даты")
            
            // Создаем временный объект healthManager для отображения исторических данных
            let tempHealthManager = HealthKitManager.createTemporary(
                steps: cachedData.steps,
                stepsCalories: Double(cachedData.steps) * 0.05,
                activityCalories: cachedData.caloriesBurned - (Double(cachedData.steps) * 0.05), // Вычисляем активности как разницу
                trainingsHistory: dateTrainings
            )
            
            // Обновляем временные значения воды
            if waterSettings.totalWaterIntake != cachedData.waterIntake {
                let originalWater = waterSettings.totalWaterIntake
                waterSettings.totalWaterIntake = cachedData.waterIntake
                
                // Восстанавливаем значение воды после небольшой задержки
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    waterSettings.totalWaterIntake = originalWater
                }
            }
            
            // Обновляем данные через StateObject, который безопасно обрабатывает обновления UI
            viewState.updateWithTemporaryData(profile: tempProfile, manager: tempHealthManager)
        } else {
            // Для неизвестных прошлых дней показываем пустые данные
            print("Для \(key) нет данных в кэше, показываем пустые данные")
            
            // Создаем пустые временные объекты
            let emptyProfile = viewState.navigationCoordinator.userProfile.copy()
            emptyProfile.resetConsumedValues()
            
            // Получаем историю тренировок для этой даты (если есть)
            let dateTrainings = getTrainingsForDate(selectedDate)
            
            let emptyHealthManager = HealthKitManager.createTemporary(
                steps: 0,
                stepsCalories: 0,
                activityCalories: 0,
                trainingsHistory: dateTrainings
            )
            
            // Обновляем данные через StateObject, который безопасно обрабатывает обновления UI
            viewState.updateWithTemporaryData(profile: emptyProfile, manager: emptyHealthManager)
            
            // Создаем новую запись в кэше для этой даты
            var emptyData = DailyData()
            // Если есть тренировки, учитываем их калории
                    if !dateTrainings.isEmpty {
                var totalActivityCalories: Double = 0
                for training in dateTrainings {
                    if let calories = training["calories"] as? Double {
                        totalActivityCalories += calories
                    }
                }
                emptyData.caloriesBurned = totalActivityCalories
            }
            
            // Сохраняем пустые данные в кэш, чтобы они были доступны при следующем загружении
            dailyDataCache[key] = emptyData
            saveDailyDataCache()
        }
    }
    
    // Получение тренировок только для выбранной даты
    private func getTrainingsForDate(_ date: Date) -> [[String: Any]] {
        guard let allTrainings = UserDefaults.standard.array(forKey: "trainingsHistory") as? [[String: Any]] else {
            return []
        }
        
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: date)
        
        // Фильтруем тренировки только для выбранной даты
        return allTrainings.filter { trainingData in
            if let trainingDate = trainingData["date"] as? Date {
                let trainingDay = calendar.startOfDay(for: trainingDate)
                return trainingDay == selectedDay
            }
            return false
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(NavigationCoordinator.shared)
    }
}

// Полноэкранный календарь для выбора даты
struct FullCalendarView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedDate: Date
    @Binding var currentMonthDate: Date
    
    @State private var calendarDate = Date()
    @State private var monthOffset = 0
    
    private var currentMonth: Date {
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.month = monthOffset
        return calendar.date(byAdding: dateComponents, to: Date()) ?? Date()
    }
    
    var body: some View {
        ZStack {
            // Белый фон на весь экран
            Color.white.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Заголовок месяца с кнопками навигации (увеличиваем верхний отступ)
                HStack {
                    Text(formattedMonthYear)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    // Кнопки навигации
                    HStack(spacing: 30) {
                        Button(action: {
                            monthOffset -= 1
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.black)
                        }
                        
                        Button(action: {
                            monthOffset += 1
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.black)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 40) // Увеличиваем верхний отступ для заголовка
                .padding(.bottom, 20) // Добавляем отступ снизу
                
                // Дни недели
                HStack {
                    ForEach(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10) // Добавляем отступ между днями недели и сеткой календаря
                
                // Custom calendar grid
                CustomCalendarGridView(
                    selectedDate: $selectedDate,
                    currentMonth: currentMonth,
                    monthOffset: $monthOffset
                )
                
                Spacer()
                
                // Кнопка Done внизу
                Button(action: {
                    // Применяем выбранную дату и закрываем
                    currentMonthDate = selectedDate
                    
                    // Вибрация при выборе
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    
                    // Закрываем модальное окно
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Done")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(red: 0, green: 0.27, blue: 0.24)) // Зеленый цвет кнопки
                        .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
    }
    
    // Форматированный месяц и год
    private var formattedMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
}

// Custom calendar grid view
struct CustomCalendarGridView: View {
    @Binding var selectedDate: Date
    let currentMonth: Date
    @Binding var monthOffset: Int
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let calendar = Calendar.current
    
    private var daysInMonth: [Date] {
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        
        var days = [Date]()
        
        // Get the weekday of the first day (0 is Sunday in Swift Calendar)
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        
        // Calculate offset based on Monday as first day (1 in our UI, 2 in Swift Calendar)
        let offset = (firstWeekday + 5) % 7 // Transform to Monday = 0
        
        // Add empty slots for days before the 1st of the month
        if offset > 0 {
            for _ in 0..<offset {
                days.append(Date(timeIntervalSince1970: 0)) // Placeholder date
            }
        }
        
        // Add all days of the month
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        // Fill the rest of the grid if needed
        let remainingDays = 42 - days.count // 6 rows × 7 columns = 42 cells
        if remainingDays > 0 {
            for day in 1...remainingDays {
                if let lastDate = days.last, let date = calendar.date(byAdding: .day, value: day, to: lastDate) {
                    days.append(date)
                }
            }
        }
        
        return days
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 15) {
            ForEach(0..<daysInMonth.count, id: \.self) { index in
                let date = daysInMonth[index]
                
                // Check if it's a placeholder (empty) date
                if calendar.component(.month, from: date) != calendar.component(.month, from: currentMonth) {
                    Text("")
                        .frame(width: 40, height: 40)
                } else {
                    let day = calendar.component(.day, from: date)
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.black : Color.clear)
                            .frame(width: 40, height: 40)
                        
                        Text("\(day)")
                            .font(.system(size: 18))
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundColor(isSelected ? .white : .black)
                    }
                    .frame(width: 40, height: 40)
                    .onTapGesture {
                        selectedDate = date
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
        }
        .padding(.horizontal, 10)
    }
}







