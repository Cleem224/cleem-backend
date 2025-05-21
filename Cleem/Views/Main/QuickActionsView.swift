import SwiftUI

struct QuickActionsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    var body: some View {
        NavigationView {
            ZStack {
                // Основной фон
                Color.appBackground
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Text("Add Food")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.top)
                    
                    Text("Choose how you want to add food")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.bottom, 30)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        QuickActionButton(
                            title: "Camera",
                            icon: "camera.fill",
                            color: Color.carbsColor,
                            action: {
                                presentationMode.wrappedValue.dismiss()
                                navigationCoordinator.showScanCamera = true
                            }
                        )
                        
                        QuickActionButton(
                            title: "Barcode",
                            icon: "barcode.viewfinder",
                            color: Color.fatColor,
                            action: {
                                presentationMode.wrappedValue.dismiss()
                                navigationCoordinator.showBarcodeScannerView = true
                            }
                        )
                        
                        QuickActionButton(
                            title: "Food Label",
                            icon: "doc.text.viewfinder",
                            color: Color.proteinColor,
                            action: {
                                presentationMode.wrappedValue.dismiss()
                                navigationCoordinator.showFoodLabelView = true
                            }
                        )
                        
                        QuickActionButton(
                            title: "Manual Entry",
                            icon: "square.and.pencil",
                            color: Color.carbsColor,
                            action: {
                                presentationMode.wrappedValue.dismiss()
                                showManualEntry()
                            }
                        )
                    }
                    .padding()
                    
                    // Добавляем тестовую секцию для демонстрации обновления прогресса
                    VStack(spacing: 15) {
                        Text("Test Progress Updates")
                            .font(.headline)
                            .padding(.top)
                        
                        HStack(spacing: 20) {
                            Button(action: {
                                // Добавляем небольшое количество еды для демонстрации
                                addSmallMeal()
                                // Закрываем окно
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                VStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.green)
                                    
                                    Text("Small Meal")
                                        .font(.caption)
                                        .foregroundColor(.black)
                                }
                                .frame(width: 100, height: 70)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            
                            Button(action: {
                                // Добавляем среднее количество еды
                                addMediumMeal()
                                // Закрываем окно
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                VStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.orange)
                                    
                                    Text("Medium Meal")
                                        .font(.caption)
                                        .foregroundColor(.black)
                                }
                                .frame(width: 100, height: 70)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                            
                            Button(action: {
                                // Сбрасываем значения потребления
                                resetConsumption()
                                // Закрываем окно
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                VStack {
                                    Image(systemName: "arrow.counterclockwise.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.red)
                                    
                                    Text("Reset")
                                        .font(.caption)
                                        .foregroundColor(.black)
                                }
                                .frame(width: 100, height: 70)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
            .navigationBarItems(trailing: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color.carbsColor)
            })
        }
    }
    
    private func showManualEntry() {
        // Show search page for manual entry
        navigationCoordinator.showManualFoodEntry(for: "Custom Meal")
    }
    
    // MARK: - Тестовые функции для демонстрации
    
    // Добавление небольшого приема пищи (примерно 15-25% от дневной нормы)
    private func addSmallMeal() {
        // Получаем целевые значения
        let targetCalories = Double(navigationCoordinator.userProfile.dailyCalorieTarget)
        let targetProtein = Double(navigationCoordinator.userProfile.proteinGramsTarget)
        let targetCarbs = Double(navigationCoordinator.userProfile.carbsGramsTarget)
        let targetFat = Double(navigationCoordinator.userProfile.fatGramsTarget)
        
        // Рассчитываем случайное значение 15-25% от цели
        let caloriesAmount = targetCalories * Double.random(in: 0.15...0.25)
        let proteinAmount = targetProtein * Double.random(in: 0.15...0.25)
        let carbsAmount = targetCarbs * Double.random(in: 0.15...0.25)
        let fatAmount = targetFat * Double.random(in: 0.15...0.25)
        
        // Добавляем в профиль
        navigationCoordinator.userProfile.addConsumedFood(
            calories: caloriesAmount,
            protein: proteinAmount,
            carbs: carbsAmount,
            fat: fatAmount
        )
        
        // Вибрация для обратной связи
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // Добавление среднего приема пищи (примерно 30-40% от дневной нормы)
    private func addMediumMeal() {
        // Получаем целевые значения
        let targetCalories = Double(navigationCoordinator.userProfile.dailyCalorieTarget)
        let targetProtein = Double(navigationCoordinator.userProfile.proteinGramsTarget)
        let targetCarbs = Double(navigationCoordinator.userProfile.carbsGramsTarget)
        let targetFat = Double(navigationCoordinator.userProfile.fatGramsTarget)
        
        // Рассчитываем случайное значение 30-40% от цели
        let caloriesAmount = targetCalories * Double.random(in: 0.3...0.4)
        let proteinAmount = targetProtein * Double.random(in: 0.3...0.4)
        let carbsAmount = targetCarbs * Double.random(in: 0.3...0.4)
        let fatAmount = targetFat * Double.random(in: 0.3...0.4)
        
        // Добавляем в профиль
        navigationCoordinator.userProfile.addConsumedFood(
            calories: caloriesAmount,
            protein: proteinAmount,
            carbs: carbsAmount,
            fat: fatAmount
        )
        
        // Вибрация для обратной связи
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // Сброс значений потребления
    private func resetConsumption() {
        navigationCoordinator.userProfile.resetConsumedValues()
        
        // Вибрация для обратной связи
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 15) {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 30))
                            .foregroundColor(color)
                    )
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickActionsView_Previews: PreviewProvider {
    static var previews: some View {
        QuickActionsView()
            .environmentObject(NavigationCoordinator.shared)
    }
}

