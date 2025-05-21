import SwiftUI

struct QuickMenuPopup: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    // Dark green color from the screenshot (00453D)
    private let backgroundColor = Color(hex: "00453D")
    
    var body: some View {
        // Popup menu - теперь без фона и с меньшим размером
        VStack(spacing: 20) {
            // Main content - the green popup with buttons
            VStack(spacing: 20) {
                // First row - Monitor training and Food Database
                HStack(spacing: 20) {
                    // Monitor training button
                    MenuButton(
                        icon: "dumbbell",
                        label: "Monitor training",
                        action: {
                            isPresented = false
                            // Показываем экран мониторинга тренировок
                            navigationCoordinator.showTrainingMonitor()
                        }
                    )
                    
                    // Food Database button
                    MenuButton(
                        icon: "knife.fork.crossed",
                        label: "Food Database",
                        useAssetImage: true,
                        assetName: "Database",
                        action: {
                            isPresented = false
                            // Используем новый метод для отображения базы данных продуктов
                            navigationCoordinator.showFoodDatabase(onFoodSelected: { selectedFood in
                                // По умолчанию просто добавляем выбранную еду в список Recently Logged
                                if let food = selectedFood as? Food {
                                    print("Добавлен продукт \(food.name ?? "Unknown") из базы данных в Recently Logged")
                                    // Уведомляем об обновлении данных
                                    NotificationCenter.default.post(name: NSNotification.Name("FoodUpdated"), object: nil)
                                }
                            })
                        }
                    )
                }
                
                // Second row - only Scan food now
                HStack {
                    Spacer()
                    // Scan food button
                    MenuButton(
                        icon: "camera",
                        label: "Scan food",
                        action: {
                            isPresented = false
                            navigationCoordinator.showScanCamera = true
                        }
                    )
                    Spacer()
                }
            }
            .padding(25)
            .background(backgroundColor)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
            // Добавляем обработку нажатий для самого popup, чтобы предотвратить его закрытие
            .contentShape(Rectangle())
            .onTapGesture {
                // Предотвращаем закрытие при нажатии на сам popup
                // Пустое действие, чтобы перехватить нажатие
            }
        }
        .padding()
    }
}

// Button component for the menu
struct MenuButton: View {
    let icon: String
    let label: String
    var useAssetImage: Bool = false
    var assetName: String = ""
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                if useAssetImage {
                    // Используем изображение из Assets
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.black)
                } else {
                    // Используем системную иконку
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(.black)
                }
                
                if label == "Monitor training" {
                    VStack(spacing: 0) {
                        Text("Monitor")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.black)
                        Text("training")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.black)
                    }
                } else {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .padding(.top, label == "Monitor training" ? 2 : 0)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .frame(width: 120, height: 90)
            .background(Color.white)
            .cornerRadius(12)
        }
    }
}

struct QuickMenuPopup_Previews: PreviewProvider {
    static var previews: some View {
        Color.gray.opacity(0.5)
            .edgesIgnoringSafeArea(.all)
            .overlay(
                QuickMenuPopup(isPresented: .constant(true))
                    .environmentObject(NavigationCoordinator.shared)
            )
    }
}

