import SwiftUI

/// Every currency not yet in the list, searchable by code or name; a tap adds it.
struct AddCurrencyView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var candidates: [Currency] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return Currencies.all.filter { c in
            !model.codes.contains(c.code) && (q.isEmpty || c.code.lowercased().contains(q) || c.name.lowercased().contains(q))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(candidates) { c in
                        Button { model.add(c.code); dismiss() } label: {
                            HStack(spacing: 10) {
                                Text(c.flag)
                                VStack(alignment: .leading) {
                                    Text(c.code).fontWeight(.semibold)
                                    Text(c.name).font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus").foregroundStyle(.tertiary)
                            }
                        }
                        .tint(.primary)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
            .navigationTitle("Add Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
