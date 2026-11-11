import SwiftUI

/// The calculator keypad in place of the system keyboard: the iOS calculator's layout, smaller.
struct Keypad: View {
    @EnvironmentObject var model: AppModel
    private let rows: [[String]] = [["C", "⌫", "%", "÷"], ["7", "8", "9", "×"], ["4", "5", "6", "−"], ["1", "2", "3", "+"]]
    private let ops: Set<String> = ["%", "÷", "×", "−", "+"]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) { ForEach(row, id: \.self) { k in key(k) } }
            }
            HStack(spacing: 8) {
                key("0", wide: true)
                key(".")
                Key(label: "=", filled: true) { model.done() }
            }
        }
        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 8)
        .background(Color(.secondarySystemBackground))
    }

    private func key(_ k: String, wide: Bool = false) -> some View {
        Key(label: k, filled: ops.contains(k), wide: wide) { model.key(k) }
    }
}

struct Key: View {
    let label: String
    var filled = false
    var wide = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if label == "⌫" { Image(systemName: "delete.left") } else { Text(label) }
            }
            .font(.system(size: 20, weight: filled ? .semibold : .medium))
            .lineLimit(1).minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(filled ? Color.white : Color.primary)
            .background(filled ? Color.accentColor : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .layoutPriority(wide ? 2 : 1)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label == "⌫" ? "Delete" : label == "C" ? "Clear" : label)
    }
}
