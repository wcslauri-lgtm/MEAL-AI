import Foundation

struct OFFResponse: Decodable {
    let product: OFFProduct?
    let status: Int?
}

struct OFFProduct: Decodable {
    let product_name: String?
    let brands: String?
    let nutriments: OFFNutriments?
    let serving_size: String?
    let image_url: String?
}

struct OFFNutriments: Decodable {
    let carbohydrates_100g: Double?
    let proteins_100g: Double?
    let fat_100g: Double?
    let carbohydrates_serving: Double?
    let proteins_serving: Double?
    let fat_serving: Double?
}

struct OFFBaseInfo: FoodBaseInfo {
    let name: String
    let carbs: Double?
    let protein: Double?
    let fat: Double?
}
