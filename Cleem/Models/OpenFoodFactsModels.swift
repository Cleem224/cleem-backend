import Foundation

// Модель ответа от OpenFoodFacts API при поиске продукта по штрихкоду
struct OpenFoodFactsResponse: Codable {
    let status: Int?
    let product: OpenFoodFactsProduct?
    let statusVerbose: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case product
        case statusVerbose = "status_verbose"
    }
}

// Модель ответа от OpenFoodFacts API при поиске продуктов по имени
struct OpenFoodFactsSearchResponse: Codable {
    let count: Int
    let page: Int?
    let pageSize: Int?
    let products: [OpenFoodFactsProduct]?
    let skip: Int?
    
    enum CodingKeys: String, CodingKey {
        case count
        case page
        case pageSize = "page_size"
        case products
        case skip
    }
}

// Модель продукта из OpenFoodFacts API
struct OpenFoodFactsProduct: Codable {
    let code: String?
    let status: Int?
    let productName: String?
    let genericName: String?
    let brands: String?
    let categories: String?
    let imageUrl: String?
    let quantity: String?
    let nutriments: OpenFoodFactsNutrients?
    let servingSize: String?
    
    enum CodingKeys: String, CodingKey {
        case code
        case status
        case productName = "product_name"
        case genericName = "generic_name"
        case brands
        case categories
        case imageUrl = "image_url"
        case quantity
        case nutriments
        case servingSize = "serving_size"
    }
}

// Модель для отображения питательных веществ из OpenFoodFacts API
struct OpenFoodFactsNutrients: Codable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let sugars100g: Double?
    let fiber100g: Double?
    let salt100g: Double?
    let sodium100g: Double?
    
    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case sugars100g = "sugars_100g"
        case fiber100g = "fiber_100g"
        case salt100g = "salt_100g"
        case sodium100g = "sodium_100g"
    }
}

