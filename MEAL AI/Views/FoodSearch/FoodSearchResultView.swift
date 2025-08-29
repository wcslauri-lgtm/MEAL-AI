import SwiftUI

struct FoodSearchResultView: View {
    let result: StageMealResult
    var onAddFavorite: (String) -> Void

    @State private var favName: String = ""
    @State private var showFavSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(result.mealName ?? "Tulos")
                .font(.title2.bold())

            HStack(spacing: 16) {
                macroCard("Carbs", result.analysis.totals.carbs_g)
                macroCard("Protein", result.analysis.totals.protein_g)
                macroCard("Fat", result.analysis.totals.fat_g)
            }

            HStack {
                Button {
                    favName = result.mealName ?? "Suosikki"
                    showFavSheet = true
                } label: {
                    Label("Lisää suosikkeihin", systemImage: "star")
                }
                .buttonStyle(.bordered)

                Button {
                    ShortcutsSender.sendToShortcuts(stage: result)
                } label: {
                    Label("Lähetä iAPS (Shortcut)", systemImage: "bolt")
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Tulos")
        .sheet(isPresented: $showFavSheet) {
            NavigationStack {
                Form {
                    TextField("Suosikin nimi", text: $favName)
                }
                .navigationTitle("Suosikki")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Tallenna") {
                            onAddFavorite(favName)
                            showFavSheet = false
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Peruuta") { showFavSheet = false }
                    }
                }
            }
        }
    }

    private func macroCard(_ title: String, _ value: Double) -> some View {
        VStack {
            Text(title).font(.headline)
            Text("\(Int(value.rounded())) g").font(.title3.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
