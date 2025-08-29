import Foundation

struct FDCSearchResponse: Decodable {
    let foods: [FDCFood]?
}

struct FDCFood: Decodable {
    let description: String?
    let foodNutrients: [FDCNutrient]?
}

struct FDCNutrient: Decodable {
    let nutrientName: String?
    let value: Double?
    let unitName: String?
}

struct USDABaseInfo: FoodBaseInfo {
    let name: String
    let carbs: Double?
    let protein: Double?
    let fat: Double?
}
