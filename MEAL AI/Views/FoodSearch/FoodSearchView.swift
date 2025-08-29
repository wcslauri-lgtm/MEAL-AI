import SwiftUI

extension StageMealResult: Identifiable {
    public var id: String { (mealName ?? "meal") + "-\(analysis.totals.carbs_g)-\(analysis.totals.protein_g)-\(analysis.totals.fat_g)" }
}

struct FoodSearchView: View {
    @State private var query: String = ""
    @State private var showingScanner = false
    @State private var showingAICamera = false
    @State private var isListening = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var result: StageMealResult?

    @ObservedObject private var favs = FavoritesStore.shared

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Hae ruokaa nimellä…", text: $query, onCommit: runTextSearch)
                    .textFieldStyle(.roundedBorder)
                Button {
                    toggleVoice()
                } label: {
                    Image(systemName: isListening ? "mic.circle.fill" : "mic.circle")
                        .font(.title2)
                }
                .help("Äänihaku")
            }.padding(.horizontal)

            HStack {
                Button { showingScanner = true } label: {
                    Label("Viivakoodi", systemImage: "barcode.viewfinder")
                }.buttonStyle(.bordered)
                Button { showingAICamera = true } label: {
                    Label("Kamera", systemImage: "camera")
                }.buttonStyle(.bordered)
                Spacer()
            }
            .padding(.horizontal)

            if isLoading { ProgressView().padding() }
            if let e = errorMessage { Text(e).foregroundColor(.red).padding(.horizontal) }

            if !favs.items.isEmpty {
                List {
                    Section("Suosikit") {
                        ForEach(favs.items) { f in
                            Button { result = f.result } label: {
                                HStack {
                                    Text(f.name)
                                    Spacer()
                                    let t = f.result.analysis.totals
                                    Text("\(Int(t.carbs_g))g C").foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else {
                Spacer()
            }
        }
        .navigationTitle("Ruokahaku")
        .sheet(isPresented: $showingScanner) {
            BarcodeScanView { code in
                showingScanner = false
                Task { await runBarcode(code) }
            }
        }
        .sheet(isPresented: $showingAICamera) {
            AICameraView { data in
                showingAICamera = false
                Task { await runImage(data) }
            }
        }
        .sheet(item: $result) { r in
            FoodSearchResultView(result: r) { favName in
                FavoritesStore.shared.add(name: favName, result: r)
            } onSendToShortcuts: {
                ShortcutsSender.sendToShortcuts(stage: r)
            }
        }
        .onDisappear { stopVoice() }
    }

    private func runTextSearch() { Task { await run(.text(query)) } }
    private func runBarcode(_ code: String) async { await run(.barcode(code)) }
    private func runImage(_ data: Data) async { await run(.image(data)) }

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

    private func toggleVoice() { if isListening { stopVoice() } else { startVoice() } }
    private func startVoice() {
        isListening = true
        Task {
            try? await VoiceSearchService.shared.authorize()
            try? VoiceSearchService.shared.start { text in self.query = text }
        }
    }
    private func stopVoice() { isListening = false; VoiceSearchService.shared.stop() }
}
