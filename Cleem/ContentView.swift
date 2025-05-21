import SwiftUI
import CoreData
import Combine

struct ContentView: View {
    // Создаем экземпляр FoodScanViewModel как StateObject, чтобы он жил
    // на протяжении всего жизненного цикла приложения
    @StateObject private var foodScanViewModel = FoodScanViewModel(context: CoreDataManager.shared.context)
    
    // Доступ к CoreData контексту
    @Environment(\.managedObjectContext) private var viewContext
    
    // Инициализируем координатор навигации
    @StateObject private var navigationCoordinator = NavigationCoordinator.shared
    
    // Инициализируем обработчик Google Sign-In
    @StateObject private var googleSignInHandler = GoogleSignInHandler.shared
    
    // Состояние для показа кнопки входа через Google
    @State private var showGoogleSignIn = false
    
    var body: some View {
        // Основное представление - MainTabView
        ZStack {
            MainTabView(navigationCoordinator: navigationCoordinator)
                // Внедряем FoodScanViewModel во все дочерние представления
                .environmentObject(foodScanViewModel)
                // Предоставляем CoreData контекст всем дочерним представлениям
                .environment(\.managedObjectContext, viewContext)
                // Внедряем обработчик Google Sign-In
                .environmentObject(googleSignInHandler)
                // При появлении представления загружаем текущие данные о потреблении
                .onAppear {
                    foodScanViewModel.fetchTodayConsumption()
                }
                // Добавляем модальные окна для сканирования еды
                .fullScreenCover(isPresented: $navigationCoordinator.showScanCamera) {
                    // Выбираем версию камеры на основе настройки
                    if navigationCoordinator.shouldUseNewScanCameraView {
                        // Новая версия с подходом Gemini+GPT+Spoonacular
                        ScanCameraViewV2()
                            .environmentObject(navigationCoordinator)
                    } else {
                        // Старая версия с подходом Gemini+Edamam
                        ScanCameraView()
                            .environmentObject(navigationCoordinator)
                    }
                }
                // Добавляем поддержку входа через Google
                .sheet(isPresented: $showGoogleSignIn) {
                    GoogleSignInContentView()
                        .environmentObject(googleSignInHandler)
                }
                
                // Показываем индикатор загрузки, если идет процесс входа
                if googleSignInHandler.isLoading {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    
                    ProgressView("Вход в аккаунт...")
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .shadow(radius: 10)
                        )
                }
        }
    }
}

// Представление для входа через Google
struct GoogleSignInContentView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var googleSignInHandler: GoogleSignInHandler
    
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                
                Text("Войти в Cleem")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Для сохранения ваших данных и синхронизации между устройствами необходимо войти в аккаунт")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                Spacer()
                
                // Кнопка входа через Google
                GoogleSignInButton {
                    handleGoogleSignIn()
                }
                .padding(.horizontal)
                .disabled(googleSignInHandler.isLoading)
                
                // Кнопка входа через Apple (для примера)
                Button(action: {
                    // Здесь будет вход через Apple
                }) {
                    HStack {
                        Image(systemName: "apple.logo")
                            .font(.title2)
                        
                        Text("Войти через Apple")
                            .fontWeight(.medium)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                            .background(Color.white)
                    )
                    .cornerRadius(8)
                }
                .padding(.horizontal)
                .foregroundColor(.primary)
                .disabled(googleSignInHandler.isLoading)
                
                Button("Продолжить без входа") {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
                .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Ошибка входа"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .navigationBarItems(trailing: Button("Закрыть") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func handleGoogleSignIn() {
        // Используем GoogleSignInViewController для входа
        let viewController = UIViewController()
        googleSignInHandler.signIn(from: viewController) { result in
            switch result {
            case .success(let userData):
                print("Пользователь успешно вошел: \(userData.name)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    presentationMode.wrappedValue.dismiss()
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
    }
}
