import SwiftUI
// Удаляем импорт GoogleSignIn и используем наши локальные типы
import Combine
// Импорты для работы с Google Sign-In и OAuth
import AppAuth

// Добавляем импорт файла с мок-реализацией
// import нашего внутреннего модуля с мок-типами
// Файл MockGoogleSignInTypes.swift содержит все необходимые типы

// Structure renamed to match usage in OnboardingView
struct GoogleSignInView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = GoogleSignInViewModel()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // Добавляем callback для обработки пропуска аутентификации
    var onSkip: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 25) {
            // Логотип и заголовок
            VStack(spacing: 15) {
                Image("AppLogo") // Замените на ваш логотип
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                
                Text("Вход в Cleem")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Для сохранения вашего прогресса и персональных данных выполните вход с помощью Google")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 50)
            
            Spacer()
            
            // Кнопка входа через Google
            Button(action: {
                viewModel.signInWithGoogle()
            }) {
                HStack {
                    Image("GoogleLogo") // Добавьте изображение логотипа Google
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    
                    Text("Войти с Google")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
                .frame(minWidth: 0, maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, 30)
            
            // Кнопка пропустить
            Button("Пропустить") {
                // Действие при пропуске - вызываем переданный callback
                if let onSkip = onSkip {
                    onSkip()
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .font(.system(size: 16))
            .foregroundColor(.secondary)
            .padding(.bottom, 30)
        }
        .onReceive(viewModel.$errorMessage) { message in
            if !message.isEmpty {
                alertMessage = message
                showingAlert = true
            }
        }
        .onReceive(viewModel.$isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                // Переход на главный экран при успешной аутентификации
                if let onSkip = onSkip {
                    onSkip()
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Ошибка входа"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: {
            if let onSkip = onSkip {
                onSkip()
            } else {
                presentationMode.wrappedValue.dismiss()
            }
        }) {
            Image(systemName: "arrow.left")
                .foregroundColor(.primary)
        })
    }
}

class GoogleSignInViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var errorMessage = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    func signInWithGoogle() {
        // Настройка конфигурации
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            errorMessage = "Ошибка конфигурации Google Sign-In"
            return
        }
        
        // Проверяем, какое окно верхнего уровня мы можем использовать
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Не удалось отобразить окно аутентификации"
            return
        }
        
        // Используем наш сервис для эмуляции входа
        GoogleSignInService.shared.signIn(clientID: clientID, presentingViewController: rootViewController) { [weak self] user, error in
            if let error = error {
                self?.handleError(error)
                return
            }
            
            guard let user = user else {
                self?.errorMessage = "Не удалось получить данные пользователя"
                return
            }
            
            let auth = user.authentication
            guard let idToken = auth.idToken,
                  let accessToken = auth.accessToken else {
                self?.errorMessage = "Не удалось получить токены аутентификации"
                return
            }
            
            // Вызываем метод аутентификации на сервере
            self?.authenticateWithServer(idToken: idToken, accessToken: accessToken)
        }
    }
    
    private func authenticateWithServer(idToken: String, accessToken: String) {
        print("Аутентификация на сервере с идентификатором: \(idToken)")
        
        // Создаем запрос для Google аутентификации
        let googleToken = GoogleSignInRequest(
            access_token: accessToken,
            id_token: idToken,
            expires_in: 3600, // Стандартное время жизни токена - 1 час
            refresh_token: nil,
            token_type: "Bearer",
            scope: "email profile"
        )
        
        // Используем ApiService для аутентификации
        ApiService.shared.authenticateWithGoogle(googleToken: googleToken)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completionResult in
                switch completionResult {
                case .failure(let error):
                    print("Ошибка аутентификации: \(error.localizedDescription)")
                    self?.errorMessage = "Ошибка аутентификации: \(error.localizedDescription)"
                case .finished:
                    break
                }
            }, receiveValue: { [weak self] token in
                guard let self = self else { return }
                
                // Сохраняем данные пользователя в UserDefaults
                UserDefaults.standard.set(token.access_token, forKey: "jwt_token")
                UserDefaults.standard.set(token.user.id, forKey: "user_id")
                UserDefaults.standard.set(token.user.name, forKey: "user_name")
                UserDefaults.standard.set(token.user.email, forKey: "user_email")
                
                // Устанавливаем состояние аутентификации
                self.isAuthenticated = true
            })
            .store(in: &cancellables)
    }
    
    private func handleError(_ error: Error) {
        print("Ошибка аутентификации: \(error.localizedDescription)")
        errorMessage = "Ошибка аутентификации: \(error.localizedDescription)"
    }
}

struct GoogleSignInView_Previews: PreviewProvider {
    static var previews: some View {
        GoogleSignInView()
    }
} 