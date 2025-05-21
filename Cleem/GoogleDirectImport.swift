import Foundation
import UIKit

// Прямые импорты для поддержки линковки Google SignIn

// Расширения для Objective-C совместимости
extension MyGSignIn {
    // Дополнительные методы для совместимости
    public class func sharedInstance() -> MyGSignIn {
        return MyGSignIn.shared
    }
}

// Дополнительные типы для адаптации Google API
public class GIDSignInButton: UIButton {
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupButton()
    }
    
    private func setupButton() {
        setTitle("Sign in with Google", for: .normal)
        backgroundColor = UIColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)
        setTitleColor(.white, for: .normal)
        layer.cornerRadius = 5.0
    }
} 