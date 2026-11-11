import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var adding = false
    @State private var settings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Curzi").font(.title.bold())
                    Spacer()
                    Button { model.keypad = false; settings = true } label: { Image(systemName: "gearshape") }
                }
                .padding(.horizontal).padding(.vertical, 8)

                ScrollViewReader { proxy in
                    List {
                        ForEach(model.rows) { currency in
                            CurrencyRow(currency: currency)
                                .id(currency.code)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                .listRowBackground(Color.clear)
                        }
                        .onMove(perform: model.move)
                        Button { model.keypad = false; adding = true } label: {
                            Label("Add another currency", systemImage: "plus").font(.subheadline)
                                .frame(maxWidth: .infinity)
                        }
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .refreshable { await model.loadRates() }
                    .onChange(of: model.keypad) {
                        if model.keypad { withAnimation { proxy.scrollTo(model.base, anchor: .center) } }
                    }
                }

                if model.keypad { Keypad() }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $adding) { AddCurrencyView() }
            .navigationDestination(isPresented: $settings) { SettingsView() }
        }
    }
}

struct CurrencyRow: View {
    @EnvironmentObject var model: AppModel
    let currency: Currency

    var body: some View {
        let editing = model.keypad && currency.code == model.base
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
            Text(currency.flag)
            Text(currency.code).fontWeight(.semibold)
            if currency.code == model.pinned { Image(systemName: "pin").foregroundStyle(.secondary) }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Button { model.begin(currency.code) } label: {
                    Text(model.shown(currency.code))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .lineLimit(1).minimumScaleFactor(0.5)
                        .foregroundStyle(editing ? (model.fresh || model.draft.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint)) : AnyShapeStyle(.primary))
                }
                .buttonStyle(.plain)
                if !model.pinned.isEmpty, currency.code != model.pinned {
                    Text("1 \(model.pinned) → \(Format.rate(model.convert(1, from: model.pinned, to: currency.code))) \(currency.code)")
                        .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(editing ? Color.accentColor : .clear, lineWidth: 2))
        .contextMenu {
            Button { model.togglePin(currency.code) } label: {
                Label(model.pinned == currency.code ? "Unpin" : "Pin", systemImage: "pin")
            }
            Button(role: .destructive) { model.remove(currency.code) } label: { Label("Delete", systemImage: "trash") }
                .disabled(model.codes.count <= 1)
        }
    }
}
