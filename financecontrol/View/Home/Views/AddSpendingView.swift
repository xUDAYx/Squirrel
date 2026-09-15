//
//  AddSpendingView.swift
//  Squirrel
//
//  Created by PinkXaciD on 2022/06/27.
//

import SwiftUI
import Beige

struct AddSpendingView: View {
    init(
        ratesViewModel rvm: RatesViewModel,
        codeDataModel cdm: CoreDataModel
    ) {
        self._vm = StateObject(
            wrappedValue: AddSpendingViewModel(
                ratesViewModel: rvm,
                coreDataModel: cdm,
                places: cdm.places
            )
        )
    }

    @StateObject
    private var vm: AddSpendingViewModel

    @AppStorage(UDKey.color.rawValue)
    private var tint: String = "Orange"
    @AppStorage(UDKey.privacyScreen.rawValue)
    private var privacyScreenIsEnabled: Bool = false

    @FetchRequest(sortDescriptors: [SortDescriptor(\CategoryEntity.name)], predicate: NSPredicate(format: "isShadowed == false"))
    private var categories: FetchedResults<CategoryEntity>

    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.colorScheme)
    private var colorScheme
    @Environment(\.colorSchemeContrast)
    private var colorSchemeContrast
    @Environment(\.scenePhase)
    private var scenePhase

    private enum Field {
        case place
        case comment
    }

    @FocusState
    private var focusedField: Field?

    @State private var selectedTab: Int = 0
    @State private var showPlace: Bool = false
    @State private var showNote: Bool = false
    @State private var hideContent: Bool = false
    @State private var showAddCategory: Bool = false
    @State private var showOtherCategory: Bool = false

    private let utils = InputUtils.shared

    // MARK: - Computed Properties

    private var filteredCategories: [CategoryEntity] {
        categories.filter { selectedTab == 0 ? !$0.isIncome : $0.isIncome }
    }

    private var filteredFavorites: [CategoryEntity] {
        filteredCategories.filter { $0.isFavorite }
    }

    private var currencySymbol: String {
        let locale = Locale(identifier: Locale.identifier(fromComponents: [NSLocale.Key.currencyCode.rawValue: vm.currency]))
        return locale.currencySymbol ?? vm.currency
    }

    private var decimalSeparator: String {
        Locale.current.decimalSeparator ?? "."
    }

    private var maxFractionDigits: Int {
        Currency(code: vm.currency).fractionDigits
    }

    var usedColors: [OKLCH] {
        var result = Set<OKLCH>()
        for category in categories {
            result.insert(category.resolveColor(colorScheme: colorScheme, increaseContrast: colorSchemeContrast).oklch())
        }
        return result.sorted { $0.h < $1.h }
    }

    private var unusedColors: [Double] {
        if usedColors.isEmpty { return [] }
        var lastHue: Double = 0
        var result: [Double] = []
        for color in usedColors {
            guard color.h != lastHue, color.h - lastHue > 5 else { continue }
            result.append((color.h - lastHue) / 2 + lastHue)
            lastHue = color.h
        }
        if lastHue <= 355, !result.isEmpty {
            result.append((360 - lastHue) / 2 + lastHue)
        }
        return result
    }

    private var displayAmount: String {
        if vm.amount.isEmpty {
            return "\(currencySymbol)0"
        }
        return "\(currencySymbol)\(vm.amount)"
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }
        var dates: [Date] = []
        var current = weekInterval.start
        while current < weekInterval.end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                topBar
                    .padding(.top, 8)
                    .padding(.horizontal, 16)

                weekStrip
                    .padding(.top, 20)
                    .padding(.horizontal, 16)

                Spacer(minLength: 12)

                amountSection

                Spacer(minLength: 12)

                numberPad
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .tint(colorIdentifier(color: tint))
        .accentColor(colorIdentifier(color: tint))
        .interactiveDismissDisabled(!vm.amount.isEmpty)
        .blur(radius: hideContent ? Vars.privacyBlur : 0)
        .onChange(of: scenePhase) { value in
            if privacyScreenIsEnabled {
                if value == .active {
                    withAnimation(.easeOut(duration: 0.2)) {
                        hideContent = false
                    }
                } else {
                    withAnimation {
                        hideContent = true
                    }
                }
            }
        }
        .onChange(of: vm.dismiss) { newValue in
            if newValue {
                dismiss()
            }
        }
        .onChange(of: selectedTab) { _ in
            if let current = vm.selectedCategory,
               (selectedTab == 0 && current.isIncome) || (selectedTab == 1 && !current.isIncome) {
                vm.selectedCategory = filteredCategories.first
            }
        }
        .onAppear {
            if vm.selectedCategory == nil {
                vm.selectedCategory = filteredCategories.first
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.bold())
                    .foregroundStyle(.primary)
            }

            Spacer()

            HStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = 0
                    }
                } label: {
                    Text("Expense")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(selectedTab == 0 ? Color(uiColor: .systemBackground) : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedTab == 0 ? Color(uiColor: .label) : Color.clear)
                        )
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = 1
                    }
                } label: {
                    Text("Income")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(selectedTab == 1 ? Color(uiColor: .systemBackground) : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedTab == 1 ? Color(uiColor: .label) : Color.clear)
                        )
                }
            }
            .background(Capsule().fill(Color(uiColor: .systemGray6)))

            Spacer()

            // Invisible spacer to balance the X button
            Color.clear
                .frame(width: 24, height: 24)
        }
    }

    // MARK: - Week Strip

    private var weekStrip: some View {
        let calendar = Calendar.current
        let today = Date()

        return HStack(spacing: 0) {
            ForEach(weekDates, id: \.self) { date in
                let dayName = date.formatted(.dateTime.weekday(.abbreviated))
                let dayNumber = calendar.component(.day, from: date)
                let isSelected = calendar.isDate(date, inSameDayAs: vm.date)
                let isToday = calendar.isDateInToday(date)
                let isFuture = date > today && !isToday

                VStack(spacing: 4) {
                    Text(dayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    ZStack {
                        if isSelected {
                            Circle()
                                .fill(Color(uiColor: .label))
                                .frame(width: 36, height: 36)
                        }

                        Text("\(dayNumber)")
                            .font(.callout.weight(.medium))
                            .foregroundColor(
                                isSelected
                                    ? Color(uiColor: .systemBackground)
                                    : (isFuture ? .secondary.opacity(0.4) : .primary)
                            )
                    }
                    .frame(width: 36, height: 36)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isFuture {
                        selectDate(date)
                    }
                }
                .opacity(isFuture ? 0.5 : 1)
            }
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(spacing: 0) {
            amountDisplay

            categoryPill
                .padding(.top, 12)

            if showPlace || showNote {
                optionalFields
                    .padding(.top, 8)
                    .padding(.horizontal, 24)
            }

            actionButtonsRow
                .padding(.top, 12)
        }
        .animation(.default, value: showPlace)
        .animation(.default, value: showNote)
    }

    // MARK: - Amount Display

    private var amountDisplay: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(displayAmount)
                .font(.system(size: 58, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            if value.translation.width < -20 {
                                withAnimation { deleteLast() }
                            }
                        }
                )

            if !vm.amount.isEmpty {
                Button {
                    withAnimation { deleteLast() }
                } label: {
                    Image(systemName: "delete.backward")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
        .animation(.default, value: vm.amount.isEmpty)
    }

    // MARK: - Category Pill

    private var categoryPill: some View {
        let categoryName: String = {
            if let name = vm.selectedCategory?.name {
                return extractName(from: name)
            }
            return "Select Category"
        }()

        let emoji: String = {
            if let name = vm.selectedCategory?.name {
                return extractEmoji(from: name)
            }
            return "\u{1F4C1}"
        }()

        return Menu {
            if filteredFavorites.isEmpty {
                if #available(iOS 16.0, *) {
                    Button {} label: {
                        Text("Your favorite categories will be shown here")
                        Text("You can add category to favorites from settings.")
                    }
                } else {
                    Text("No favorite categories.")
                }
            } else {
                ForEach(filteredFavorites) { category in
                    Button {
                        vm.selectedCategory = category
                    } label: {
                        Text(category.name ?? "Unknown")
                    }
                }
            }

            Divider()

            Button {
                showOtherCategory = true
            } label: {
                Label("Other", systemImage: "list.bullet")
            }

            Divider()

            Button {
                showAddCategory = true
            } label: {
                Label("Add new", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 6) {
                Text(emoji)
                Text(categoryName)
                    .fontWeight(.bold)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .stroke(Color(uiColor: .systemGray4), lineWidth: 1.5)
            )
        }
        .background {
            Group {
                NavigationLink(isActive: $showAddCategory) {
                    AddCategoryView(
                        selectedCategory: $vm.selectedCategory,
                        insert: true,
                        colors: usedColors,
                        unusedColors: unusedColors,
                        oklch: OKLCH(lightness: colorScheme.colorLightness, chroma: CategoryColorValues.chroma),
                        isIncome: selectedTab == 1
                    )
                } label: {
                    EmptyView()
                }

                NavigationLink(isActive: $showOtherCategory) {
                    AddSpendingOtherCategoryList(
                        selectedCategory: $vm.selectedCategory,
                        categories: filteredCategories,
                        usedColors: usedColors,
                        unusedColors: unusedColors,
                        colorScheme: colorScheme,
                        isIncome: selectedTab == 1
                    )
                } label: {
                    EmptyView()
                }
            }
            .disabled(true)
            .opacity(0)
        }
    }

    // MARK: - Optional Fields

    private var optionalFields: some View {
        VStack(spacing: 8) {
            if showPlace {
                TextField("Place", text: $vm.place)
                    .font(.subheadline)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .place)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if showNote {
                TextField("Add a note...", text: $vm.comment)
                    .font(.subheadline)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .comment)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Action Buttons Row

    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation {
                    showPlace.toggle()
                    if showPlace {
                        focusedField = .place
                    } else {
                        focusedField = nil
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showPlace ? "mappin.slash" : "mappin")
                        .font(.caption)
                    Text(showPlace ? "Hide place" : "Add place")
                        .font(.subheadline)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(uiColor: .systemGray6))
                )
            }

            Button {
                withAnimation {
                    showNote.toggle()
                    if showNote {
                        focusedField = .comment
                    } else {
                        focusedField = nil
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showNote ? "doc.badge.minus" : "doc.text")
                        .font(.caption)
                    Text(showNote ? "Hide note" : "Add note")
                        .font(.subheadline)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(uiColor: .systemGray6))
                )
            }
        }
    }

    // MARK: - Number Pad

    private var numberPad: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
        let keys: [String] = [
            "1", "2", "3",
            "4", "5", "6",
            "7", "8", "9",
            decimalSeparator, "0", "confirm"
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(keys, id: \.self) { key in
                numberPadButton(key)
            }
        }
    }

    @ViewBuilder
    private func numberPadButton(_ key: String) -> some View {
        Button {
            focusedField = nil
            numberPadAction(key)
        } label: {
            Group {
                if key == "confirm" {
                    Image(systemName: "checkmark")
                        .font(.title2.weight(.bold))
                        .foregroundColor(Color(uiColor: .systemBackground))
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(Circle().fill(Color(uiColor: .label)))
                } else {
                    Text(key)
                        .font(.title.weight(.medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(Circle().fill(Color(uiColor: .systemGray6)))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Functions

extension AddSpendingView {
    private func numberPadAction(_ key: String) {
        switch key {
        case "confirm":
            confirmSave()
        case decimalSeparator:
            appendDecimal()
        default:
            appendDigit(key)
        }
    }

    private func appendDigit(_ digit: String) {
        let sep = decimalSeparator
        if let sepRange = vm.amount.range(of: sep) {
            let fractionPart = vm.amount[sepRange.upperBound...]
            if fractionPart.count >= maxFractionDigits { return }
        }
        // Prevent multiple leading zeros
        if vm.amount == "0" && digit == "0" { return }
        // Replace leading zero with the typed digit
        if vm.amount == "0" {
            vm.amount = digit
            return
        }
        vm.amount.append(digit)
    }

    private func appendDecimal() {
        if maxFractionDigits == 0 { return }
        let sep = decimalSeparator
        if vm.amount.contains(sep) { return }
        if vm.amount.isEmpty { vm.amount = "0" }
        vm.amount.append(sep)
    }

    private func deleteLast() {
        if !vm.amount.isEmpty {
            vm.amount.removeLast()
        }
    }

    private func confirmSave() {
        let amountStr = vm.amount.isEmpty ? "0" : vm.amount
        guard let number = NumberFormatter.standard.number(from: amountStr),
              number.doubleValue > 0,
              vm.selectedCategory != nil else {
            HapticManager.shared.notification(.warning)
            return
        }
        vm.done()
    }

    private func selectDate(_ date: Date) {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            vm.date = Date.now
        } else {
            vm.date = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        }
    }

    private func extractEmoji(from name: String) -> String {
        guard let first = name.first, first.isEmoji else { return "\u{1F4C1}" }
        return String(first)
    }

    private func extractName(from name: String) -> String {
        let trimmed = name.drop(while: { !$0.isLetter && !$0.isNumber })
        return String(trimmed).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Other Category List

private struct AddSpendingOtherCategoryList: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var listColorScheme

    @Binding var selectedCategory: CategoryEntity?

    let categories: [CategoryEntity]
    let usedColors: [OKLCH]
    let unusedColors: [Double]
    let colorScheme: ColorScheme
    let isIncome: Bool

    @State private var search: String = ""
    @State private var showAddCategory: Bool = false

    var body: some View {
        Group {
            let searchResult = searchFunc(search)

            if searchResult.isEmpty {
                CustomContentUnavailableView.search(search.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                List {
                    ForEach(searchResult) { category in
                        Button {
                            selectedCategory = category
                            dismiss()
                        } label: {
                            HStack {
                                if let color = category.color {
                                    Image(systemName: "circle.fill")
                                        .font(.title)
                                        .foregroundColor(Color[color])
                                }

                                Text(category.name ?? "Unknown")
                                    .foregroundColor(.primary)

                                Spacer()

                                if selectedCategory?.id == category.id {
                                    Image(systemName: "checkmark")
                                        .font(.body.bold())
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }

                    Section {
                        NavigationLink(isActive: $showAddCategory) {
                            AddCategoryView(
                                selectedCategory: $selectedCategory,
                                insert: true,
                                colors: usedColors,
                                unusedColors: unusedColors,
                                oklch: OKLCH(lightness: colorScheme.colorLightness, chroma: CategoryColorValues.chroma),
                                isIncome: isIncome
                            )
                        } label: {
                            Text("Add new")
                        }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Search by name")
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func searchFunc(_ searchString: String) -> [CategoryEntity] {
        let trimmed = searchString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return categories
        }
        return categories.filter { category in
            category.name?.localizedCaseInsensitiveContains(trimmed) ?? false
        }
    }
}

// MARK: - Character Extension

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
    }
}
