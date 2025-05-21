import SwiftUI
import CoreData
import HealthKit
import UIKit

// Убираем @main, так как он уже есть в AppDelegate
struct CleemApp: App {
    // Добавляем делегат приложения для обработки событий жизненного цикла
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject var navigationCoordinator = NavigationCoordinator.shared
    
    let persistenceController = PersistenceController.shared
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    // Ключ для отслеживания первого запуска приложения
    @AppStorage("appFirstLaunchCompleted") private var appFirstLaunchCompleted = false
    
    // Состояние для отображения заставки при запуске
    @State private var showLaunchScreen = true
    // Состояние для управления отображением баннеров
    @State private var showBanner = false
    @State private var bannerData = BannerData(title: "", detail: "", type: .success)
    
    // Отслеживаем состояние жизненного цикла приложения
    @Environment(\.scenePhase) private var scenePhase
    
    // Reference to health manager to ensure it's initialized on app startup
    // Using @ObservedObject to ensure it's kept alive and updated
    @ObservedObject private var healthManager = HealthKitManager.shared
    
    init() {
        // Устанавливаем значение use_new_recognition в true по умолчанию
        UserDefaults.standard.set(true, forKey: "use_new_recognition")
        
        // Инициализируем API ключи только для нового менеджера при запуске приложения
        print("🚀 Инициализация CleemApp...")
        FoodRecognitionManagerV2.initializeApiKeys()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Основной экран приложения
                MainTabView()
                    .environmentObject(navigationCoordinator)
                    .preferredColorScheme(.light)
                    .banner(isPresented: $showBanner, data: bannerData)
                    .onAppear {
                        setupAppearance()
                        setupNotifications()
                        
                        // Проверяем, первый ли это запуск приложения
                        if !appFirstLaunchCompleted {
                            print("Первый запуск приложения: сбрасываем статус авторизации HealthKit")
                            // При первом запуске сбрасываем статус авторизации
                            healthManager.resetAuthorizationStatus()
                            // Отмечаем, что первый запуск завершен
                            appFirstLaunchCompleted = true
                        }
                        
                        // Verify HealthKit authorization on app start
                        print("App started, verifying HealthKit authorization")
                        
                        // Force check authorization status with staggered checks
                        // to ensure proper initialization
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            healthManager.forceCheckAuthorization()
                            
                            // Series of checks to ensure proper state
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                healthManager.forceCheckAuthorization()
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    healthManager.forceCheckAuthorization()
                                }
                            }
                        }
                        
                        // Проверяем, нужно ли показать онбординг
                        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
                        if !hasCompletedOnboarding {
                            DispatchQueue.main.async {
                                // Запускаем полный процесс онбординга
                                navigationCoordinator.startOnboarding()
                            }
                        }
                    }
                    .onChange(of: healthManager.isAuthorized) { newValue in
                        print("App detected HealthKit authorization change: \(newValue)")
                    }
                    // Добавим обработку жизненного цикла приложения для сброса флага обновления
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                        // Приложение уходит в фон - сбрасываем флаг обновления
                        print("App going to background - resetting HealthKit session flag")
                        healthManager.resetSessionUpdateFlag()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                        // Приложение закрывается - сбрасываем флаг обновления
                        print("App terminating - resetting HealthKit session flag")
                        healthManager.resetSessionUpdateFlag()
                    }
                
                // Заставка при загрузке, отображается поверх основного контента
                if showLaunchScreen {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                        .onAppear {
                            // Скрыть заставку через 1 секунду
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showLaunchScreen = false
                                }
                            }
                        }
                }
            }
        }
        // Отслеживаем изменения состояния сцены для сохранения данных
        .onChange(of: scenePhase) { oldPhase, newPhase in
            print("Изменение состояния приложения: \(oldPhase) -> \(newPhase)")
            
            if newPhase == .active && oldPhase != .active {
                print("Приложение стало активным - загружаем и проверяем данные")
                
                // Проверяем инициализацию UserDefaults
                if UserDefaults.standard.object(forKey: "foodHistory") == nil {
                    print("CleemApp: Инициализация foodHistory в UserDefaults")
                    UserDefaults.standard.set([], forKey: "foodHistory")
                    UserDefaults.standard.synchronize()
                }
                
                // Synchronize food data between CoreData and UserDefaults
                CoreDataManager.shared.synchronizeAllFoodData()
                
                // Проверяем состояние foodHistory
                if let foodHistory = UserDefaults.standard.array(forKey: "foodHistory") as? [[String: Any]] {
                    print("CleemApp: При активации найдено \(foodHistory.count) записей еды в UserDefaults")
                    
                    // Фильтруем яблоки при запуске приложения
                    var filteredFoodHistory = foodHistory
                    let initialCount = filteredFoodHistory.count
                    
                    // Удаляем все записи с "apple" в названии, если они не являются последним отсканированным продуктом
                    let lastScannedFoodID = UserDefaults.standard.string(forKey: "lastScannedFoodID")
                    filteredFoodHistory.removeAll { item in
                        if let name = item["name"] as? String,
                           name.lowercased() == "apple",
                           let id = item["id"] as? String,
                           id != lastScannedFoodID {
                            print("CleemApp: 🍎 Удаляем Apple из истории еды для предотвращения появления по умолчанию")
                            return true
                        }
                        return false
                    }
                    
                    // Если мы удалили яблоки из истории, сохраняем обновленную историю
                    if initialCount != filteredFoodHistory.count {
                        UserDefaults.standard.set(filteredFoodHistory, forKey: "foodHistory")
                        // Удаляем lastAppleImage для полной уверенности
                        UserDefaults.standard.removeObject(forKey: "lastAppleImage")
                        UserDefaults.standard.synchronize()
                        print("CleemApp: Удалено \(initialCount - filteredFoodHistory.count) яблок из истории еды")
                    }
                } else {
                    print("CleemApp: При активации не найдена история еды в UserDefaults")
                }
                
                // Отправляем уведомление для обновления интерфейса
                NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
                print("CleemApp: Отправлено уведомление FoodUpdated")
            }
            
            if newPhase == .background || newPhase == .inactive {
                print("Приложение уходит в фон или стало неактивным - сохраняем данные в CoreData")
                CoreDataManager.shared.saveContext()
                
                // Принудительная синхронизация UserDefaults
                UserDefaults.standard.synchronize()
                print("CleemApp: UserDefaults синхронизирован")
            }
        }
    }
    
    func setupAppearance() {
        // Настройка UIKit элементов, чтобы они соответствовали нашей теме
        UINavigationBar.appearance().backgroundColor = UIColor(Color.appBackgroundPeach)
        UINavigationBar.appearance().tintColor = UIColor(Color.appPrimary)
        UITabBar.appearance().backgroundColor = UIColor(Color.appSecondaryBackground)
    }
    
    func setupNotifications() {
        // Настройка слушателя уведомлений для отображения баннеров
        NotificationCenter.default.addObserver(forName: Notification.Name("ShowBanner"), object: nil, queue: .main) { notification in
            if let bannerData = notification.object as? BannerData {
                self.bannerData = bannerData
                withAnimation {
                    self.showBanner = true
                }
            }
        }
    }
}

// Splash экран внутри приложения
struct SplashScreenView: View {
    var body: some View {
        ZStack {
            // Светло-голубой фон, такой же как на экранах onboarding
            Color(red: 0.91, green: 0.97, blue: 1.0)
                .edgesIgnoringSafeArea(.all)
            
            // Логотип и текст Cleem в центре экрана (горизонтально)
            HStack(spacing: 2) {
                // Логотип брокколи (иконка из Assets)
                Image("BroccoliFace")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                
                // Надпись Cleem
                Text("Cleem")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.leading, -5) // Дополнительно приближаем текст к изображению
            }
        }
    }
}

// Все цвета теперь определены в Color+Extensions.swift
extension Color {
    // Основной фон (как на фото)
    static let appBackgroundPeach = Color(red: 0.94, green: 0.63, blue: 0.56)
    
    // Основной светло-голубой фон (как на скриншоте)
    static let appBackground = Color(red: 0.82, green: 0.93, blue: 0.99)
    
    // Цвет фона для экрана приветствия (персиковый)
    static let appWelcomeBackground = Color(red: 1.0, green: 0.74, blue: 0.57)
    
    // Цвет фона для голубого экрана приветствия
    static let appBlueBackground = Color(red: 0.85, green: 0.95, blue: 1.0)
    
    // Цвет для кнопок на экране приветствия
    static let appButtonBackground = Color(red: 0.9, green: 0.9, blue: 0.9)
    
    // Основной цвет акцента
    static let appPrimary = Color(red: 0.23, green: 0.21, blue: 0.38)
    
    // Дополнительный цвет акцента
    static let appSecondary = Color(red: 0.6, green: 0.41, blue: 0.51)
    
    // Цвет текста на фоне
    static let appText = Color(red: 0.27, green: 0.27, blue: 0.27)
    
    // Цвет фона для карточек и элементов
    static let appSecondaryBackground = Color.white
    
    // Цвет текста на элементах
    static let appTextOnElements = Color(red: 0.2, green: 0.2, blue: 0.2)
    
    // Вспомогательный цвет для декоративных элементов
    static let appAccent = Color(red: 0.85, green: 0.57, blue: 0.5)
}


