import Foundation

final class USDAService {
    static let shared = USDAService()
    private init() {}

    func fetchFood(query: String) async throws -> USDABaseInfo {
        guard let apiKey = UserDefaults.standard.usdaApiKey, !apiKey.isEmpty else {
            return USDABaseInfo(name: query, carbs: nil, protein: nil, fat: nil)
        }
        var comps = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        comps.queryItems = [
            .init(name: "api_key", value: apiKey),
            .init(name: "query", value: query),
            .init(name: "pageSize", value: "1")
        ]
        let (data, resp) = try await URLSession.shared.data(from: comps.url!)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return USDABaseInfo(name: query, carbs: nil, protein: nil, fat: nil)
        }
        let decoded = try JSONDecoder().decode(FDCSearchResponse.self, from: data)
        guard let first = decoded.foods?.first else {
            return USDABaseInfo(name: query, carbs: nil, protein: nil, fat: nil)
        }
        func pick(_ name: String) -> Double? {
            return first.foodNutrients?.first { ($0.nutrientName ?? "").lowercased().contains(name) }?.value
        }
        let carbs  = pick("carbohydrate") ?? pick("carbohydrates")
        let protein = pick("protein")
        let fat     = pick("fat")
        let name = (first.description ?? query).capitalized
        return USDABaseInfo(name: name, carbs: carbs, protein: protein, fat: fat)
    }
}
