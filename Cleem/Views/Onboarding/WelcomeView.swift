import SwiftUI
import CoreHaptics

struct WelcomeView: View {
    var onContinue: () -> Void
    @State private var animateItems = false
    @State private var showLanguageSelection = false
    @State private var selectedLanguage: UserProfile.Language = .english
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var hapticEngine: CHHapticEngine?
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            // Background - light blue
            Color(red: 0.91, green: 0.97, blue: 1.0)
                .edgesIgnoringSafeArea(.all)
            
            // Основной контент
            VStack {
                // Language button in top right corner
                HStack {
                    Spacer()
                    Button(action: {
                        showLanguageSelection = true
                        // Вибрация при нажатии
                        generateFeedback()
                    }) {
                        Text(selectedLanguage.code)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                    .opacity(animateItems ? 1.0 : 0)
                    .offset(y: animateItems ? 0 : -10)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: animateItems)
                }
                
                Spacer()
                
                // Welcome image in center (увеличенный размер)
                ZStack {
                    // Белый круг под изображением
                    Circle()
                        .fill(Color.white)
                        .frame(width: UIScreen.main.bounds.width * 0.7, height: UIScreen.main.bounds.width * 0.7)
                    
                    // Изображение
                    Image("Welcome")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: UIScreen.main.bounds.width * 0.75, height: UIScreen.main.bounds.width * 0.75)
                        .clipShape(Circle())
                        .offset(x: 8, y: 2)
                        .rotationEffect(Angle(degrees: rotationAngle))
                        .onAppear {
                            // Запускаем анимацию постоянного вращения
                            withAnimation(.linear(duration: 45).repeatForever(autoreverses: false)) {
                                rotationAngle = 360
                            }
                        }
                }
                .padding(.vertical, 15)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: animateItems)
                
                Spacer()
                
                // Text section moved down, above the Get Started button
                VStack(spacing: 10) {
                    // Main title
                    Text("Welcome to Cleem!")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                    
                    // Subtitle
                    Text("Health is above all")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .padding(.top, 5)
                }
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.4), value: animateItems)
                .padding(.bottom, 40)
                
                // Get Started button (уменьшенный текст)
                Button(action: {
                    // Вибрация при нажатии
                    generateFeedback()
                    onContinue()
                }) {
                    Text("Get Started")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color.white)
                        .cornerRadius(30)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
                .opacity(animateItems ? 1 : 0)
                .offset(y: animateItems ? 0 : 30)
                .animation(.easeOut(duration: 0.5).delay(0.6), value: animateItems)
                .zIndex(1) // Устанавливаем более низкий z-index для кнопки
            }
            .allowsHitTesting(!showLanguageSelection) // Блокируем взаимодействие с основным контентом при открытом языковом меню
            
            // Language selection overlay
            if showLanguageSelection {
                // Dark overlay for the background
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showLanguageSelection = false
                    }
                    .zIndex(2)
                
                VStack {
                    Spacer().frame(height: UIScreen.main.bounds.height * 0.15) // Increased height slightly to move it down
                    
                    LanguageSelectionOverlay(
                        selectedLanguage: $selectedLanguage,
                        isPresented: $showLanguageSelection
                    )
                    
                    Spacer()
                }
                .zIndex(3) // Higher z-index than the overlay
            }
        }
        .onAppear {
            // Подготовка haptic feedback
            prepareHaptics()
            
            // Запускаем анимацию появления элементов с небольшой задержкой
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateItems = true
            }
            
            // Load saved language if available
            if let savedLanguage = navigationCoordinator.userProfile.preferredLanguage {
                selectedLanguage = savedLanguage
            }
        }
    }
    
    // Метод для подготовки haptic feedback
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine error: \(error.localizedDescription)")
        }
    }
    
    // Функция для создания тактильной обратной связи (вибрации)
    private func generateFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

struct LanguageSelectionOverlay: View {
    @Binding var selectedLanguage: UserProfile.Language
    @Binding var isPresented: Bool
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    
    // Language options
    private let languages: [(language: UserProfile.Language, name: String, flag: String)] = [
        (.russian, "Русский", "🇷🇺"),
        (.english, "English", "🇺🇸"),
        (.spanish, "Español", "🇪🇸"),
        (.french, "Français", "🇫🇷"),
        (.chinese, "中文", "🇨🇳"),
        (.german, "Deutsch", "🇩🇪")
    ]
    
    var body: some View {
        // Белая карточка с языками (как на скриншоте)
        VStack(spacing: 12) {
            ForEach(languages, id: \.language) { option in
                Button(action: {
                    selectedLanguage = option.language
                    navigationCoordinator.userProfile.preferredLanguage = option.language
                    
                    // Вибрация при выборе языка
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    
                    isPresented = false
                }) {
                    HStack {
                        Spacer()
                        
                        // Название языка и флаг по центру, рядом друг с другом
                        HStack(spacing: 10) {
                            Text(option.name)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.black)
                            
                            Text(option.flag)
                                .font(.system(size: 24))
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.93, green: 0.93, blue: 0.93))
                    .cornerRadius(16)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(onContinue: {})
            .environmentObject(NavigationCoordinator.shared)
    }
} 