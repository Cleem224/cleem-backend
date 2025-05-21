import SwiftUI
import AppAuth  // Добавляем импорт для AppAuth
// Если нужны другие фреймворки для Google Sign-In
import Combine // Для работы с событиями

struct GoogleSignInBridgeView: View {
    var onComplete: () -> Void
    
    var body: some View {
        // This view imports and wraps GoogleSignInView
        GoogleSignInView(onSkip: onComplete)
    }
}

struct GoogleSignInBridgeView_Previews: PreviewProvider {
    static var previews: some View {
        GoogleSignInBridgeView(onComplete: {})
    }
} 