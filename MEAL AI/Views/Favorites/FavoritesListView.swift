import SwiftUI

struct FavoritesListView: View {
    @ObservedObject var store = FavoritesStore.shared

    var body: some View {
        List {
            ForEach(store.items) { f in
                VStack(alignment: .leading) {
                    Text(f.name).font(.headline)
                    let t = f.result.analysis.totals
                    Text("Carbs \(Int(t.carbs_g))g · Protein \(Int(t.protein_g))g · Fat \(Int(t.fat_g))g")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .onDelete { idx in
                idx.map { store.items[$0].id }.forEach { store.remove($0) }
            }
        }
        .navigationTitle("Suosikit")
        .toolbar { EditButton() }
    }
}
