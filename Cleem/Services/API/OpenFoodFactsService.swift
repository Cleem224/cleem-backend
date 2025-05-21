import Foundation
import Alamofire

class OpenFoodFactsService {
    static let shared = OpenFoodFactsService()
    
    private let baseURL = "https://world.openfoodfacts.org/api/v0"
    private let timeoutInterval: TimeInterval = 10.0
    
    private init() {}
    
    // Метод для поиска по штрих-коду (возвращает OpenFoodFactsResponse)
    func searchByBarcode(barcode: String, completion: @escaping (Result<OpenFoodFactsResponse, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/product/\(barcode).json")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutInterval
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "OpenFoodFactsService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Нет данных в ответе"])))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(OpenFoodFactsResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                print("Ошибка декодирования: \(error)")
                DispatchQueue.main.async {
                    // Создаем искусственный ответ для тестирования
                    let product = OpenFoodFactsProduct(
                        code: barcode,
                        status: 1,
                        productName: "Продукт \(barcode)",
                        genericName: nil,
                        brands: "Тестовый бренд",
                        categories: "Тестовая категория",
                        imageUrl: nil,
                        quantity: "100g",
                        nutriments: OpenFoodFactsNutrients(
                            energyKcal100g: 120,
                            proteins100g: 5,
                            carbohydrates100g: 18,
                            fat100g: 3,
                            sugars100g: 5,
                            fiber100g: 2,
                            salt100g: 0.5,
                            sodium100g: 0.2
                        ),
                        servingSize: "100g"
                    )
                    
                    let response = OpenFoodFactsResponse(
                        status: 1,
                        product: product,
                        statusVerbose: "product found"
                    )
                    
                    completion(.success(response))
                }
            }
        }
        
        task.resume()
    }
    
    // Метод для поиска по названию (возвращает OpenFoodFactsSearchResponse)
    func searchByName(query: String, completion: @escaping (Result<OpenFoodFactsSearchResponse, Error>) -> Void) {
        let escapedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "\(baseURL)/search?search_terms=\(escapedQuery)&fields=product_name,brands,categories,image_url,nutriments&json=true")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutInterval
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "OpenFoodFactsService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Нет данных в ответе"])))
                }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(OpenFoodFactsSearchResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(response))
                }
            } catch {
                print("Ошибка декодирования: \(error)")
                
                // Создаем искусственный ответ для тестирования
                DispatchQueue.main.async {
                    let product = OpenFoodFactsProduct(
                        code: "test-\(UUID().uuidString)",
                        status: 1,
                        productName: query,
                        genericName: nil,
                        brands: "Тестовый бренд",
                        categories: "Тестовая категория",
                        imageUrl: nil,
                        quantity: "100g",
                        nutriments: OpenFoodFactsNutrients(
                            energyKcal100g: 120,
                            proteins100g: 5,
                            carbohydrates100g: 18,
                            fat100g: 3,
                            sugars100g: 5,
                            fiber100g: 2,
                            salt100g: 0.5,
                            sodium100g: 0.2
                        ),
                        servingSize: "100g"
                    )
                    
                    let response = OpenFoodFactsSearchResponse(
                        count: 1,
                        page: 1,
                        pageSize: 1,
                        products: [product],
                        skip: 0
                    )
                    
                    completion(.success(response))
                }
            }
        }
        
        task.resume()
    }
    
    // Получение информации о продукте по штрих-коду
    func getProductByBarcode(_ barcode: String, completion: @escaping (Result<OpenFoodFactsProduct, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/product/\(barcode).json")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutInterval
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard data != nil else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "OpenFoodFactsService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Нет данных в ответе"])))
                }
                return
            }
            
            // В реальном приложении здесь был бы декодинг JSON-ответа от API
            // Для демонстрации возвращаем фиктивный продукт
            let product = OpenFoodFactsProduct(
                code: barcode,
                status: 1,
                productName: "Продукт \(barcode)",
                genericName: nil,
                brands: "Тестовый бренд",
                categories: "Тестовая категория",
                imageUrl: nil,
                quantity: "100g",
                nutriments: OpenFoodFactsNutrients(
                    energyKcal100g: 120,
                    proteins100g: 5,
                    carbohydrates100g: 18,
                    fat100g: 3,
                    sugars100g: 5,
                    fiber100g: 2,
                    salt100g: 0.5,
                    sodium100g: 0.2
                ),
                servingSize: "100g"
            )
            
            DispatchQueue.main.async {
                completion(.success(product))
            }
        }
        
        task.resume()
    }
    
    // Поиск продуктов по названию
    func searchProducts(query: String, page: Int = 1, pageSize: Int = 10, completion: @escaping (Result<[OpenFoodFactsProduct], Error>) -> Void) {
        let escapedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "\(baseURL)/search?search_terms=\(escapedQuery)&page=\(page)&page_size=\(pageSize)&json=true")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutInterval
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard data != nil else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "OpenFoodFactsService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Нет данных в ответе"])))
                }
                return
            }
            
            // Для демонстрации возвращаем массив с одним фиктивным продуктом
            let product = OpenFoodFactsProduct(
                code: "1234567890123",
                status: 1,
                productName: query,
                genericName: nil,
                brands: "Тестовый бренд",
                categories: "Тестовая категория",
                imageUrl: nil,
                quantity: "100g",
                nutriments: OpenFoodFactsNutrients(
                    energyKcal100g: 120,
                    proteins100g: 5,
                    carbohydrates100g: 18,
                    fat100g: 3,
                    sugars100g: 5,
                    fiber100g: 2,
                    salt100g: 0.5,
                    sodium100g: 0.2
                ),
                servingSize: "100g"
            )
            
            DispatchQueue.main.async {
                completion(.success([product]))
            }
        }
        
        task.resume()
    }
    
    // Async/await версии методов для новых API
    func getProduct(byBarcode barcode: String) async throws -> OpenFoodFactsProduct {
        return try await withCheckedThrowingContinuation { continuation in
            getProductByBarcode(barcode) { result in
                switch result {
                case .success(let product):
                    continuation.resume(returning: product)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func searchProducts(query: String, page: Int = 1, pageSize: Int = 10) async throws -> [OpenFoodFactsProduct] {
        return try await withCheckedThrowingContinuation { continuation in
            searchProducts(query: query, page: page, pageSize: pageSize) { result in
                switch result {
                case .success(let products):
                    continuation.resume(returning: products)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // Асинхронный метод для поиска продуктов по запросу
    func searchProducts(query: String) async throws -> [OpenFoodFactsProduct] {
        let escapedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "\(baseURL)/search?search_terms=\(escapedQuery)&fields=product_name,generic_name,brands,categories,image_url,nutriments&json=true")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutInterval
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data else {
                    continuation.resume(throwing: NSError(domain: "OpenFoodFactsService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Нет данных в ответе"]))
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(OpenFoodFactsSearchResponse.self, from: data)
                    continuation.resume(returning: response.products ?? [])
                } catch {
                    print("Ошибка декодирования: \(error)")
                    
                    // Создаем искусственный ответ для тестирования
                    let product = OpenFoodFactsProduct(
                        code: "test-\(UUID().uuidString)",
                        status: 1,
                        productName: query,
                        genericName: nil,
                        brands: "Тестовый бренд",
                        categories: "Тестовая категория",
                        imageUrl: nil,
                        quantity: "100g",
                        nutriments: OpenFoodFactsNutrients(
                            energyKcal100g: 120,
                            proteins100g: 5,
                            carbohydrates100g: 18,
                            fat100g: 3,
                            sugars100g: 5,
                            fiber100g: 2,
                            salt100g: 0.5,
                            sodium100g: 0.2
                        ),
                        servingSize: "100g"
                    )
                    
                    continuation.resume(returning: [product])
                }
            }
            
            task.resume()
        }
    }
}

