import Foundation
import UIKit

// Заглушка для библиотеки Alamofire
public class Alamofire {
    public static let shared = Alamofire()
    
    private init() {}
    
    public func request(_ url: String) -> Request {
        return Request()
    }
    
    public class Request {
        public func response(completion: @escaping (Data?) -> Void) {
            // Симуляция запроса
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion(nil)
            }
        }
    }
} 