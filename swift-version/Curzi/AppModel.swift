import Foundation
import SwiftUI

/// The app's state: what the person keeps, the rates, and the keypad.
@MainActor
final class AppModel: ObservableObject {
    // Kept across launches.
    @AppStorage("codes") private var codesData = Data()
    @AppStorage("base") var base = "CAD"
    @AppStorage("draft") var draft = "100"
    @AppStorage("pinned") var pinned = ""
    @AppStorage("decimals") var decimals = true

    @Published var codes: [String] = ["USD", "EUR", "GBP", "CAD"] {
        didSet { codesData = (try? JSONEncoder().encode(codes)) ?? Data() }
    }
    @Published var feed: RatesFeed?
    @Published var stale = false
    @Published var ratesFailed = false
    @Published var loading = false
    // The keypad: open, the number shown when tapped (back if left empty), and whether the next key replaces it.
    @Published var keypad = false
    @Published var held = ""
    @Published var fresh = false
    @Published var now = Date()

    private let service = RatesService()
    private var ticker: Timer?

    init() {
        if let kept = try? JSONDecoder().decode([String].self, from: codesData), !kept.isEmpty { codes = kept }
        ticker = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
    }

    // MARK: Rates

    func loadRates() async {
        loading = true
        defer { loading = false }
        do {
            let loaded = try await service.load()
            feed = loaded.feed; stale = loaded.stale; ratesFailed = false
        } catch {
            ratesFailed = true
        }
    }

    func rate(_ code: String) -> Double { feed?.rates[code] ?? 0 }

    var evaluated: Expression.Result { Expression.evaluate(draft) }
    var amount: Double { max(0, evaluated.value) }

    func convert(_ value: Double, from: String, to: String) -> Double {
        let f = rate(from)
        return f > 0 ? value * rate(to) / f : 0
    }

    func shown(_ code: String) -> String {
        if code == base { return draft.isEmpty ? held : draft }
        return Format.money(convert(amount, from: base, to: code), decimals: decimals)
    }

    var ratesNote: String {
        guard let feed else { return ratesFailed ? "Couldn’t load rates. Pull down to try again." : "Loading rates…" }
        let age = Format.ago(now.timeIntervalSince(feed.updatedAt))
        return stale ? "Offline. Rates last updated \(age)." : "Rates last updated \(age). Mid-market rates by exchangerate-api.com."
    }

    // MARK: Currencies

    var rows: [Currency] { codes.map { code in Currencies.byCode[code] ?? Currency(code: code, name: code, flag: "🏳️") } }

    func add(_ code: String) { codes.append(code) }

    func remove(_ code: String) {
        guard codes.count > 1 else { return }
        codes.removeAll { $0 == code }
        if base == code { base = codes[0] }
        if pinned == code { pinned = "" }
    }

    func move(from: IndexSet, to: Int) { codes.move(fromOffsets: from, toOffset: to) }

    /// Pinning puts the currency first.
    func togglePin(_ code: String) {
        if pinned == code { pinned = "" } else {
            pinned = code
            codes = [code] + codes.filter { $0 != code }
        }
    }

    // MARK: Keypad

    /// Tapping an amount makes its row the base and opens the keypad; the number stays until the first key.
    func begin(_ code: String) {
        let shown = code == base ? draft : Format.plain(convert(amount, from: base, to: code), decimals: decimals)
        held = shown; draft = shown; base = code; fresh = true; keypad = true
    }

    func key(_ k: String) {
        let cur = fresh ? "" : draft
        let ops = "+−×÷%"
        let isOp = ops.contains(k), lastOp = cur.last.map { ops.contains($0) } ?? false
        fresh = false
        switch k {
        case "C": draft = ""
        case "⌫": draft = String(cur.dropLast())
        case _ where isOp && (cur.isEmpty || lastOp): draft = cur.isEmpty ? "" : String(cur.dropLast()) + k
        default: draft = cur + k
        }
    }

    func done() {
        keypad = false; fresh = false
        if draft.isEmpty { draft = held } else if evaluated.ok { draft = Format.plain(evaluated.value, decimals: decimals) }
    }
}
