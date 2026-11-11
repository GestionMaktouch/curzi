import Foundation

struct Currency: Identifiable, Hashable {
    let code: String
    let name: String
    let flag: String
    var id: String { code }
}

/// What the rate feed answered, kept on disk for offline use.
struct RatesFeed: Codable {
    let date: String
    let updatedAt: Date
    let rates: [String: Double]
}

/// What a typed expression comes to. `5×100÷7` → 71.43: + − × ÷ % with the usual
/// precedence, left to right. A trailing operator or point is ignored while typing.
enum Expression {
    struct Result { let value: Double; let ok: Bool }

    static func evaluate(_ expr: String) -> Result {
        var s = expr
            .replacingOccurrences(of: "[×xX*]", with: "*", options: .regularExpression)
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "[−–]", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "[,\\s]", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "[+\\-*/%.]+$", with: "", options: .regularExpression)
        if s.isEmpty { return Result(value: 0, ok: true) }

        let regex = try! NSRegularExpression(pattern: "\\d*\\.?\\d+|[+\\-*/%]")
        let tokens = regex.matches(in: s, range: NSRange(s.startIndex..., in: s))
            .map { String(s[Range($0.range, in: s)!]) }
        guard tokens.joined() == s else { return Result(value: 0, ok: false) }

        var values: [Double] = [], ops: [Character] = []
        func rank(_ op: Character) -> Int { op == "+" || op == "-" ? 1 : 2 }
        func apply() -> Bool {
            guard let op = ops.popLast(), let b = values.popLast(), let a = values.popLast() else { return false }
            switch op {
            case "+": values.append(a + b)
            case "-": values.append(a - b)
            case "*": values.append(a * b)
            case "/": values.append(a / b)
            default: values.append(a.truncatingRemainder(dividingBy: b))
            }
            return true
        }
        var expectNumber = true
        for t in tokens {
            if t.count == 1, let op = t.first, "+-*/%".contains(op) {
                if expectNumber { return Result(value: 0, ok: false) }
                while let last = ops.last, rank(last) >= rank(op) { if !apply() { return Result(value: 0, ok: false) } }
                ops.append(op)
                expectNumber = true
            } else {
                if !expectNumber { return Result(value: 0, ok: false) }
                values.append(Double(t) ?? 0)
                expectNumber = false
            }
        }
        if expectNumber { return Result(value: 0, ok: false) }
        while !ops.isEmpty { if !apply() { return Result(value: 0, ok: false) } }
        let value = values.first ?? 0
        return value.isFinite ? Result(value: value, ok: true) : Result(value: 0, ok: false)
    }
}

enum Format {
    /// Grouped to the cent (1,234.57); four places under one unit; a whole number with decimals off.
    static func money(_ n: Double, decimals: Bool) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        if !decimals {
            f.maximumFractionDigits = 0
        } else if n >= 1 || n == 0 {
            f.minimumFractionDigits = 2; f.maximumFractionDigits = 2
        } else {
            f.minimumFractionDigits = 4; f.maximumFractionDigits = 4
        }
        return f.string(from: NSNumber(value: n)) ?? ""
    }

    /// The text you edit: exact, ungrouped.
    static func plain(_ n: Double, decimals: Bool) -> String {
        if !decimals { return String(Int(n.rounded())) }
        return n >= 1 || n == 0 ? String(format: "%.2f", n) : String(format: "%.4f", n)
    }

    static func rate(_ n: Double) -> String { String(format: "%.4f", n) }

    /// "just now", "5 minutes ago", "3 hours ago", "2 days ago".
    static func ago(_ interval: TimeInterval) -> String {
        let s = max(0, interval)
        func unit(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s") ago" }
        if s < 60 { return "just now" }
        if s < 3600 { return unit(Int(s / 60), "minute") }
        if s < 86400 { return unit(Int(s / 3600), "hour") }
        return unit(Int(s / 86400), "day")
    }
}
