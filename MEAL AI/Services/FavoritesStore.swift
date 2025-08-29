import Foundation

struct FavoriteEntry: Identifiable, Codable {
    let id: UUID
    var name: String
    var result: StageMealResult
    var createdAt: Date
}

final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()
    @Published private(set) var items: [FavoriteEntry] = []
    private init() { load() }

    func add(name: String, result: StageMealResult) {
        items.insert(FavoriteEntry(id: UUID(), name: name, result: result, createdAt: Date()), at: 0)
        save()
    }
    func remove(_ id: UUID) { items.removeAll{ $0.id == id }; save() }

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("favorites.json")
    }()

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let arr = try? JSONDecoder().decode([FavoriteEntry].self, from: data) {
            items = arr
        }
    }
    private func save() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: fileURL) }
    }
}
