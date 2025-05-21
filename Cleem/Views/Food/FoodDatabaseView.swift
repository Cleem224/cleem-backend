import SwiftUI
import UIKit
import CoreData

struct FoodDatabaseView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @StateObject private var databaseService = FoodDatabaseService.shared
    
    @State private var searchText = ""
    @State private var selectedTab = 0 // 0 - All, 1 - Saved Food, 2 - Custom Meal
    @State private var showErrorAlert = false
    @State private var selectedFood: RecommendedFoodItem? = nil
    @State private var showFoodDetail = false
    
    private let tabs = ["All", "Saved Food", "Custom Meal"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header с заголовком и кнопкой закрытия
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Food Database")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Кнопка для обновления рекомендаций
                Button(action: {
                    databaseService.loadRecommendations()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            
            // Строка поиска
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("What was on your plate?", text: $searchText)
                    .font(.system(size: 16))
                    .onChange(of: searchText) { newValue in
                        databaseService.searchFoods(query: newValue)
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        databaseService.searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 5)
            
            // Табы для фильтрации
            HStack {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button(action: {
                        selectedTab = index
                    }) {
                        Text(tabs[index])
                            .font(.system(size: 14, weight: selectedTab == index ? .semibold : .regular))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(selectedTab == index ? Color.black : Color.gray.opacity(0.2))
                            .foregroundColor(selectedTab == index ? .white : .black)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            // Заголовок раздела рекомендаций
            HStack {
                Text("Recommendations")
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top, 20)
                
                Spacer()
                
                // Индикатор ошибки
                if databaseService.errorMessage != nil {
                    Button(action: {
                        showErrorAlert = true
                    }) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Отображение результатов поиска или рекомендаций
            ZStack {
                ScrollView {
                    VStack(spacing: 15) {
                        if !searchText.isEmpty {
                            if databaseService.searchResults.isEmpty && !databaseService.isLoading {
                                Text("No results found")
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                ForEach(databaseService.searchResults) { food in
                                    FoodItemRow(food: food, onTap: {
                                        selectedFood = food
                                        showFoodDetail = true
                                    })
                                }
                            }
                        } else {
                            if databaseService.recommendations.isEmpty && !databaseService.isLoading {
                                Text("No recommendations available")
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                ForEach(databaseService.recommendations) { food in
                                    FoodItemRow(food: food, onTap: {
                                        selectedFood = food
                                        showFoodDetail = true
                                    })
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                .background(Color.white)
                
                // Индикатор загрузки
                if databaseService.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .frame(width: 100, height: 100)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
        }
        .background(Color.white)
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            databaseService.loadRecommendations()
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"),
                message: Text(databaseService.errorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showFoodDetail) {
            if let food = selectedFood {
                FoodDetailView(food: food, onAdd: {
                    addFoodWithHapticFeedback(food)
                })
            }
        }
    }
    
    // Функция для добавления еды с тактильным откликом
    private func addFoodWithHapticFeedback(_ food: RecommendedFoodItem) {
        // Генерируем тактильный отклик для улучшения UX
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
        
        print("===== ДОБАВЛЕНИЕ ПРОДУКТА ИЗ FOOD DATABASE =====")
        
        // Передаем продукт в базу данных для обработки
        databaseService.addFoodToRecentlyLogged(food: food)
        
        // Используем NavigationCoordinator для возврата выбранного продукта
        if let recentlyScannedFood = NavigationCoordinator.shared.recentlyScannedFood {
            navigationCoordinator.selectFoodFromDatabase(recentlyScannedFood)
        }
        
        // Показываем уведомление об успехе
        let banner = BannerData(title: "Добавлено", detail: food.name, type: .success)
        NotificationCenter.default.post(name: Notification.Name("ShowBanner"), object: banner)
        
        // Закрываем экран
        presentationMode.wrappedValue.dismiss()
        
        print("===== ДОБАВЛЕНИЕ ПРОДУКТА ЗАВЕРШЕНО =====")
    }
}

// Структура для баннерного уведомления
struct BannerData {
    let title: String
    let detail: String
    let type: BannerType
    
    enum BannerType {
        case success
        case error
        case warning
    }
}

struct FoodDatabaseView_Previews: PreviewProvider {
    static var previews: some View {
        FoodDatabaseView()
            .environmentObject(NavigationCoordinator.shared)
    }
}

