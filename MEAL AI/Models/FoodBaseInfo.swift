import Foundation

protocol FoodBaseInfo {
    var name: String { get }
    var carbs: Double? { get }
    var protein: Double? { get }
    var fat: Double? { get }
}
