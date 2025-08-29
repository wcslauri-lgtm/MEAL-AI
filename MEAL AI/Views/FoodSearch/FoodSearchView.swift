import SwiftUI

extension StageMealResult: Identifiable {
    public var id: String { (mealName ?? "meal") + "-\(analysis.totals.carbs_g)-\(analysis.totals.protein_g)-\(analysis.totals.fat_g)" }
}

struct FoodSearchView: View {
    @State private var query: String = ""
    @State private var showingScanner = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var result: StageMealResult?

    var body: some View {
        VStack(spacing: 12) {
            TextField("Hae ruokaa nimellä…", text: $query, onCommit: runTextSearch)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            Button { showingScanner = true } label: {
                Label("Viivakoodi", systemImage: "barcode.viewfinder")
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            if isLoading { ProgressView().padding() }
            if let e = errorMessage { Text(e).foregroundColor(.red).padding(.horizontal) }

            Spacer()
        }
        .navigationTitle("Ruokahaku")
        .sheet(isPresented: $showingScanner) {
            BarcodeScanView { code in
                showingScanner = false
                Task { await runBarcode(code) }
            }
        }
        .sheet(item: $result) { r in
            NavigationStack {
                FoodSearchResultView(result: r) {
                    ShortcutsSender.sendToShortcuts(stage: r)
                }
            }
        }
    }

    private func runTextSearch() { Task { await run(.text(query)) } }
    private func runBarcode(_ code: String) async { await run(.barcode(code)) }

    private func run(_ input: FoodSearchRouter.Input) async {
        guard UserDefaults.standard.foodSearchEnabled else {
            self.errorMessage = "Food Search ei ole päällä (Asetukset → Food Search)."
            return
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let stage = try await FoodSearchRouter.shared.run(input)
            self.result = stage
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
