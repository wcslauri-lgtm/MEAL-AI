import UIKit

enum ShortcutsSender {
    static func sendToShortcuts(stage: StageMealResult) {
        let c = Int(stage.analysis.totals.carbs_g.rounded())
        let f = Int(stage.analysis.totals.fat_g.rounded())
        let p = Int(stage.analysis.totals.protein_g.rounded())
        guard c > 0 || f > 0 || p > 0 else { return }

        let defaults = UserDefaults.standard
        let sendJSON = defaults.bool(forKey: "shortcutSendJSON")
        let name = (defaults.string(forKey: "shortcutName") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        var comps = URLComponents()
        comps.scheme = "shortcuts"
        comps.host = "x-callback-url"
        comps.path = "/run-shortcut"
        var items: [URLQueryItem] = [
            .init(name: "name", value: name),
            .init(name: "x-success", value: "mealai://done"),
            .init(name: "x-error", value: "mealai://error")
        ]
        if sendJSON {
            let payload = ["carbs": c, "fat": f, "protein": p]
            if let data = try? JSONSerialization.data(withJSONObject: payload),
               let s = String(data: data, encoding: .utf8) {
                items.append(.init(name: "input", value: s))
            }
        }
        comps.queryItems = items
        if let url = comps.url { UIApplication.shared.open(url) }
    }
}
