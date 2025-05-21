import SwiftUI

struct LanguageSelectionView: View {
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @State private var selectedLanguage: UserProfile.Language = .russian
    @State private var navigateToNextScreen = false
    
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
        ZStack {
            // Background
            Color(red: 0.91, green: 0.97, blue: 1.0)
                .edgesIgnoringSafeArea(.all)
            
            // Language selection content
            VStack(spacing: 0) {
                // EN button in top right
                HStack {
                    Spacer()
                    Button(action: {
                        selectedLanguage = .english
                    }) {
                        Text("EN")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.black)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                
                Spacer()
                
                // Language selection box
                VStack(spacing: 0) {
                    ForEach(languages, id: \.language) { option in
                        LanguageButton(
                            language: option.name,
                            flag: option.flag,
                            isSelected: selectedLanguage == option.language,
                            action: {
                                selectedLanguage = option.language
                                navigationCoordinator.userProfile.preferredLanguage = option.language
                            }
                        )
                    }
                }
                .padding(.vertical, 20)
                .background(Color.white)
                .cornerRadius(20)
                .padding(.horizontal, 20)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                
                Spacer()
                
                // Continue button
                Button(action: {
                    // Save the selected language to user profile
                    navigationCoordinator.userProfile.preferredLanguage = selectedLanguage
                    
                    // Navigate to next screen
                    navigateToNextScreen = true
                }) {
                    Text("Get Started")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color.white)
                        .cornerRadius(30)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToNextScreen) {
            GenderSelectionView(
                onContinue: {
                    navigationCoordinator.activeScreen = .ageSelection
                },
                onBack: {
                    navigateToNextScreen = false
                }
            ).environmentObject(navigationCoordinator)
        }
        .onAppear {
            // Set initial language based on user profile if available
            selectedLanguage = navigationCoordinator.userProfile.preferredLanguage ?? .english
        }
    }
}

// Language button component
struct LanguageButton: View {
    let language: String
    let flag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(language)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.black)
                
                Spacer()
                
                Text(flag)
                    .font(.system(size: 30))
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.94, green: 0.94, blue: 0.94))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
}

struct LanguageSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LanguageSelectionView()
                .environmentObject(NavigationCoordinator.shared)
        }
    }
} 