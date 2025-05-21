import Foundation
import UIKit

// Заглушка для библиотеки GTMSessionFetcher
public class GTMSessionFetcherWrapper {
    public static let shared = GTMSessionFetcherWrapper()
    
    private init() {}
    
    // Функции-заглушки
    public func fetch(url: URL, completion: @escaping (Data?, Error?) -> Void) {
        // Симуляция запроса
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(nil, nil)
        }
    }
}

// Класс для экспорта в Objective-C
@objc(GTMSessionFetcherWrapper)
public class GTMSessionFetcherObjCWrapper: NSObject {
    @objc public static let shared = GTMSessionFetcherObjCWrapper()
    
    private override init() {
        super.init()
    }
    
    @objc public func fetch(url: URL, completion: @escaping (Data?, Error?) -> Void) {
        GTMSessionFetcherWrapper.shared.fetch(url: url, completion: completion)
    }
} 