import Foundation
import UIKit
import SwiftUI
// Удаляем условный импорт
// #if canImport(GoogleSignIn)
// import GoogleSignIn
// #endif

// Helper for Google Sign-In URL handling that works with the main AppDelegate
class GoogleSignInURLHandler: NSObject {
    static let shared = GoogleSignInURLHandler()
    
    func handleURL(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("GoogleSignInURLHandler: Обработка URL \(url)")
        
        // Используем нашу мок-реализацию для обработки URL
        return MyGSignIn.shared.handle(url)
    }
} 