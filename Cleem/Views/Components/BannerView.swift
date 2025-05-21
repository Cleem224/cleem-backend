import SwiftUI

// Компонент для отображения уведомлений в виде баннеров
struct BannerView: View {
    @Binding var isPresented: Bool
    var data: BannerData
    var autoDismiss: Bool = true
    var dismissDelay: TimeInterval = 2.0
    
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                // Иконка в зависимости от типа уведомления
                iconView
                
                // Текст уведомления
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if !data.detail.isEmpty {
                        Text(data.detail)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Кнопка закрытия
                Button(action: {
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(bannerColor)
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal)
        .onAppear {
            if autoDismiss {
                DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) {
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    // Цвет фона баннера зависит от типа уведомления
    private var bannerColor: Color {
        switch data.type {
        case .success:
            return Color.green.opacity(0.9)
        case .error:
            return Color.red.opacity(0.9)
        case .warning:
            return Color.orange.opacity(0.9)
        }
    }
    
    // Иконка баннера зависит от типа уведомления
    private var iconView: some View {
        Group {
            switch data.type {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 22, weight: .semibold))
            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 22, weight: .semibold))
            case .warning:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 22, weight: .semibold))
            }
        }
    }
}

// Модификатор для добавления баннера к любому представлению
struct BannerModifier: ViewModifier {
    @Binding var isPresented: Bool
    var data: BannerData
    var autoDismiss: Bool = true
    var dismissDelay: TimeInterval = 2.0
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isPresented {
                VStack {
                    BannerView(
                        isPresented: $isPresented,
                        data: data,
                        autoDismiss: autoDismiss,
                        dismissDelay: dismissDelay
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                    
                    Spacer()
                }
                .animation(.spring(), value: isPresented)
            }
        }
    }
}

// Расширение для удобного использования модификатора
extension View {
    func banner(isPresented: Binding<Bool>, data: BannerData, autoDismiss: Bool = true, dismissDelay: TimeInterval = 2.0) -> some View {
        self.modifier(
            BannerModifier(
                isPresented: isPresented,
                data: data,
                autoDismiss: autoDismiss,
                dismissDelay: dismissDelay
            )
        )
    }
}

// Предварительный просмотр
struct BannerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            BannerView(
                isPresented: .constant(true),
                data: BannerData(
                    title: "Success",
                    detail: "Your item has been added successfully",
                    type: .success
                )
            )
            
            BannerView(
                isPresented: .constant(true),
                data: BannerData(
                    title: "Error",
                    detail: "Something went wrong",
                    type: .error
                )
            )
            
            BannerView(
                isPresented: .constant(true),
                data: BannerData(
                    title: "Warning",
                    detail: "This is a warning message",
                    type: .warning
                )
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 