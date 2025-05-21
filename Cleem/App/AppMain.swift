import SwiftUI

@main
struct AppMain {
    static func main() {
        if #available(iOS 14.0, *) {
            // Use the SwiftUI app lifecycle
            CleemApp.main()
        } else {
            // Fallback for iOS 13
            UIApplicationMain(
                CommandLine.argc,
                CommandLine.unsafeArgv,
                nil,
                NSStringFromClass(AppDelegate.self)
            )
        }
    }
} 