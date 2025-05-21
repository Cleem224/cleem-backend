import SwiftUI

// Add extension to make UserProfile.Language identifiable
extension UserProfile.Language: Identifiable {
    public var id: String { self.rawValue }
}

struct LanguageSelectionSheet: View {
    @Binding var isPresented: Bool
    @Binding var selectedLanguage: UserProfile.Language
    var onLanguageSelected: (UserProfile.Language) -> Void
    
    var body: some View {
        ZStack {
            // Полупрозрачный задний фон
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    // Закрыть при нажатии вне карточки
                    isPresented = false
                }
            
            // Белая карточка с языками
            VStack(spacing: 10) {
                // Русский
                languageButton(language: .russian, title: "Русский")
                
                // Английский
                languageButton(language: .english, title: "English")
                
                // Испанский
                languageButton(language: .spanish, title: "Español")
                
                // Французский
                languageButton(language: .french, title: "Français")
                
                // Китайский
                languageButton(language: .chinese, title: "中文")
                
                // Немецкий
                languageButton(language: .german, title: "Deutsch")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
            )
            .padding(.horizontal, 30)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: isPresented)
    }
    
    private func languageButton(language: UserProfile.Language, title: String) -> some View {
        Button(action: {
            selectedLanguage = language
            onLanguageSelected(language)
            // Не закрываем окно после выбора языка
        }) {
            HStack {
                Spacer()
                
                Text(title)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.black)
                
                Text(language.flag)
                    .font(.system(size: 20))
                    .padding(.leading, 6)
                
                Spacer()
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.92, green: 0.92, blue: 0.92)) // Светло-серый цвет как на скриншоте
            )
        }
    }
}

#Preview {
    ZStack {
        Color(red: 0.91, green: 0.97, blue: 1.0).edgesIgnoringSafeArea(.all)
        
        LanguageSelectionSheet(
            isPresented: .constant(true),
            selectedLanguage: .constant(.english),
            onLanguageSelected: { _ in }
        )
    }
} 