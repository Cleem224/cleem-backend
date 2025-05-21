import SwiftUI
import UIKit
import Combine
// Import models
import Foundation

// String-based enum to avoid ambiguity
enum NutrientOption: String {
    case calories
    case protein
    case carbs
    case fat
    
    var title: String {
        switch self {
        case .calories: return "Calorie left"
        case .protein: return "Protein left"
        case .carbs: return "Carb left"
        case .fat: return "Fat left"
        }
    }
    
    var iconName: String {
        switch self {
        case .calories: return "flame.fill"
        case .protein: return "p.square.fill"
        case .carbs: return "c.square.fill"
        case .fat: return "f.square.fill"
        }
    }
    
    // Определяет, нужно ли отображать иконку в квадратном фоне
    var useCustomSquareBackground: Bool {
        switch self {
        case .calories: return true
        case .protein, .carbs, .fat: return false // Уже используют встроенные квадратные иконки SF Symbols
        }
    }
    
    var color: Color {
        switch self {
        case .calories: return .black
        case .protein: return Color(red: 0.92, green: 0.36, blue: 0.36) // Red
        case .carbs: return Color(red: 0.36, green: 0.56, blue: 0.92) // Blue
        case .fat: return Color(red: 0.92, green: 0.62, blue: 0.36) // Orange
        }
    }
    
    // Map NutrientOption to NutritionParameterType
    var parameterType: NutritionParameterType {
        switch self {
        case .calories: return .calories
        case .protein: return .protein
        case .carbs: return .carbs
        case .fat: return .fats
        }
    }
}

// Main Nutrients Modal View
struct NutrientsModalView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @Binding var calorieGoal: Int
    @Binding var proteinGoal: Int
    @Binding var carbsGoal: Int
    @Binding var fatGoal: Int
    @Binding var isPresented: Bool
    
    // States for modal presentation
    @State private var animateItems = false
    @State private var refreshID = UUID() // Для принудительного обновления UI
    
    // Переключатель связи показателей
    @State private var linkNutrients: Bool = true
    
    // Сохраняем исходные значения для возможного сброса
    @State private var initialCalories: Int = 0
    @State private var initialProtein: Int = 0
    @State private var initialCarbs: Int = 0
    @State private var initialFat: Int = 0
    
    var onSave: () -> Void
    
    var body: some View {
        ZStack {
            // Background color - using pure white
            Color.white.edgesIgnoringSafeArea(.all)
                .clipShape(RoundedRectangle(cornerRadius: 45, style: .continuous))
            
            VStack(spacing: 20) {
                // Top section with X button and title - rearranged layout
                HStack {
                    // X button - moved to the left
                    Button(action: {
                        // Add vibration when tapping X button
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        dismissModal()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                        }
                    }
                    
                    Spacer()
                    
                    // Title - centered and moved further down
                    Text("Nutrients")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                        .offset(y: 60) // Moving down even more
                    
                    Spacer()
                    
                    // Empty space to balance the layout
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 100) // Further increased top padding
                
                // Added extra space to move panels down
                Spacer().frame(height: 15)
                
                // Nutrients list
                VStack(spacing: 15) {
                    // Переключатель связи питательных веществ (перемещен над панелью калорий)
                    HStack {
                        Spacer() // Added spacer to push toggle to the right
                        
                        Text("All")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.black)
                        
                        Toggle("", isOn: $linkNutrients)
                            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0, green: 0.27, blue: 0.24)))
                            .labelsHidden()
                            .onChange(of: linkNutrients) { newValue in
                                // Обновляем настройку в профиле пользователя
                                navigationCoordinator.userProfile.autoCalculateNutrients = newValue
                                
                                // Добавляем одиночную тактильную обратную связь
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.prepare() // Подготавливаем генератор для уменьшения задержки
                                generator.impactOccurred() // Генерируем одиночную вибрацию
                            }
                    }
                    .padding(.trailing, 10) // Changed from leading to trailing
                    .padding(.bottom, 5)
                    
                    // Calorie goal
                    nutrientRow(option: .calories, value: calorieGoal)
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 10)
                        .animation(.easeOut(duration: 0.3).delay(0.1), value: animateItems)
                        .id("calories-\(calorieGoal)-\(refreshID)") // Принудительное обновление
                    
                    // Protein goal
                    nutrientRow(option: .protein, value: proteinGoal)
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 10)
                        .animation(.easeOut(duration: 0.3).delay(0.2), value: animateItems)
                        .id("protein-\(proteinGoal)-\(refreshID)") // Принудительное обновление
                    
                    // Carbs goal
                    nutrientRow(option: .carbs, value: carbsGoal)
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 10)
                        .animation(.easeOut(duration: 0.3).delay(0.3), value: animateItems)
                        .id("carbs-\(carbsGoal)-\(refreshID)") // Принудительное обновление
                    
                    // Fat goal
                    nutrientRow(option: .fat, value: fatGoal)
                        .opacity(animateItems ? 1 : 0)
                        .offset(y: animateItems ? 0 : 10)
                        .animation(.easeOut(duration: 0.3).delay(0.4), value: animateItems)
                        .id("fat-\(fatGoal)-\(refreshID)") // Принудительное обновление
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .id(refreshID) // Привязываем изменение refreshID к обновлению UI
                
                Spacer()
                
                // Go button at bottom
                Button(action: {
                    // Save changes and dismiss
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    dismissModal()
                }) {
                    Text("Go")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46) // Further reduced height
                        .background(
                            Capsule()
                                .fill(Color.black)
                        )
                }
                .padding(.horizontal, 65)
                .padding(.bottom, 30) // Further reduced to move button up more
                .offset(y: -40) // Further increased negative offset to move button up more
                .opacity(animateItems ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.5), value: animateItems)
            }
        }
        .onAppear {
            // Сохраняем начальные значения
            initialCalories = calorieGoal
            initialProtein = proteinGoal
            initialCarbs = carbsGoal
            initialFat = fatGoal
            
            // Инициализируем переключатель связи нутриентов
            linkNutrients = navigationCoordinator.userProfile.autoCalculateNutrients
            
            // Animate items appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateItems = true
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // Nutrient row
    private func nutrientRow(option: NutrientOption, value: Int) -> some View {
        Button(action: {
            // Add haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            // Открываем экран редактирования более прямым способом
            // Без перенаправления через NavigationCoordinator
            openParameterEdit(option: option)
        }) {
            HStack(spacing: 15) {
                // Circle with icon
                ZStack {
                    // White background circle
                    Circle()
                        .stroke(lineWidth: 5)
                        .foregroundColor(.white)
                    
                    // Progress circle - используем процент из UserProfile
                    let progress = getProgressForNutrient(option: option)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .foregroundColor(option.color)
                        .frame(width: 44, height: 44)
                        .rotationEffect(Angle(degrees: 270))
                    
                    // Icon
                    // Квадратный фон для всех нутриентов
                    RoundedRectangle(cornerRadius: 4)
                        .fill(option.color)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Group {
                                if option == .calories {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                } else if option == .protein {
                                    Text("P")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                } else if option == .carbs {
                                    Text("C")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                } else if option == .fat {
                                    Text("F")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        )
                }
                
                // Nutrient name and value
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.system(size: 16))
                        .foregroundColor(.black.opacity(0.7))
                    
                    Text("\(value)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Spacer()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background(Color.gray.opacity(0.15)) // Темно-серый фон для панелей
            .cornerRadius(12)
        }
    }
    
    // Функция для получения прогресса для каждого нутриента
    private func getProgressForNutrient(option: NutrientOption) -> CGFloat {
        switch option {
        case .calories:
            let target = Double(calorieGoal)
            return min(1.0, max(0.0, CGFloat(navigationCoordinator.userProfile.consumedCalories / target)))
        case .protein:
            let target = Double(proteinGoal)
            return min(1.0, max(0.0, CGFloat(navigationCoordinator.userProfile.consumedProtein / target)))
        case .carbs:
            let target = Double(carbsGoal)
            return min(1.0, max(0.0, CGFloat(navigationCoordinator.userProfile.consumedCarbs / target)))
        case .fat:
            // Получаем прогресс жиров из UserProfile
            let target = Double(fatGoal)
            return min(1.0, max(0.0, CGFloat(navigationCoordinator.userProfile.consumedFat / target)))
        }
    }
    
    // Обновленный метод открытия экрана редактирования с поддержкой пересчета
    private func openParameterEdit(option: NutrientOption) {
        // Clear any possible focus to prevent keyboard issues
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Устанавливаем автоматический пересчет в профиле
        navigationCoordinator.userProfile.autoCalculateNutrients = linkNutrients
        
        // Создаем общий обработчик для обновления значений без атрибутов захвата
        let updater = {
            // Используем явное обращение к self без захвата
            self.updateValuesAfterEdit(option: option)
        }

        // Use the same edit view configuration for all nutrient types
        let editView = NavigationView {
            NutritionParameterEditView(
                parameterType: option.parameterType,
                value: getBindingForOption(option),
                onDismiss: updater
            )
            .environmentObject(navigationCoordinator)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        
        // Create the hosting controller with the same configuration for all nutrients
        let editController = UIHostingController(rootView: editView)
        
        // Add a PresentationDelegate to handle dismissal for all nutrients
        let delegate = PresentationDelegate(onDismiss: updater)
        
        // Apply a consistent configuration for the presentation controller
        if let presentationController = editController.presentationController {
            presentationController.delegate = delegate
        }
        
        // Present the controller with consistent settings
        presentEditScreen(editController)
    }
    
    // Helper to get the correct binding based on nutrient option
    private func getBindingForOption(_ option: NutrientOption) -> Binding<Int> {
        switch option {
        case .calories:
            return $calorieGoal
        case .protein:
            return $proteinGoal
        case .carbs:
            return $carbsGoal
        case .fat:
            return $fatGoal
        }
    }
    
    // Отдельный метод для обновления значений после редактирования
    private func updateValuesAfterEdit(option: NutrientOption) {
        print("Updating values after edit: \(option), linkNutrients: \(linkNutrients)")
        
        let oldValues = "OLD - calories: \(initialCalories), protein: \(initialProtein), carbs: \(initialCarbs), fat: \(initialFat)"
        let newValues = "NEW - calories: \(calorieGoal), protein: \(proteinGoal), carbs: \(carbsGoal), fat: \(fatGoal)"
        print(oldValues)
        print(newValues)
        
        // Применяем изменения в зависимости от выбранного параметра
        switch option {
        case .calories:
            navigationCoordinator.userProfile.recalculateNutrientsFromCalories(newCalories: Double(calorieGoal))
        case .protein:
            navigationCoordinator.userProfile.recalculateFromProtein(newProtein: Double(proteinGoal))
        case .carbs:
            navigationCoordinator.userProfile.recalculateFromCarbs(newCarbs: Double(carbsGoal))
        case .fat:
            navigationCoordinator.userProfile.recalculateFromFats(newFats: Double(fatGoal))
        }
        
        // Если linkNutrients включен, то обновляем все значения из профиля
        if linkNutrients {
            calorieGoal = Int(round(navigationCoordinator.userProfile.dailyCalories))
            proteinGoal = Int(round(navigationCoordinator.userProfile.proteinInGrams))
            carbsGoal = Int(round(navigationCoordinator.userProfile.carbsInGrams))
            fatGoal = Int(round(navigationCoordinator.userProfile.fatsInGrams))
        }
        
        // Обновляем начальные значения независимо от режима связи
        switch option {
        case .calories:
            initialCalories = calorieGoal
        case .protein:
            initialProtein = proteinGoal
        case .carbs:
            initialCarbs = carbsGoal
        case .fat:
            initialFat = fatGoal
        }
        
        // Если linkNutrients включен, обновляем все начальные значения
        if linkNutrients {
            initialCalories = calorieGoal
            initialProtein = proteinGoal
            initialCarbs = carbsGoal
            initialFat = fatGoal
        }
        
        // Принудительно обновляем UI
        DispatchQueue.main.async {
            // Генерируем новый UUID для обновления представления
            self.refreshID = UUID()
            
            // Добавляем небольшую анимацию для плавного обновления значений
            withAnimation(.easeInOut(duration: 0.3)) {
                // Пустое замыкание, сама анимация создается обновлением refreshID
            }
        }
        
        // Отправляем уведомление об изменении для обновления интерфейса
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
    }
    
    // Вспомогательный метод для представления UIHostingController
    private func presentEditScreen(_ controller: UIHostingController<some View>) {
        // Explicitly set fullScreen presentation style and transition style
        controller.modalPresentationStyle = .fullScreen
        controller.modalTransitionStyle = .coverVertical
        
        // Set additional presentation configuration
        if let presentation = controller.presentationController {
            presentation.delegate = presentation.delegate // Preserve existing delegate
        }
        
        // Получаем текущий rootViewController для представления
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            // Находим самый верхний контроллер для правильного представления
            var topController = rootViewController
            while let presentedController = topController.presentedViewController {
                topController = presentedController
            }
            
            // Always dismiss any existing presented controller first to avoid inconsistencies
            if topController.presentedViewController != nil {
                topController.dismiss(animated: false) {
                    // Then present the new controller
                    topController.present(controller, animated: true)
                }
            } else {
                // Present directly if no existing controller
                topController.present(controller, animated: true)
            }
        }
    }
    
    // Вспомогательный класс для отслеживания закрытия модального окна
    class PresentationDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
        // Используем замыкание без захвата self
        let onDismiss: () -> Void
        
        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
            super.init()
        }
        
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            onDismiss()
        }
    }
    
    // Dismiss modal
    private func dismissModal() {
        // Call onSave callback
        onSave()
        
        // Dismiss the modal
        isPresented = false
    }
    
    // Функция для обновления значений в UserProfile
    private func updateUserProfileValues() {
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
        
        // Если значения не связаны, отключаем автоматический пересчет в профиле
        if !linkNutrients {
            navigationCoordinator.userProfile.autoCalculateNutrients = false
        } else {
            navigationCoordinator.userProfile.autoCalculateNutrients = true
        }
        
        // Отправляем уведомление о том, что значения питания обновились
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
        
        print("NutrientsModalView: Updated UserProfile with values: calories=\(calorieGoal), protein=\(proteinGoal)g, carbs=\(carbsGoal)g, fat=\(fatGoal)g")
    }
}

// Preview for NutrientsModalView
struct NutrientsModalView_Previews: PreviewProvider {
    static var previews: some View {
        NutrientsModalView(
            calorieGoal: .constant(1100),
            proteinGoal: .constant(130),
            carbsGoal: .constant(200),
            fatGoal: .constant(65),
            isPresented: .constant(true)
        ) {
            // Implementation of onSave callback
        }
        .environmentObject(NavigationCoordinator.shared)
    }
}

