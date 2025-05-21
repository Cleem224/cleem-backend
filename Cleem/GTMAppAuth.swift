import Foundation
import UIKit

// Заглушка для библиотеки GTMAppAuth
public class GTMAppAuthWrapper {
    public static let shared = GTMAppAuthWrapper()
    
    private init() {}
    
    // Функции-заглушки
    public func authenticate() -> Bool {
        return true
    }
}

// Класс для экспорта в Objective-C
@objc(GTMAppAuthWrapper)
public class GTMAppAuthObjCWrapper: NSObject {
    @objc public static let shared = GTMAppAuthObjCWrapper()
    
    private override init() {
        super.init()
    }
    
    @objc public func authenticate() -> Bool {
        return true
    }
} 