import SwiftUI

struct FoodSearchResultView: View {
    let result: StageMealResult
    var onSendToShortcuts: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(result.mealName ?? "Tulos")
                .font(.title2.bold())

            HStack(spacing: 16) {
                macroCard("Carbs", result.analysis.totals.carbs_g)
                macroCard("Protein", result.analysis.totals.protein_g)
                macroCard("Fat", result.analysis.totals.fat_g)
            }

            Button {
                onSendToShortcuts()
            } label: {
                Label("Lähetä iAPS (Shortcut)", systemImage: "bolt")
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationTitle("Tulos")
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
