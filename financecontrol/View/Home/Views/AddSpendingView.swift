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
        case amount
        case place
        case comment
    }

    @FocusState
    private var focusedField: Field?

    @State private var selectedTab: Int = 0
    @State private var showPlace: Bool = false
    @State private var showNote: Bool = false
    @State private var hideContent: Bool = false
    @State private var showCurrencySelector: Bool = false

    private let utils = InputUtils.shared

    private var filteredCategories: [CategoryEntity] {
        categories.filter { selectedTab == 0 ? !$0.isIncome : $0.isIncome }
    }

    private var currencySymbol: String {
        let locale = Locale(identifier: Locale.identifier(fromComponents: [NSLocale.Key.currencyCode.rawValue: vm.currency]))
        return locale.currencySymbol ?? vm.currency
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

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // -- TOP BAR --
                topBar

                // -- AMOUNT DISPLAY --
                Spacer()
                amountDisplay
                Spacer()

                // -- CATEGORY GRID PANEL --
                categoryPanel
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
            .addKeyboardToolbar(showToolbar: focusedField != nil) {
                focusedField = nil
            }
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
        .onAppear {
            focusedField = .amount
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }

            Spacer()

            DatePicker("", selection: $vm.date, in: .firstAvailableDate...Date.now, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)

            Menu {
                Button {
                    withAnimation {
                        showPlace.toggle()
                    }
                } label: {
                    Label(showPlace ? "Hide Place" : "Add Place", systemImage: showPlace ? "mappin.slash" : "mappin.and.ellipse")
                }

                Button {
                    withAnimation {
                        showNote.toggle()
                    }
                } label: {
                    Label(showNote ? "Hide Note" : "Add Note", systemImage: showNote ? "text.badge.minus" : "text.badge.plus")
                }

                Divider()

                Button {
                    showCurrencySelector = true
                } label: {
                    Label("Currency: \(vm.currency)", systemImage: "coloncurrencysign.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
            }

            // Hidden NavigationLinks for navigation destinations
            .background {
                Group {
                    NavigationLink(isActive: $showCurrencySelector) {
                        OtherCurrencySelector(selectedCurrency: $vm.currency)
                    } label: {
                        EmptyView()
                    }
                }
                .disabled(true)
                .opacity(0)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Amount Display

    private var amountDisplay: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(currencySymbol)
                    .font(.system(size: 36, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                TextField("0", text: $vm.amount)
                    .currencyFormatted($vm.amount, currencyCode: vm.currency)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .focused($focusedField, equals: .amount)

                Button {
                    if !vm.amount.isEmpty {
                        vm.amount.removeLast()
                    }
                } label: {
                    Image(systemName: "delete.backward")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }
                .opacity(vm.amount.isEmpty ? 0 : 1)
            }
            .padding(.horizontal, 24)

            if showPlace {
                TextField("Place", text: $vm.place)
                    .font(.subheadline)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)
                    .focused($focusedField, equals: .place)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if showNote {
                TextField("Add a note...", text: $vm.comment)
                    .font(.subheadline)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)
                    .focused($focusedField, equals: .comment)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Category Panel

    private var categoryPanel: some View {
        VStack(spacing: 12) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            // Expense/Income toggle + Edit button
            HStack {
                Picker("", selection: $selectedTab) {
                    Text("Expenses").tag(0)
                    Text("Income").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)

                Spacer()

                NavigationLink {
                    CategoriesEditView()
                } label: {
                    Image(systemName: "pencil")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)

            // Category grid
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(filteredCategories) { category in
                        categoryTile(for: category)
                            .onTapGesture {
                                onCategoryTap(category)
                            }
                    }

                    addNewTile
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .ignoresSafeArea(edges: .bottom)
        )
        .animation(.default, value: selectedTab)
    }

    // MARK: - Category Tile

    @ViewBuilder
    private func categoryTile(for category: CategoryEntity) -> some View {
        let name = category.name ?? "Unknown"
        let emoji = extractEmoji(from: name)
        let label = extractName(from: name)
        let isSelected = vm.selectedCategory?.id == category.id

        VStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 30))
            Text(label)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: isSelected ? .systemGray3 : .tertiarySystemGroupedBackground))
        )
    }

    // MARK: - Add New Tile

    private var addNewTile: some View {
        NavigationLink {
            AddCategoryView(
                selectedCategory: $vm.selectedCategory,
                insert: true,
                colors: usedColors,
                unusedColors: unusedColors,
                oklch: OKLCH(lightness: colorScheme.colorLightness, chroma: CategoryColorValues.chroma),
                isIncome: selectedTab == 1
            )
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Text("Add new")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundStyle(.secondary.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Functions

extension AddSpendingView {
    private func onCategoryTap(_ category: CategoryEntity) {
        focusedField = nil

        let amountString = vm.amount.isEmpty ? "0" : vm.amount
        guard let number = NumberFormatter.standard.number(from: amountString),
              number.doubleValue > 0 else {
            HapticManager.shared.notification(.warning)
            focusedField = .amount
            return
        }

        vm.selectedCategory = category
        vm.done()
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

// MARK: - Character Extension

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
    }
}
