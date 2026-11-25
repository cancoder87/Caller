import SwiftUI
import Foundation

private let accent = Color(red: 0.02, green: 0.48, blue: 0.41)

struct ContentView: View {
    @Environment(\.openURL) private var openURL
    @State private var tab: CallerTab = .favorites
    @State private var favorites: Set<String> = ["anna", "max"]
    @State private var selectedContact: CallerContact?
    @State private var number = ""
    @State private var query = ""
    @State private var missedOnly = false
    @State private var callUnavailable = false

    var body: some View {
        TabView(selection: $tab) {
            Tab("Избранное", systemImage: "star.fill", value: .favorites) {
                NavigationStack { favoritesScreen.navigationTitle("Избранное") }
            }
            Tab("Недавние", systemImage: "clock", value: .recents) {
                NavigationStack { recentsScreen.navigationTitle("Недавние") }
            }
            Tab("Контакты", systemImage: "person.crop.circle", value: .contacts) {
                NavigationStack { contactsScreen.navigationTitle("Контакты") }
            }
            Tab("Клавиатура", systemImage: "circle.grid.3x3.fill", value: .keypad) {
                NavigationStack { keypadScreen.navigationTitle("Клавиатура") }
            }
        }
        .tint(accent)
        .sheet(item: $selectedContact) { contact in
            NavigationStack {
                List {
                    Section {
                        VStack(spacing: 12) {
                            avatar(contact, size: 72)
                            Text(contact.name).font(.title2.weight(.semibold))
                            Text(contact.number).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    Section {
                        Button {
                            number = contact.number.filter { $0.isASCII && ($0.isNumber || $0 == "+") }
                            selectedContact = nil
                            tab = .keypad
                        } label: {
                            Label("Открыть в клавиатуре", systemImage: "circle.grid.3x3.fill")
                        }
                        Button {
                            if favorites.contains(contact.id) {
                                favorites.remove(contact.id)
                            } else {
                                favorites.insert(contact.id)
                            }
                        } label: {
                            if favorites.contains(contact.id) {
                                Label("Убрать из избранного", systemImage: "star.slash")
                            } else {
                                Label("Добавить в избранное", systemImage: "star")
                            }
                        }
                    }
                }
                .navigationTitle("Контакт")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") { selectedContact = nil }
                    }
                }
            }
            .tint(accent)
        }
        .alert("Вызов недоступен", isPresented: $callUnavailable) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text("Этот номер нельзя набрать на данном устройстве.")
        }
    }

    private var favoritesScreen: some View {
        let people = CallerContact.samples.filter { favorites.contains($0.id) }
        return ScrollView {
            if people.isEmpty {
                ContentUnavailableView {
                    Label("Нет избранных контактов", systemImage: "star")
                } actions: {
                    Button("Открыть контакты") { tab = .contacts }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
                    ForEach(people) { contact in
                        Button {
                            selectedContact = contact
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                avatar(contact, size: 48)
                                Text(contact.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Text("Мобильный")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(.background, in: RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { tab = .contacts } label: {
                    Label("Выбрать контакт", systemImage: "plus")
                }
            }
        }
    }

    private var recentsScreen: some View {
        List {
            Section {
                Picker("Фильтр звонков", selection: $missedOnly) {
                    Text("Все").tag(false)
                    Text("Пропущенные").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            Section("Сегодня") {
                ForEach(RecentCall.samples.filter { !missedOnly || $0.kind == .missed }) { call in
                    contactButton(call.contact) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(call.contact.name).font(.headline)
                            Label(call.kind.title, systemImage: call.kind.icon)
                                .font(.subheadline)
                                .foregroundStyle(call.kind == .missed ? Color.red : Color.secondary)
                        }
                        Spacer()
                        Text(call.time).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var contactsScreen: some View {
        let people = CallerContact.samples.filter {
            query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.number.contains(query)
        }.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        return List {
            ForEach(Set(people.map(\.initial)).sorted(), id: \.self) { initial in
                Section(initial) {
                    ForEach(people.filter { $0.initial == initial }) { contact in
                        contactButton(contact) {
                            Text(contact.name)
                            Spacer()
                            if favorites.contains(contact.id) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(accent)
                                    .accessibilityLabel("В избранном")
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Имя или номер")
        .overlay {
            if people.isEmpty { ContentUnavailableView.search(text: query) }
        }
    }

    private func contactButton<LabelContent: View>(
        _ contact: CallerContact,
        @ViewBuilder label: () -> LabelContent
    ) -> some View {
        Button {
            selectedContact = contact
        } label: {
            HStack(spacing: 12) {
                avatar(contact, size: 40)
                label()
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }

    private func avatar(_ contact: CallerContact, size: CGFloat) -> some View {
        Text(contact.initials)
            .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
            .foregroundStyle(contact.color)
            .frame(width: size, height: size)
            .background(contact.color.opacity(0.12), in: Circle())
            .accessibilityHidden(true)
    }

    private var keypadScreen: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text(number.isEmpty ? "Введите номер" : number)
                    .font(number.isEmpty ? .title3 : .largeTitle.weight(.medium))
                    .foregroundStyle(number.isEmpty ? .secondary : .primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .frame(maxWidth: .infinity, minHeight: 66)
                    .textSelection(.enabled)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 10) {
                    ForEach(DialKey.all) { key in
                        Button {
                            number.append(key.symbol)
                        } label: {
                            VStack(spacing: 1) {
                                Text(key.symbol).font(.system(.largeTitle, design: .rounded))
                                if !key.caption.isEmpty {
                                    Text(key.caption).font(.caption2.weight(.semibold)).tracking(1)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 62)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(key.accessibilityName)
                        .accessibilityAction(named: Text("Вставить плюс")) {
                            if key.symbol == "0" && number.isEmpty { number = "+" }
                        }
                        .modifier(PlusGesture(enabled: key.symbol == "0" && number.isEmpty) { number = "+" })
                    }

                    Color.clear.frame(height: 58).accessibilityHidden(true)
                    Button(action: callNumber) {
                        Image(systemName: "phone.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(accent, in: Capsule())
                            .opacity(canCall ? 1 : 0.45)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCall)
                    .accessibilityLabel("Позвонить")

                    Button {
                        if !number.isEmpty { number.removeLast() }
                    } label: {
                        Image(systemName: "delete.left")
                            .font(.title2)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(number.isEmpty)
                    .opacity(number.isEmpty ? 0 : 1)
                    .accessibilityHidden(number.isEmpty)
                    .accessibilityLabel("Удалить последний символ")
                }
            }
            .frame(maxWidth: 330)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    // The system handles telephone calls. Star and hash stay on the keypad because tel URLs cannot dial them.
    private var canCall: Bool {
        number.contains(where: \.isNumber) && !number.contains("*") && !number.contains("#")
    }

    private func callNumber() {
        guard canCall, let url = URL(string: "tel:\(number)") else { return }
        openURL(url) { accepted in callUnavailable = !accepted }
    }
}

private struct PlusGesture: ViewModifier {
    let enabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.highPriorityGesture(LongPressGesture().onEnded { _ in action() })
        } else {
            content
        }
    }
}

private enum CallerTab: Hashable {
    case favorites, recents, contacts, keypad
}

private struct CallerContact: Identifiable {
    let id: String
    let name: String
    let number: String
    let color: Color

    var initial: String { String(name.prefix(1)) }
    var initials: String { name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined() }

    // Reserved fictional numbers keep the sample screens independent of personal device data.
    static let anna = Self(id: "anna", name: "Анна Смирнова", number: "+1 (202) 555-0101", color: accent)
    static let vera = Self(id: "vera", name: "Вера Иванова", number: "+1 (202) 555-0102", color: .purple)
    static let max = Self(id: "max", name: "Максим Волков", number: "+1 (202) 555-0103", color: .blue)
    static let olga = Self(id: "olga", name: "Ольга Ким", number: "+1 (202) 555-0104", color: .pink)
    static let samples = [anna, vera, max, olga]
}

private struct RecentCall: Identifiable {
    enum Kind {
        case incoming, outgoing, missed

        var title: String {
            switch self {
            case .incoming: "Входящий"
            case .outgoing: "Исходящий"
            case .missed: "Пропущенный"
            }
        }

        var icon: String {
            switch self {
            case .incoming: "arrow.down.left"
            case .outgoing: "arrow.up.right"
            case .missed: "phone.down"
            }
        }
    }

    let id: Int
    let contact: CallerContact
    let time: String
    let kind: Kind

    static let samples = [
        Self(id: 1, contact: .vera, time: "12:48", kind: .missed),
        Self(id: 2, contact: .anna, time: "11:26", kind: .outgoing),
        Self(id: 3, contact: .max, time: "10:05", kind: .incoming),
        Self(id: 4, contact: .olga, time: "09:41", kind: .incoming)
    ]
}

private struct DialKey: Identifiable {
    let symbol: String
    let caption: String

    var id: String { symbol }
    var accessibilityName: String {
        switch symbol {
        case "*": "Звёздочка"
        case "#": "Решётка"
        default: symbol
        }
    }

    static let all = [
        ("1", ""), ("2", "ABC"), ("3", "DEF"),
        ("4", "GHI"), ("5", "JKL"), ("6", "MNO"),
        ("7", "PQRS"), ("8", "TUV"), ("9", "WXYZ"),
        ("*", ""), ("0", "+"), ("#", "")
    ].map { Self(symbol: $0.0, caption: $0.1) }
}

#Preview {
    ContentView()
}
