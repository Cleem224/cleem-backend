import SwiftUI

// MARK: - Стили кнопок

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.appPrimary)
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: Color.appPrimary.opacity(0.3), radius: 5, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .foregroundColor(Color.appPrimary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appPrimary, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    var bgColor: Color = .white
    var iconColor: Color = .appPrimary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(14)
            .background(bgColor)
            .foregroundColor(iconColor)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Стили карточек

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.appSecondaryBackground)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Стили текстовых полей

struct AppTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.appSecondary.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Компоненты

struct AppCard<Content: View>: View {
    var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .modifier(CardStyle())
    }
}

struct AppTextField: View {
    var placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var icon: String? = nil
    
    var body: some View {
        HStack {
            if let iconName = icon {
                Image(systemName: iconName)
                    .foregroundColor(Color.appSecondary)
                    .frame(width: 22, height: 22)
                    .padding(.leading, 8)
            }
            
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
            }
        }
        .modifier(AppTextFieldStyle())
    }
}

// MARK: - Расширения для применения стилей

extension View {
    func cardStyle() -> some View {
        self.modifier(CardStyle())
    }
    
    func appTextFieldStyle() -> some View {
        self.modifier(AppTextFieldStyle())
    }
}

// MARK: - Вспомогательные компоненты

struct SectionHeader: View {
    var title: String
    var showButton: Bool = false
    var buttonTitle: String = "See All"
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(Color.appTextOnElements)
            
            Spacer()
            
            if showButton {
                Button(action: { action?() }) {
                    Text(buttonTitle)
                        .font(.subheadline)
                        .foregroundColor(Color.appPrimary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 5)
    }
} 