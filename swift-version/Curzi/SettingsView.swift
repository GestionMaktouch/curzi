import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var store = Store()

    var body: some View {
        List {
            Section {
                if store.supporter {
                    Text("You support Curzi. Thank you!")
                } else {
                    Button(store.buying ? "Buying…" : "Support Curzi · \(store.price)") { Task { await store.buy() } }
                        .disabled(store.buying || store.product == nil)
                }
                Button("Restore Purchases") { Task { await store.restore() } }
            } header: { Text("Support") } footer: {
                Text(store.note ?? "Curzi is free. One payment, no subscription, says thanks and keeps it that way.")
            }
            Section {
                Toggle("Show decimals", isOn: $model.decimals)
            } header: { Text("Display") } footer: {
                Text(model.decimals ? "Amounts to the cent." : "Amounts rounded to whole units.")
            }
            Section {
                LabeledContent("Source", value: "Exchange Rate API")
                if model.ratesFailed && model.feed == nil {
                    Button("Try Again") { Task { await model.loadRates() } }
                }
            } header: { Text("Rates") } footer: { Text(model.ratesNote) }
            Section("About") { LabeledContent("Curzi", value: "The old XE feel.") }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
    }
}

/// The one-time "support" purchase through StoreKit 2.
@MainActor
final class Store: ObservableObject {
    static let itemID = "support"
    @Published var product: Product?
    @Published var supporter = false
    @Published var buying = false
    @Published var note: String?

    var price: String { product?.displayPrice ?? "$2.99" }

    func load() async {
        product = try? await Product.products(for: [Self.itemID]).first
        await refreshEntitlement()
        // Finish anything the store delivered while the app was away.
        for await result in Transaction.unfinished {
            if case .verified(let t) = result { await t.finish() }
        }
    }

    func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.itemID, t.revocationDate == nil { supporter = true }
        }
    }

    func buy() async {
        guard let product else { return }
        buying = true; defer { buying = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                if case .verified(let t) = result { await t.finish() }
                supporter = true
                note = "Thank you for supporting Curzi!"
            case .pending: note = "Waiting for approval."
            case .userCancelled: break
            @unknown default: break
            }
        } catch {
            note = "The purchase didn’t go through. Try again."
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }
}
