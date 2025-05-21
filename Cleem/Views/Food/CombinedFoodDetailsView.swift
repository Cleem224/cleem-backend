import SwiftUI
import UIKit

// UIViewController wrapper for hard dismissal
class UIWindowDismissController: UIViewController {
    var dismissAction: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add a gesture recognizer to the whole view
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(forceDismiss))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func forceDismiss() {
        dismissAction?()
    }
}

// SwiftUI wrapper for the UIWindow dismiss controller
struct WindowDismissView: UIViewControllerRepresentable {
    var dismissAction: () -> Void
    
    func makeUIViewController(context: Context) -> UIWindowDismissController {
        let controller = UIWindowDismissController()
        controller.dismissAction = dismissAction
        controller.view.backgroundColor = .clear
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIWindowDismissController, context: Context) {
        uiViewController.dismissAction = dismissAction
    }
}

// UIKit wrapper to force dismiss the current view
class ForceDismissViewController: UIViewController {
    static func dismiss() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            // Force dismiss any presented controller
            if let presentedVC = rootVC.presentedViewController {
                presentedVC.dismiss(animated: true)
            }
            
            // Find any UIHostingController and dismiss it
            findAndDismissHostingController(rootVC)
            
            // Post notification to reset NavigationCoordinator
            NotificationCenter.default.post(name: NavigationCoordinator.navigateToHomeScreen, object: nil)
        }
    }
    
    private static func findAndDismissHostingController(_ viewController: UIViewController) {
        // Check if this is a UIHostingController
        if NSStringFromClass(type(of: viewController)).contains("UIHostingController") {
            viewController.dismiss(animated: true)
            return
        }
        
        // Check presented controller
        if let presented = viewController.presentedViewController {
            findAndDismissHostingController(presented)
        }
        
        // Check child controllers
        for child in viewController.children {
            findAndDismissHostingController(child)
        }
    }
}

// SwiftUI wrapper for the dismiss functionality
struct ForceDismissView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Nothing to update
    }
    
    static func dismiss() {
        ForceDismissViewController.dismiss()
    }
}

// Вспомогательное представление для создания кнопки закрытия, которая гарантированно работает
struct CloseButtonView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @Environment(\.presentationMode) var presentationMode
    
    // For haptic feedback
    private let generator = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        Button(action: {
            // Pre-prepare haptic feedback
            generator.prepare()
            
            // Use multiple dismissal methods to ensure it works
            dismissScreen()
        }) {
            // Простой дизайн кнопки X, как на фото, с увеличенными размерами
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 50) // Увеличиваем размер кнопки
                
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold)) // Увеличиваем размер иконки
                    .foregroundColor(.black)
            }
        }
        .buttonStyle(PlainButtonStyle()) // Ensure button taps are registered
        .contentShape(Circle()) // Make the entire circle tappable
        .padding(10) // Добавляем дополнительное пространство вокруг кнопки
    }
    
    // Separate function for dismissal logic to make code more organized
    private func dismissScreen() {
        // Generate haptic feedback
        generator.impactOccurred()
        
        print("CloseButton: Attempting to dismiss screen")
        
        // Force cleanup any active screen
        navigationCoordinator.activeScreen = nil
        
        // First try the SwiftUI way
        presentationMode.wrappedValue.dismiss()
        
        // Then try through NavigationCoordinator
        navigationCoordinator.dismissActiveScreen()
        
        // Use our force dismiss functionality
        ForceDismissView.dismiss()
        
        // Then use direct UIKit approach for maximum compatibility
        DispatchQueue.main.async {
            // Access the UIApplication to find any presented controllers
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                dismissPresentedViewController(rootViewController)
            }
            
            // Also force notify about navigation to home
            NotificationCenter.default.post(name: NavigationCoordinator.navigateToHomeScreen, object: nil)
        }
    }
    
    // Recursive function to dismiss any presented view controllers
    private func dismissPresentedViewController(_ viewController: UIViewController) {
        if let presentedVC = viewController.presentedViewController {
            // Dismiss this view controller
            presentedVC.dismiss(animated: true) {
                // After dismissal, check again recursively
                self.dismissPresentedViewController(viewController)
            }
        }
    }
}

// Add this extension after the previews
// Extension for reliable view dismissal
extension View {
    func reliableDismiss(with coordinator: NavigationCoordinator) -> some View {
        self.modifier(ReliableDismissModifier(coordinator: coordinator))
    }
}

// Modifier that uses multiple dismissal techniques
struct ReliableDismissModifier: ViewModifier {
    @Environment(\.presentationMode) var presentationMode
    let coordinator: NavigationCoordinator
    
    func body(content: Content) -> some View {
        content
            .onChange(of: coordinator.activeScreen) { _, newScreen in
                if newScreen == nil {
                    DispatchQueue.main.async {
                        self.presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onDisappear {
                // Ensure clean up when view disappears
                if coordinator.activeScreen != nil {
                    coordinator.activeScreen = nil
                }
            }
    }
}

// Добавляем компонент для ввода порций
struct PortionInputView: View {
    @Binding var portions: Int
    @Binding var isShowingPortionInput: Bool
    @State private var inputText: String = ""
    
    var body: some View {
        ZStack {
            // Затемненный фон
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    dismissKeyboard()
                    isShowingPortionInput = false
                }
            
            // Контейнер с вводом - упрощенный вариант
            VStack(spacing: 15) {
                // Убираем заголовок "Количество порций"
                
                TextField("", text: $inputText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 40, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .onAppear {
                        inputText = "\(portions)"
                        // Автофокус на поле ввода
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                
                // Одна кнопка "Done" вместо двух кнопок
                Button(action: {
                    if let value = Int(inputText), value > 0 {
                        portions = value
                    }
                    dismissKeyboard()
                    isShowingPortionInput = false
                }) {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 200)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .cornerRadius(10)
                }
                .padding(.bottom, 20)
            }
            .frame(width: 280)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct CombinedFoodDetailsView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @Environment(\.presentationMode) var presentationMode
    let combinedFood: CombinedFoodItem
    
    @State private var portions: Int = 1
    @State private var selectedSize: String = "Medium"
    private let sizes = ["Small", "Medium", "Large"]
    // Коэффициенты для размеров порций
    private let sizeMultipliers: [String: Double] = [
        "Small": 0.7,
        "Medium": 1.0,
        "Large": 1.4
    ]
    @State private var showBookmark: Bool = false
    @State private var formattedAddedTime: String = ""
    // For haptic feedback
    private let generator = UIImpactFeedbackGenerator(style: .light)
    // For dismiss gesture
    @State private var offset = CGSize.zero
    // Для отображения модального окна ввода порций
    @State private var isShowingPortionInput: Bool = false
    
    // Рассчитываем текущие значения с учетом числа порций и выбранного размера
    private var sizeMultiplier: Double {
        return sizeMultipliers[selectedSize] ?? 1.0
    }
    
    private var totalCalories: Int {
        return Int(combinedFood.calories * Double(portions) * sizeMultiplier)
    }
    
    private var totalProtein: Int {
        return Int(combinedFood.protein * Double(portions) * sizeMultiplier)
    }
    
    private var totalCarbs: Int {
        return Int(combinedFood.carbs * Double(portions) * sizeMultiplier)
    }
    
    private var totalFat: Int {
        return Int(combinedFood.fat * Double(portions) * sizeMultiplier)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Фоновый цвет для всего экрана
                Color(.systemGray6)
                    .edgesIgnoringSafeArea(.all)
                
                // Close button with large tap area (placed at the very bottom layer)
                Color.clear
                    .frame(width: 100, height: 100)
                    .contentShape(Rectangle())
                    .position(x: 50, y: 0) // Перемещаем на самый верх
                    .onTapGesture {
                        print("Tap area tapped")
                        generator.impactOccurred()
                        dismissAllWays()
                    }
                    .zIndex(200)
                
                // Основное содержимое - перемещаем всё выше
                VStack(spacing: 0) {
                    // Safe area padding at top - убираем отступ полностью
                    Color.clear
                        .frame(height: max(0, geometry.safeAreaInsets.top - 35)) // Максимально уменьшаем отступ сверху
                    
                    // Custom navigation bar - перемещаем максимально вверх
                    HStack {
                        Spacer()
                        
                        Text("Nutrition")
                            .font(.system(size: 22, weight: .semibold)) // Увеличиваем размер текста и делаем более жирным
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 5) // Минимальный вертикальный отступ
                    .background(Color(.systemGray6))
                    .padding(.top, -10) // Добавляем отрицательный отступ сверху, чтобы поднять панель выше
                    
                    ScrollView {
                        VStack(spacing: 12) { // Уменьшаем расстояние между элементами
                            // Food image first (переместили показатель времени после изображения)
                            if let imageData = combinedFood.imageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 165)
                                    .cornerRadius(14)
                                    .padding(.horizontal)
                                    .padding(.top, 10) // Небольшой отступ сверху
                            } else {
                                // Fallback image
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 165)
                                    .overlay(
                                        Image(systemName: "fork.knife")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 38)
                                            .foregroundColor(.gray)
                                    )
                                    .padding(.horizontal)
                                    .padding(.top, 10) // Небольшой отступ сверху
                            }
                            
                            // Time and bookmark indicator (перемещено после изображения)
                            HStack {
                                Spacer()
                                HStack {
                                    Text(formattedAddedTime)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.black)
                                        .foregroundColor(.white)
                                        .cornerRadius(15)
                                }
                                
                                Button(action: {
                                    showBookmark.toggle()
                                }) {
                                    Image(systemName: "bookmark")
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Food name
                            Text(combinedFood.name)
                                .font(.system(size: 28, weight: .bold))
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Portions section
                            HStack {
                                Text("Portions")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                // Portions indicator (dark pill)
                                Button(action: {
                                    generator.impactOccurred(intensity: 0.6)
                                    isShowingPortionInput = true
                                }) {
                                    HStack(spacing: 5) {
                                        Text("\(portions)")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.black))
                                }
                            }
                            .padding(.horizontal)
                            
                            // Portion sizes as segmented control - добавляем реальный функционал
                            HStack(spacing: 4) {
                                ForEach(sizes, id: \.self) { size in
                                    Button(action: {
                                        // Добавляем тактильный отклик
                                        generator.impactOccurred(intensity: 0.4)
                                        selectedSize = size
                                    }) {
                                        Text(size)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .padding(.vertical, 10)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(selectedSize == size ? Color.black : Color.gray.opacity(0.1))
                                            )
                                            .foregroundColor(selectedSize == size ? .white : .gray)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .animation(.easeInOut(duration: 0.2), value: selectedSize)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Nutrition Summary section - показатели пересчитываются автоматически
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Nutrition Summary")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                    .padding(.top, 5)
                                
                                // Nutrition metrics grid
                                VStack(spacing: 5) {
                                    // Labels row
                                    HStack {
                                        Text("Calories")
                                            .font(.footnote)
                                            .frame(maxWidth: .infinity)
                                        
                                        Text("Protein")
                                            .font(.footnote)
                                            .frame(maxWidth: .infinity)
                                        
                                        Text("Carbs")
                                            .font(.footnote)
                                            .frame(maxWidth: .infinity)
                                        
                                        Text("Fat")
                                            .font(.footnote)
                                            .frame(maxWidth: .infinity)
                                    }
                                    
                                    // Main circles row с новыми индикаторами прогресса
                                    HStack(spacing: 0) {
                                        // Calories
                                        VStack(spacing: 5) {
                                            ZStack {
                                                Circle()
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                                                    .frame(width: 60, height: 60)
                                                
                                                // Динамический прогресс в зависимости от выбранного размера
                                                Circle()
                                                    .trim(from: 0, to: min(1.0, Double(totalCalories) / 1000.0))
                                                    .stroke(Color.black, lineWidth: 6)
                                                    .frame(width: 60, height: 60)
                                                    .rotationEffect(.degrees(-90))
                                                
                                                // Square with icon inside
                                                RoundedRectangle(cornerRadius: 5)
                                                    .fill(Color.black)
                                                    .frame(width: 24, height: 24)
                                                    .overlay(
                                                        Image(systemName: "flame.fill")
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.white)
                                                    )
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        
                                        // Protein
                                        VStack(spacing: 5) {
                                            ZStack {
                                                Circle()
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                                                    .frame(width: 60, height: 60)
                                                
                                                // Динамический прогресс
                                                Circle()
                                                    .trim(from: 0, to: min(1.0, Double(totalProtein) / 50.0))
                                                    .stroke(Color.red, lineWidth: 6)
                                                    .frame(width: 60, height: 60)
                                                    .rotationEffect(.degrees(-90))
                                                
                                                // Square with letter inside
                                                RoundedRectangle(cornerRadius: 5)
                                                    .fill(Color.red)
                                                    .frame(width: 24, height: 24)
                                                    .overlay(
                                                        Text("P")
                                                            .font(.system(size: 14, weight: .bold))
                                                            .foregroundColor(.white)
                                                    )
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        
                                        // Carbs
                                        VStack(spacing: 5) {
                                            ZStack {
                                                Circle()
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                                                    .frame(width: 60, height: 60)
                                                
                                                // Динамический прогресс
                                                Circle()
                                                    .trim(from: 0, to: min(1.0, Double(totalCarbs) / 100.0))
                                                    .stroke(Color.blue, lineWidth: 6)
                                                    .frame(width: 60, height: 60)
                                                    .rotationEffect(.degrees(-90))
                                                
                                                // Square with letter inside
                                                RoundedRectangle(cornerRadius: 5)
                                                    .fill(Color.blue)
                                                    .frame(width: 24, height: 24)
                                                    .overlay(
                                                        Text("C")
                                                            .font(.system(size: 14, weight: .bold))
                                                            .foregroundColor(.white)
                                                    )
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        
                                        // Fat
                                        VStack(spacing: 5) {
                                            ZStack {
                                                Circle()
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                                                    .frame(width: 60, height: 60)
                                                
                                                // Динамический прогресс
                                                Circle()
                                                    .trim(from: 0, to: min(1.0, Double(totalFat) / 40.0))
                                                    .stroke(Color.orange, lineWidth: 6)
                                                    .frame(width: 60, height: 60)
                                                    .rotationEffect(.degrees(-90))
                                                
                                                // Square with letter inside
                                                RoundedRectangle(cornerRadius: 5)
                                                    .fill(Color.orange)
                                                    .frame(width: 24, height: 24)
                                                    .overlay(
                                                        Text("F")
                                                            .font(.system(size: 14, weight: .bold))
                                                            .foregroundColor(.white)
                                                    )
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .animation(.easeInOut(duration: 0.3), value: totalCalories)
                                    .animation(.easeInOut(duration: 0.3), value: totalProtein)
                                    .animation(.easeInOut(duration: 0.3), value: totalCarbs)
                                    .animation(.easeInOut(duration: 0.3), value: totalFat)
                                    
                                    // Values row с обновленными значениями
                                    HStack(spacing: 10) {
                                        Text("\(totalCalories)")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 5)
                                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                                        
                                        Text("\(totalProtein)g")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 5)
                                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                                        
                                        Text("\(totalCarbs)g")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 5)
                                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                                        
                                        Text("\(totalFat)g")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 5)
                                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                                    }
                                    .transition(.opacity)
                                    .animation(.easeInOut(duration: 0.2), value: totalCalories)
                                }
                                .padding(.vertical, 15)
                                .padding(.horizontal, 10)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            
                            // Add Ingredients button
                            Button(action: {
                                // Show the FoodDatabaseView to add new ingredients
                                navigationCoordinator.showFoodDatabase(onFoodSelected: { selectedFood in
                                    // Add the selected food as an ingredient
                                    if let food = selectedFood as? Food {
                                        // Copy the current list of ingredients
                                        var updatedIngredients = combinedFood.ingredients
                                        
                                        // Add the new ingredient
                                        updatedIngredients.append(food)
                                        
                                        // Set the ingredient flag
                                        food.isIngredient = true
                                        
                                        // Update the combined food with the new ingredients list
                                        combinedFood.ingredients = updatedIngredients
                                        
                                        // Save changes to the combined food
                                        CombinedFoodManager.shared.ensureBackupExists(combinedFood)
                                        
                                        // Update UI by forcing a UI refresh
                                        let updatedPortions = portions
                                        DispatchQueue.main.async {
                                            portions = updatedPortions
                                        }
                                        
                                        // Notify that food data has been updated
                                        NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
                                    }
                                })
                            }) {
                                HStack {
                                    Spacer()
                                    Text("Add ingredients")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.vertical, 15)
                                .background(Color.black)
                                .cornerRadius(8)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            
                            // Ingredients section
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Ingredients")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                
                                // Ingredients grid with 3 items per row
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 12) {
                                    // Используем реальные ингредиенты из комбинированного блюда
                                    ForEach(combinedFood.ingredients, id: \.id) { ingredient in
                                        IngredientItem(
                                            name: ingredient.name ?? "Unknown",
                                            unit: "1 unit",
                                            onDelete: {
                                                // Remove this ingredient from the combined food
                                                var updatedIngredients = combinedFood.ingredients
                                                updatedIngredients.removeAll { $0.id == ingredient.id }
                                                
                                                // Update the combined food with the new ingredients list
                                                combinedFood.ingredients = updatedIngredients
                                                
                                                // Save changes to the combined food
                                                CombinedFoodManager.shared.ensureBackupExists(combinedFood)
                                                
                                                // Update UI by forcing a UI refresh
                                                let updatedPortions = portions
                                                DispatchQueue.main.async {
                                                    portions = updatedPortions
                                                }
                                                
                                                // Notify that food data has been updated
                                                NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
                                            }
                                        )
                                    }
                                    
                                    // Add empty items to match the layout
                                    ForEach(0..<(3 - (combinedFood.ingredients.count % 3)), id: \.self) { _ in
                                        if combinedFood.ingredients.count % 3 != 0 && combinedFood.ingredients.count > 0 {
                                            Color.clear
                                                .frame(height: 70)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.bottom, 20)
                        }
                        .padding(.top, 0) // Убираем верхний отступ полностью
                        .padding(.bottom, geometry.safeAreaInsets.bottom)
                    }
                }
                
                // Верхняя панель с кнопкой закрытия - перемещаем выше
                VStack {
                    ZStack {
                        // Прозрачный фон для верхней панели - делаем минимальной высоты
                        Color.clear
                            .frame(height: 20 + geometry.safeAreaInsets.top) // Ещё больше уменьшаем высоту
                        
                        // Close button container
                        HStack {
                            // Increased touch area for close button
                            Button(action: {
                                // Generate haptic feedback
                                generator.impactOccurred()
                                
                                print("Corner Close Button: Closing view")
                                dismissAllWays()
                            }) {
                                ZStack {
                                    // Large transparent touch area
                                    Color.clear
                                        .frame(width: 60, height: 60)
                                    
                                    // Visible button
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 40, height: 40)
                                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                                        .overlay(
                                            Image(systemName: "xmark")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.black)
                                        )
                                }
                            }
                            .padding(.leading, 15)
                            .padding(.top, max(0, geometry.safeAreaInsets.top - 45)) // Максимально уменьшаем отступ сверху
                            .offset(y: -10) // Добавляем дополнительное смещение вверх
                            
                            Spacer()
                        }
                    }
                    Spacer()
                }
                .zIndex(100) // Ensure close button is above all content
                
                // Add invisible WindowDismissView for hard dismissal
                WindowDismissView(dismissAction: dismissAllWays)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .allowsHitTesting(false)
                
                // Модальное окно для ввода порций
                if isShowingPortionInput {
                    PortionInputView(
                        portions: $portions,
                        isShowingPortionInput: $isShowingPortionInput
                    )
                    .zIndex(300) // Выше всех остальных элементов
                }
            }
            // Add swipe down gesture to dismiss
            .offset(y: offset.height)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.height > 0 {
                            self.offset = gesture.translation
                        }
                    }
                    .onEnded { gesture in
                        if gesture.translation.height > 100 {
                            withAnimation {
                                dismissAllWays()
                            }
                        } else {
                            withAnimation {
                                self.offset = .zero
                            }
                        }
                    }
            )
        }
        .navigationBarHidden(true)
        .onAppear {
            formatAddedTime()
            prepareHaptics()
        }
        // Add a hidden UIKit bridge for force dismissal
        .background(ForceDismissView().frame(width: 0, height: 0).opacity(0))
        // Replace the previous onChange with our new modifier
        .reliableDismiss(with: navigationCoordinator)
    }
    
    // Helper method to prepare haptic feedback
    private func prepareHaptics() {
        generator.prepare()
    }
    
    // Combined dismissal method to handle all possible ways to dismiss
    private func dismissAllWays() {
        // Direct approach - reset active screen
        navigationCoordinator.activeScreen = nil
        
        // Use our force dismiss functionality
        ForceDismissView.dismiss()
        
        // Use presentation mode
        presentationMode.wrappedValue.dismiss()
        
        // Post notification
        NotificationCenter.default.post(name: NavigationCoordinator.navigateToHomeScreen, object: nil)
        
        // Try NavigationCoordinator
        navigationCoordinator.dismissActiveScreen()
        
        // Dispatch to main for UIKit operations
        DispatchQueue.main.async {
            // Direct UIKit approach
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.dismiss(animated: true)
            }
        }
    }
    
    // Форматируем время добавления еды в формат "HH:mm"
    private func formatAddedTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        // Используем дату создания (createdAt) из модели
        formattedAddedTime = formatter.string(from: combinedFood.createdAt)
    }
}

// Simple Ingredient Item without image
struct IngredientItem: View {
    var name: String
    var unit: String
    var onDelete: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 8) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                    
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .frame(height: 70)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                
                // Delete button
                if let deleteAction = onDelete {
                    Button(action: deleteAction) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 18))
                            .shadow(color: .white, radius: 1)
                            .padding(5)
                    }
                }
            }
        }
    }
}

struct CombinedFoodDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock combined food for preview
        let mockFood1 = Food(context: CoreDataManager.shared.context)
        mockFood1.id = UUID()
        mockFood1.name = "Steak"
        mockFood1.calories = 200
        mockFood1.protein = 25
        mockFood1.carbs = 0
        mockFood1.fat = 12
        
        let mockFood2 = Food(context: CoreDataManager.shared.context)
        mockFood2.id = UUID()
        mockFood2.name = "Mushrooms"
        mockFood2.calories = 20
        mockFood2.protein = 2
        mockFood2.carbs = 3
        mockFood2.fat = 0
        
        let mockCombinedFood = CombinedFoodItem(
            name: "Pizza",
            ingredients: [mockFood1, mockFood2]
        )
        
        return CombinedFoodDetailsView(combinedFood: mockCombinedFood)
            .environmentObject(NavigationCoordinator.shared)
    }
}



