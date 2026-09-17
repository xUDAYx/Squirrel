
//
//  ContentView.swift
//  financecontrol
//
//  Created by PinkXaciD on 2023/06/26.
//

import SwiftUI
import CoreData
#if DEBUG
import OSLog
#endif

struct ContentView: View {
    @Environment(\.scenePhase) 
    private var scenePhase
    @Environment(\.openURL)
    private var openURL
    
    @AppStorage(UDKey.presentOnboarding.rawValue)
    private var presentOnboarding: Bool = true
    @AppStorage(UDKey.color.rawValue)
    private var tint: String = "Orange"
    @AppStorage(UDKey.autoDarkMode.rawValue)
    private var autoDarkMode: Bool = true
    @AppStorage(UDKey.darkMode.rawValue)
    private var darkMode: Bool = false
    @AppStorage(UDKey.privacyScreen.rawValue)
    private var privacyScreenIsEnabled: Bool = false
    
    @StateObject
    private var cdm: CoreDataModel
    @StateObject
    private var rvm: RatesViewModel
    @StateObject
    private var filtersViewModel: FiltersViewModel
    @StateObject
    private var pieChartViewModel: PieChartViewModel
    @StateObject
    private var statsListViewModel: StatsListViewModel
    @StateObject
    private var statsSearchViewModel: StatsSearchViewModel
    @StateObject
    private var privacyMonitor: PrivacyMonitor = PrivacyMonitor(privacyScreenIsEnabled: false, hideExpenseSum: false)
    @StateObject
    private var statsViewModel: StatsViewModel = StatsViewModel()
    @StateObject
    private var cloudKitKVSManager: CloudKitKVSManager
    @StateObject
    private var barChartViewModel = BarChartViewModel(context: DataManager.shared.context)
    
    @ObservedObject 
    private var errorHandler = ErrorHandler.shared
    
    @State
    private var addExpenseAction: Bool = false
    @State
    private var addTransactionInitialDate: Date = .now
    @State
    private var hideContent: Bool = false
    
    private var selection: Binding<Int> {
        Binding(get: {
            self.selectionValue
        },
        set: {
            if $0 == 2 {
                if self.selectionValue != 0 {
                    self.addTransactionInitialDate = .now
                }
                self.addExpenseAction = true
                return
            }

            if $0 == selectionValue {
                // tapped twice
                self.scrollToTop = $0
                return
            }
            
            self.selectionValue = $0
        })
    }
    @State
    private var selectionValue: Int = 0
    @State
    private var scrollToTop: Int? = nil
    
    #if ICLOUD_ENABLED
    let cloudSyncWasEnabled = NSUbiquitousKeyValueStore.default.bool(forKey: UDKey.iCloudSync.rawValue)
    #else
    let cloudSyncWasEnabled = false
    #endif
    
    init() {
        let ratesViewModel = RatesViewModel()
        let cloudKitKVSManger = CloudKitKVSManager()
        let coreDataModel = CoreDataModel(isCloudSyncEnabled: cloudKitKVSManger.iCloudSync, ratesViewModel: ratesViewModel)
        let filtersViewModel = FiltersViewModel()
        let pieChartViewModel = PieChartViewModel(cdm: coreDataModel, fvm: filtersViewModel)
        let statsSearchViewModel = StatsSearchViewModel()
        let statsListViewModel = StatsListViewModel(cdm: coreDataModel, fvm: filtersViewModel, pcvm: pieChartViewModel, searchModel: statsSearchViewModel)
        self._rvm = StateObject(wrappedValue: ratesViewModel)
        self._cloudKitKVSManager = StateObject(wrappedValue: cloudKitKVSManger)
        self._cdm = StateObject(wrappedValue: coreDataModel)
        self._pieChartViewModel = StateObject(wrappedValue: pieChartViewModel)
        self._filtersViewModel = StateObject(wrappedValue: filtersViewModel)
        self._statsListViewModel = StateObject(wrappedValue: statsListViewModel)
        self._statsSearchViewModel = StateObject(wrappedValue: statsSearchViewModel)
    }
        
    var body: some View {
        TabView(selection: selection) {
            homeTab

            transactionsTab

            Color.clear
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .tag(2)

            analyticsTab

            settingsTab
        }
        .blur(radius: hideContent ? Vars.privacyBlur : 0)
        .animation(.easeOut(duration: 0.1), value: hideContent)
        .onOpenURL { url in
            if url == .addExpenseAction {
                addTransactionInitialDate = .now
                addExpenseAction = true
            }
        }
        .onChange(of: scenePhase) { value in
            scenePhaseChange(value)
        }
        .environmentObject(cdm)
        .environmentObject(rvm)
        .sheet(isPresented: $addExpenseAction) {
            GallaAddTransactionView(
                ratesViewModel: rvm,
                coreDataModel: cdm,
                initialDate: addTransactionInitialDate
            )
        }
        .sheet(isPresented: $presentOnboarding) {
            OnboardingView()
                .environmentObject(cdm)
                .environmentObject(cloudKitKVSManager)
                .accentColor(.orange)
                .interactiveDismissDisabled()
        }
        .tint(colorIdentifier(color: tint))
        .accentColor(colorIdentifier(color: tint))
        .preferredColorScheme(autoDarkMode ? nil : (darkMode ? .dark : .light))
        .customAlert()
        .alert(
            "Something went wrong...",
            isPresented: $errorHandler.showAlert,
            presenting: errorHandler.appError
        ) { error in
            if error.createIssue {
                Button("Create an issue on GitHub") {
                    errorHandler.dropError()
                    openURL(.newGithubIssue)
                }
            }
            
            Button("OK", role: .cancel) {
                errorHandler.dropError()
            }
        } message: { error in
            Text("\(error.errorDescription)\n\(error.recoverySuggestion)")
        }
        .styleListsToDynamicType()
    }
    
    private var homeTab: some View {
        GallaHomeView(
            showAddTransaction: $addExpenseAction,
            addTransactionInitialDate: $addTransactionInitialDate
        )
        .environmentObject(privacyMonitor)
        .tabItem {
            Label("Home", systemImage: "house.fill")
        }
        .tag(0)
    }
    
    private var transactionsTab: some View {
        GallaTransactionsView()
            .environmentObject(privacyMonitor)
            .tabItem {
                Label("Transactions", systemImage: "list.bullet.rectangle")
            }
            .tag(1)
    }

    private var analyticsTab: some View {
        GallaAnalyticsView()
            .tabItem {
                Label("Analytics", systemImage: "chart.bar.xaxis")
            }
            .tag(3)
    }
    
    private var settingsTab: some View {
        GallaSettingsView(
            presentOnboarding: $presentOnboarding,
            cloudSyncWasEnabled: cloudSyncWasEnabled
        )
        .environmentObject(cloudKitKVSManager)
        .environmentObject(privacyMonitor)
        .environmentObject(pieChartViewModel)
        .tabItem {
            Label("Settings", systemImage: "gearshape.fill")
        }
        .tag(4)
        .badge(cloudKitKVSManager.iCloudSync != cloudSyncWasEnabled ? 1 : 0)
    }
    
    private func scenePhaseChange(_ value: ScenePhase) {
        if value == .inactive {
            WidgetsManager.shared.reloadSumWidgets()
            WidgetsManager.shared.updateAccentColor()
        }
        
        if privacyScreenIsEnabled {
            hideContent = value != .active
        }
        
        privacyMonitor.changePrivacyScreenValue(value != .active)
        
        if value == .active {
            rvm.checkForUpdate()
            
            if let lastFetchDate = cdm.lastFetchDate, !Calendar.current.isDateInToday(lastFetchDate) {
                cdm.fetchSpendings(updateWidgets: false)
            }
            
            #if DEBUG
            Logger(subsystem: Vars.appIdentifier, category: #fileID).log("Moved to foreground, CD last fetch: \((cdm.lastFetchDate ?? .distantFuture).formatted(date: .numeric, time: .standard))")
            #endif
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// MARK: - Galla visual language

private enum GallaStyle {
    static let defaultExpenseCategories: [(name: String, color: String)] = [
        ("Housing", "nord1"), ("Food", "nord2"), ("Groceries", "nord4"),
        ("Utilities", "nord6"), ("Transportation", "nord94"), ("Shopping", "nord7"),
        ("Clothes", "nord1"), ("Going out", "nord4"), ("Entertainment", "nord6"),
        ("Subscription", "nord7")
    ]

    static let defaultIncomeCategories = ["Salary", "Freelance", "Investment", "Gift", "Other"]

    static let horizontalPadding: CGFloat = 24
    static let cornerRadius: CGFloat = 24
    static let softBackground = Color(uiColor: .secondarySystemBackground)

    static func actionBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .black
    }

    static func actionForeground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : .white
    }

    static func displayName(for category: String) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard leadingEmoji(in: trimmed) != nil else { return trimmed }
        let name = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? trimmed : name
    }

    static func emoji(for category: String) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if let emoji = leadingEmoji(in: trimmed) { return String(emoji) }

        let value = category.lowercased()
        if value.contains("food") || value.contains("lunch") || value.contains("restaurant") { return "🍽️" }
        if value.contains("grocer") { return "🛒" }
        if value.contains("transport") || value.contains("uber") || value.contains("commute") { return "🚕" }
        if value.contains("house") || value.contains("housing") || value.contains("rent") { return "🏠" }
        if value.contains("util") || value.contains("bill") { return "💡" }
        if value.contains("shop") { return "🛍️" }
        if value.contains("cloth") { return "👕" }
        if value.contains("coffee") { return "☕️" }
        if value.contains("entertain") || value.contains("movie") { return "🍿" }
        if value.contains("going out") || value.contains("nightlife") { return "🍻" }
        if value.contains("subscription") { return "📅" }
        if value.contains("health") { return "💊" }
        if value.contains("travel") { return "✈️" }
        if value.contains("salary") || value.contains("income") { return "💰" }
        if value.contains("freelance") { return "💼" }
        if value.contains("investment") { return "📈" }
        if value.contains("gift") { return "🎁" }
        if value == "other" { return "💵" }
        return "🧾"
    }

    private static func leadingEmoji(in category: String) -> Character? {
        guard let first = category.first else { return nil }
        let isEmoji = first.unicodeScalars.contains {
            $0.properties.isEmojiPresentation || $0.value == 0xFE0F
        }
        return isEmoji ? first : nil
    }

    static func amount(_ value: Double, currency: String = UserDefaults.defaultCurrency()) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = value.rounded() == value ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func convertedAmount(_ spending: SpendingEntity) -> Double {
        let currency = UserDefaults.defaultCurrency()
        if spending.wrappedCurrency == currency { return spending.amountWithReturns }
        let rate = UserDefaults.standard.getUnwrapedRates()[currency] ?? 1
        return spending.amountUSDWithReturns * rate
    }

    static func convertedAmount(_ income: GallaIncomeRecord) -> Double {
        let currency = UserDefaults.defaultCurrency()
        if income.currency == currency { return income.amount }
        let rate = UserDefaults.standard.getUnwrapedRates()[currency] ?? 1
        let usdAmount = income.currency == "USD" ? income.amount : income.amount / (UserDefaults.standard.getUnwrapedRates()[income.currency] ?? 1)
        return income.currency == "USD" ? income.amount * rate : usdAmount * rate
    }
}

private struct GallaPill<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Capsule().fill(GallaStyle.softBackground))
    }
}

private struct GallaTransactionRow: View {
    let spending: SpendingEntity

    var body: some View {
        HStack(spacing: 12) {
            GallaTransactionEmoji(category: spending.categoryName)

            VStack(alignment: .leading, spacing: 3) {
                Text(GallaStyle.displayName(for: spending.categoryName))
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)
                if let place = spending.place, !place.isEmpty {
                    Text(place)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            Text("−" + GallaStyle.amount(GallaStyle.convertedAmount(spending)))
                .font(.body.weight(.semibold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct GallaIncomeRow: View {
    let record: GallaIncomeRecord

    var body: some View {
        HStack(spacing: 12) {
            GallaTransactionEmoji(category: record.category)

            VStack(alignment: .leading, spacing: 3) {
                Text(GallaStyle.displayName(for: record.category))
                    .font(.body.weight(.semibold))
                if let place = record.place, !place.isEmpty {
                    Text(place).font(.caption).foregroundColor(.secondary)
                }
            }

            Spacer()
            Text("+" + GallaStyle.amount(GallaStyle.convertedAmount(record)))
                .font(.body.weight(.semibold))
                .foregroundColor(.green)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(GallaStyle.displayName(for: record.category)), income \(GallaStyle.amount(record.amount, currency: record.currency))")
    }
}

private struct GallaTransactionEmoji: View {
    @Environment(\.colorScheme) private var colorScheme
    let category: String

    var body: some View {
        Text(GallaStyle.emoji(for: category))
            .font(.system(size: 30))
            .frame(width: 42, height: 42)
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.2),
                radius: 2.5,
                x: 0,
                y: 2
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Home

private enum GallaTransactionDeletion {
    case expense(SpendingEntity)
    case income(GallaIncomeRecord)
}

private struct GallaHomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var cdm: CoreDataModel
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SpendingEntity.date, ascending: false)])
    private var spendings: FetchedResults<SpendingEntity>

    @Binding var showAddTransaction: Bool
    @Binding var addTransactionInitialDate: Date
    @State private var showSearch = false
    @State private var showMonthPicker = false
    @State private var monthOffset = 0
    @State private var monthDragTranslation: CGFloat = 0
    @State private var monthPreviewOffsetDelta = 0
    @State private var selectedSpending: SpendingEntity?
    @State private var incomeRecords = GallaIncomeStore.shared.list()

    private var thisMonth: [SpendingEntity] {
        let month = Calendar.current.date(byAdding: .month, value: -monthOffset, to: .now) ?? .now
        return spendings.filter { Calendar.current.isDate($0.wrappedDate, equalTo: month, toGranularity: .month) }
    }

    private var spent: Double {
        thisMonth.reduce(0) { $0 + GallaStyle.convertedAmount($1) }
    }

    private var income: Double {
        incomeRecords
            .filter { Calendar.current.isDate($0.date, equalTo: Calendar.current.date(byAdding: .month, value: -monthOffset, to: .now) ?? .now, toGranularity: .month) }
            .reduce(0) { $0 + GallaStyle.convertedAmount($1) }
    }

    private var remaining: Double {
        income - spent
    }

    private var chartValues: [Double] {
        let selectedMonth = Calendar.current.date(byAdding: .month, value: -monthOffset, to: .now) ?? .now
        return (-5...0).map { offset in
            guard let date = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) else { return 0 }
            return spendings
                .filter { Calendar.current.isDate($0.wrappedDate, equalTo: date, toGranularity: .month) }
                .reduce(0) { $0 + GallaStyle.convertedAmount($1) }
        }
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    monthPicker
                    summary
                    GallaWaveChart(values: chartValues, monthOffset: monthOffset)
                        .frame(height: 150)
                        .padding(.horizontal, -GallaStyle.horizontalPadding)
                }
                .padding(.horizontal, GallaStyle.horizontalPadding)
                .padding(.top, 14)

                recentTransactions
                    .padding(.horizontal, GallaStyle.horizontalPadding)
                    .padding(.top, 16)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(item: $selectedSpending) { spending in
            GallaTransactionDetailView(spending: spending)
        }
        .sheet(isPresented: $showSearch) {
            GallaSearchView()
        }
        .onReceive(NotificationCenter.default.publisher(for: GallaIncomeStore.didChangeNotification)) { _ in
            incomeRecords = GallaIncomeStore.shared.list()
        }
        .onAppear(perform: syncAddTransactionDate)
        .onChange(of: monthOffset) { _ in
            syncAddTransactionDate()
        }
    }

    private var header: some View {
        HStack {
            Text("Galla")
                .font(.largeTitle.bold())
            Spacer()
            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass")
                    .font(.title2.weight(.medium))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Search transactions")
        }
    }

    private var monthPicker: some View {
        Group {
            if showMonthPicker {
                inlineMonthPicker
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            showMonthPicker = true
                        }
                    } label: {
                        GallaPill {
                            HStack(spacing: 8) {
                                Text(monthOffset == 0 ? "This month" : selectedMonthLabel)
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.bold))
                            }
                        }
                    }
                    .foregroundColor(.primary)
                    .accessibilityLabel("Choose month")
                    .accessibilityValue("Collapsed")
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(height: 60)
    }

    private var inlineMonthPicker: some View {
        GeometryReader { geometry in
            let cellWidth: CGFloat = 64
            let cellPitch = cellWidth + 8

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(GallaStyle.softBackground)

                movingMonthRow(cellWidth: cellWidth)
                    .offset(x: monthDragTranslation)
                    .mask(monthPickerSharpContentMask)

                movingMonthRow(cellWidth: cellWidth)
                    .offset(x: monthDragTranslation)
                    .blur(radius: 2.8)
                    .mask(monthPickerBlurredEdgesMask)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                fixedMonthSelection(cellWidth: cellWidth)
                    .allowsHitTesting(false)
            }
            .frame(width: geometry.size.width, height: 60)
            .contentShape(Rectangle())
            .highPriorityGesture(monthDragGesture(cellPitch: cellPitch))
        }
        .frame(height: 60)
        .mask(monthPickerFadeMask)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func movingMonthRow(cellWidth: CGFloat) -> some View {
        HStack(spacing: 8) {
            // Keep guard cells outside the maximum one-gesture travel so the
            // rounded strip never reveals an empty edge while rubber-banding.
            ForEach(-30...30, id: \.self) { position in
                let candidateOffset = monthOffset - position
                let date = Calendar.current.date(byAdding: .month, value: -candidateOffset, to: .now) ?? .now
                let isUpcoming = candidateOffset < 0

                Button {
                    selectMonth(offset: candidateOffset)
                } label: {
                    VStack(spacing: 1) {
                        Text(date, format: .dateTime.month(.abbreviated))
                            .font(.subheadline.weight(.medium))
                        Text(date, format: .dateTime.year())
                            .font(.caption2)
                            .opacity(0.55)
                    }
                    .foregroundColor(isUpcoming ? .secondary.opacity(0.42) : .primary)
                    .frame(width: cellWidth, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(isUpcoming)
                .accessibilityLabel(date.formatted(.dateTime.month(.wide).year()))
                .accessibilityValue(isUpcoming ? "Upcoming" : (candidateOffset == monthOffset ? "Selected" : ""))
                .accessibilityAddTraits(candidateOffset == monthOffset ? .isSelected : [])
            }
        }
    }

    private func fixedMonthSelection(cellWidth: CGFloat) -> some View {
        VStack(spacing: 1) {
            Text(previewedMonthDate, format: .dateTime.month(.abbreviated))
                .font(.subheadline.weight(.semibold))
            Text(previewedMonthDate, format: .dateTime.year())
                .font(.caption2)
                .opacity(0.78)
        }
        .foregroundColor(GallaStyle.actionForeground(for: colorScheme))
        .frame(width: cellWidth, height: 44)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(GallaStyle.actionBackground(for: colorScheme))
        )
        .accessibilityHidden(true)
    }

    private var previewedMonthOffset: Int {
        max(0, monthOffset + monthPreviewOffsetDelta)
    }

    private var previewedMonthDate: Date {
        Calendar.current.date(byAdding: .month, value: -previewedMonthOffset, to: .now) ?? .now
    }

    private var monthPickerFadeMask: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: 28)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 28)
        }
    }

    private var monthPickerSharpContentMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.14),
                .init(color: .black, location: 0.86),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var monthPickerBlurredEdgesMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .clear, location: 0.2),
                .init(color: .clear, location: 0.8),
                .init(color: .black, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func monthDragGesture(cellPitch: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let resistedTranslation = rubberBandedMonthTranslation(
                    value.translation.width,
                    cellPitch: cellPitch
                )
                monthDragTranslation = resistedTranslation
                let rawDelta = Int((resistedTranslation / cellPitch).rounded())
                let clampedDelta = min(24, max(-24, rawDelta))
                let selectableOffset = max(0, monthOffset + clampedDelta)
                let selectableDelta = selectableOffset - monthOffset
                if selectableDelta != monthPreviewOffsetDelta {
                    monthPreviewOffsetDelta = selectableDelta
                    HapticManager.shared.impact(.light)
                }
            }
            .onEnded { _ in
                commitMonthDrag(cellPitch: cellPitch)
            }
    }

    private func rubberBandedMonthTranslation(_ translation: CGFloat, cellPitch: CGFloat) -> CGFloat {
        let newerMonthsAvailable = min(monthOffset, 24)
        let lowerLimit = -CGFloat(newerMonthsAvailable) * cellPitch
        let upperLimit = CGFloat(24) * cellPitch

        if translation < lowerLimit {
            return lowerLimit + rubberBandDistance(
                translation - lowerLimit,
                dimension: cellPitch * 0.8
            )
        }

        if translation > upperLimit {
            return upperLimit + rubberBandDistance(
                translation - upperLimit,
                dimension: cellPitch * 0.8
            )
        }

        return translation
    }

    private func rubberBandDistance(_ distance: CGFloat, dimension: CGFloat) -> CGFloat {
        let magnitude = abs(distance)
        let resistedMagnitude = (0.55 * magnitude * dimension) / (dimension + 0.55 * magnitude)
        return distance < 0 ? -resistedMagnitude : resistedMagnitude
    }

    private func commitMonthDrag(cellPitch: CGFloat) {
        let selectedOffset = previewedMonthOffset
        let selectedDelta = selectedOffset - monthOffset
        guard selectedDelta != 0 else {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                monthDragTranslation = 0
            }
            monthPreviewOffsetDelta = 0
            return
        }

        withAnimation(.easeOut(duration: 0.12)) {
            monthDragTranslation = CGFloat(selectedDelta) * cellPitch
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                monthOffset = selectedOffset
                monthDragTranslation = 0
                monthPreviewOffsetDelta = 0
            }
        }
    }

    private func selectMonth(offset: Int) {
        guard offset >= 0 else { return }
        HapticManager.shared.impact(.light)
        withAnimation(.easeInOut(duration: 0.22)) {
            monthOffset = offset
            monthDragTranslation = 0
            monthPreviewOffsetDelta = 0
            showMonthPicker = false
        }
    }

    private var selectedMonthLabel: String {
        let date = Calendar.current.date(byAdding: .month, value: -monthOffset, to: .now) ?? .now
        return date.formatted(.dateTime.month(.wide).year())
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(GallaStyle.amount(remaining))
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.48)
                    .lineLimit(1)
                    .layoutPriority(1)

                VStack(spacing: 4) {
                    Text("left")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Capsule()
                        .fill(Color.primary)
                        .frame(width: 48, height: 2)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                summaryMetric(title: GallaStyle.amount(income), subtitle: "income")

                Rectangle()
                    .fill(Color(uiColor: .separator))
                    .frame(width: 1, height: 48)
                    .padding(.horizontal, 24)

                summaryMetric(title: GallaStyle.amount(spent), subtitle: "spent")
            }
        }
    }

    private func summaryMetric(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recentTransactions: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(monthOffset == 0 ? "This month" : selectedMonthLabel)
                    .font(.title2.bold())
                Spacer()
                Text("See all")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 4)

            let monthIncome = incomeRecords.filter { Calendar.current.isDate($0.date, equalTo: Calendar.current.date(byAdding: .month, value: -monthOffset, to: .now) ?? .now, toGranularity: .month) }
            let monthSpendings = thisMonth
            if monthSpendings.isEmpty && monthIncome.isEmpty {
                VStack(spacing: 14) {
                    Text("Your spending story starts here")
                        .font(.headline)
                    Text("Add the first expense to see it on your home screen and analytics.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        syncAddTransactionDate()
                        showAddTransaction = true
                    } label: {
                        Text("Add expense")
                            .foregroundColor(GallaStyle.actionForeground(for: colorScheme))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GallaStyle.actionBackground(for: colorScheme))
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                .background(RoundedRectangle(cornerRadius: GallaStyle.cornerRadius).fill(GallaStyle.softBackground))
            } else {
                List {
                    ForEach(Array(monthSpendings.enumerated()), id: \.element.objectID) { index, spending in
                        VStack(spacing: 0) {
                            Button { selectedSpending = spending } label: {
                                GallaTransactionRow(spending: spending)
                            }
                            .buttonStyle(.plain)

                            if index < monthSpendings.count - 1 || !monthIncome.isEmpty {
                                Divider()
                                    .padding(.leading, 54)
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                delete(.expense(spending))
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .labelStyle(.iconOnly)
                            }
                        }
                    }

                    ForEach(Array(monthIncome.enumerated()), id: \.element.id) { index, income in
                        VStack(spacing: 0) {
                            GallaIncomeRow(record: income)

                            if index < monthIncome.count - 1 {
                                Divider()
                                    .padding(.leading, 54)
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                delete(.income(income))
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .labelStyle(.iconOnly)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 0)
            }
        }
    }

    private func syncAddTransactionDate() {
        let calendar = Calendar.autoupdatingCurrent
        let selectedMonth = calendar.date(byAdding: .month, value: -monthOffset, to: .now) ?? .now
        let selectedMonthComponents = calendar.dateComponents([.year, .month], from: selectedMonth)
        let currentComponents = calendar.dateComponents([.day, .hour, .minute, .second], from: .now)

        guard let monthStart = calendar.date(from: selectedMonthComponents),
              let validDays = calendar.range(of: .day, in: .month, for: monthStart) else {
            addTransactionInitialDate = selectedMonth
            return
        }

        var targetComponents = selectedMonthComponents
        targetComponents.day = min(currentComponents.day ?? 1, validDays.count)
        targetComponents.hour = currentComponents.hour
        targetComponents.minute = currentComponents.minute
        targetComponents.second = currentComponents.second
        addTransactionInitialDate = calendar.date(from: targetComponents) ?? selectedMonth
    }

    private func delete(_ transaction: GallaTransactionDeletion) {
        switch transaction {
        case .expense(let spending):
            cdm.deleteSpending(spending)
            HapticManager.shared.notification(.success)
        case .income(let income):
            if GallaIncomeStore.shared.delete(income) {
                HapticManager.shared.notification(.success)
            }
        }
    }
}

private struct GallaWaveChart: View {
    let values: [Double]
    let monthOffset: Int

    private var hasData: Bool { values.contains { $0 > 0 } }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                Path { path in
                    guard !values.isEmpty else { return }
                    let maxValue = max(values.max() ?? 1, 1)
                    let step = geometry.size.width / CGFloat(max(values.count - 1, 1))
                    let points = values.enumerated().map { index, value in
                        CGPoint(
                            x: CGFloat(index) * step,
                            y: hasData ? geometry.size.height - CGFloat(value / maxValue) * (geometry.size.height - 28) - 14 : geometry.size.height / 2
                        )
                    }
                    path.move(to: points[0])
                    for index in 1..<points.count {
                        let previous = points[index - 1]
                        let point = points[index]
                        let controlX = (previous.x + point.x) / 2
                        path.addCurve(to: point, control1: CGPoint(x: controlX, y: previous.y), control2: CGPoint(x: controlX, y: point.y))
                    }
                }
                .stroke(hasData ? Color.primary : Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: hasData ? 4 : 2, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 112)

            HStack {
                ForEach(-5...0, id: \.self) { offset in
                    let selectedMonth = Calendar.current.date(byAdding: .month, value: -monthOffset, to: .now) ?? .now
                    let date = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) ?? .now
                    Text(date, format: .dateTime.month(.abbreviated))
                        .font(.caption)
                        .fontWeight(offset == 0 ? .bold : .regular)
                        .foregroundColor(offset == 0 ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 18)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Six month spending trend")
    }
}

// MARK: - Transactions

private enum GallaDateFilter: String, CaseIterable, Identifiable {
    case all = "All time"
    case month = "This month"
    case week = "This week"
    var id: String { rawValue }
}

private struct GallaTransactionsView: View {
    @EnvironmentObject private var cdm: CoreDataModel
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SpendingEntity.date, ascending: false)])
    private var spendings: FetchedResults<SpendingEntity>

    @State private var search = ""
    @State private var dateFilter: GallaDateFilter = .all
    @State private var selectedCategories = Set<UUID>()
    @State private var showFilters = false
    @State private var selectedSpending: SpendingEntity?
    @State private var incomeRecords = GallaIncomeStore.shared.list()

    private var filtered: [SpendingEntity] {
        spendings.filter { spending in
            let matchesSearch = search.isEmpty || spending.categoryName.localizedCaseInsensitiveContains(search) || (spending.place ?? "").localizedCaseInsensitiveContains(search) || (spending.comment ?? "").localizedCaseInsensitiveContains(search)
            let matchesCategory = selectedCategories.isEmpty || selectedCategories.contains(spending.category?.id ?? UUID())
            let matchesDate: Bool
            switch dateFilter {
            case .all: matchesDate = true
            case .month: matchesDate = Calendar.current.isDate(spending.wrappedDate, equalTo: .now, toGranularity: .month)
            case .week: matchesDate = Calendar.current.isDate(spending.wrappedDate, equalTo: .now, toGranularity: .weekOfYear)
            }
            return matchesSearch && matchesCategory && matchesDate
        }
    }

    private var grouped: [(Date, [SpendingEntity])] {
        Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.wrappedDate) }
            .sorted { $0.key > $1.key }
            .map { ($0.key, $0.value) }
    }

    private var filteredIncome: [GallaIncomeRecord] {
        incomeRecords.filter { income in
            let matchesSearch = search.isEmpty || income.category.localizedCaseInsensitiveContains(search) || (income.place ?? "").localizedCaseInsensitiveContains(search) || (income.note ?? "").localizedCaseInsensitiveContains(search)
            switch dateFilter {
            case .all:
                return matchesSearch
            case .month:
                return matchesSearch && Calendar.current.isDate(income.date, equalTo: .now, toGranularity: .month)
            case .week:
                return matchesSearch && Calendar.current.isDate(income.date, equalTo: .now, toGranularity: .weekOfYear)
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                if !filteredIncome.isEmpty {
                    Section {
                        ForEach(Array(filteredIncome.enumerated()), id: \.element.id) { index, income in
                            VStack(spacing: 0) {
                                GallaIncomeRow(record: income)
                                if index < filteredIncome.count - 1 {
                                    Divider().padding(.leading, 54)
                                }
                            }
                            .listRowInsets(transactionRowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                deleteSwipeButton(for: .income(income))
                            }
                        }
                    } header: {
                        transactionSectionHeader(
                            title: "Income",
                            amount: "+" + GallaStyle.amount(filteredIncome.reduce(0) { $0 + GallaStyle.convertedAmount($1) }),
                            amountColor: .green
                        )
                        .textCase(nil)
                        .padding(.top, 8)
                    }
                }

                ForEach(grouped, id: \.0) { date, items in
                    Section {
                        ForEach(Array(items.enumerated()), id: \.element.objectID) { index, spending in
                            VStack(spacing: 0) {
                                Button { selectedSpending = spending } label: {
                                    GallaTransactionRow(spending: spending)
                                }
                                .buttonStyle(.plain)

                                if index < items.count - 1 {
                                    Divider().padding(.leading, 54)
                                }
                            }
                            .listRowInsets(transactionRowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                deleteSwipeButton(for: .expense(spending))
                            }
                        }
                    } header: {
                        transactionSectionHeader(
                            title: sectionTitle(date),
                            amount: "−" + GallaStyle.amount(items.reduce(0) { $0 + GallaStyle.convertedAmount($1) }),
                            amountColor: .secondary
                        )
                        .textCase(nil)
                        .padding(.top, 8)
                    }
                }

                if filtered.isEmpty && filteredIncome.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                        Text("No matching transactions").font(.headline)
                        Text("Try another search or clear your filters.")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                    .listRowInsets(transactionRowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            .navigationTitle("Transactions")
            .searchable(text: $search, prompt: "Category, place or note")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showFilters = true } label: {
                        Image(systemName: selectedCategories.isEmpty && dateFilter == .all ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityLabel("Filter transactions")
                }
            }
        }
        .navigationViewStyle(.stack)
        .onReceive(NotificationCenter.default.publisher(for: GallaIncomeStore.didChangeNotification)) { _ in
            incomeRecords = GallaIncomeStore.shared.list()
        }
        .sheet(isPresented: $showFilters) {
            GallaFilterView(dateFilter: $dateFilter, selectedCategories: $selectedCategories)
        }
        .sheet(item: $selectedSpending) { spending in
            GallaTransactionDetailView(spending: spending)
        }
    }

    private var transactionRowInsets: EdgeInsets {
        EdgeInsets(top: 0, leading: GallaStyle.horizontalPadding, bottom: 0, trailing: GallaStyle.horizontalPadding)
    }

    private func transactionSectionHeader(title: String, amount: String, amountColor: Color) -> some View {
        HStack {
            Text(title)
                .font(.title3.bold())
                .foregroundColor(.primary)
            Spacer()
            Text(amount)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(amountColor)
        }
    }

    private func deleteSwipeButton(for transaction: GallaTransactionDeletion) -> some View {
        Button(role: .destructive) {
            delete(transaction)
        } label: {
            Label("Delete", systemImage: "trash")
                .labelStyle(.iconOnly)
        }
    }

    private func delete(_ transaction: GallaTransactionDeletion) {
        switch transaction {
        case .expense(let spending):
            cdm.deleteSpending(spending)
            HapticManager.shared.notification(.success)
        case .income(let income):
            if GallaIncomeStore.shared.delete(income) {
                HapticManager.shared.notification(.success)
            }
        }
    }

    private func sectionTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct GallaSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SpendingEntity.date, ascending: false)])
    private var spendings: FetchedResults<SpendingEntity>
    @State private var search = ""
    @State private var selectedSpending: SpendingEntity?

    var body: some View {
        NavigationView {
            List {
                ForEach(spendings.filter { search.isEmpty || $0.categoryName.localizedCaseInsensitiveContains(search) || ($0.place ?? "").localizedCaseInsensitiveContains(search) }) { spending in
                    Button { selectedSpending = spending } label: { GallaTransactionRow(spending: spending) }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Search")
            .searchable(text: $search, prompt: "Category or place")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .sheet(item: $selectedSpending) { GallaTransactionDetailView(spending: $0) }
    }
}

private struct GallaFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CategoryEntity.name, ascending: true)], predicate: NSPredicate(format: "isShadowed == false"))
    private var categories: FetchedResults<CategoryEntity>
    @Binding var dateFilter: GallaDateFilter
    @Binding var selectedCategories: Set<UUID>

    var body: some View {
        NavigationView {
            List {
                Section("Date range") {
                    ForEach(GallaDateFilter.allCases) { option in
                        Button {
                            dateFilter = option
                        } label: {
                            HStack {
                                Text(option.rawValue).foregroundColor(.primary)
                                Spacer()
                                if dateFilter == option { Image(systemName: "checkmark").foregroundColor(.primary) }
                            }
                        }
                    }
                }
                Section("Categories") {
                    ForEach(categories) { category in
                        Button { toggle(category.id) } label: {
                            HStack {
                                Text(GallaStyle.emoji(for: category.name ?? ""))
                                Text(GallaStyle.displayName(for: category.name ?? "Untitled")).foregroundColor(.primary)
                                Spacer()
                                if let id = category.id, selectedCategories.contains(id) { Image(systemName: "checkmark").foregroundColor(.primary) }
                            }
                        }
                    }
                }
                Section {
                    Button("Clear all", role: .destructive) {
                        dateFilter = .all
                        selectedCategories.removeAll()
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func toggle(_ id: UUID?) {
        guard let id else { return }
        if selectedCategories.contains(id) { selectedCategories.remove(id) } else { selectedCategories.insert(id) }
    }
}

// MARK: - Analytics

private struct GallaAnalyticsView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \SpendingEntity.date, ascending: false)])
    private var spendings: FetchedResults<SpendingEntity>
    @State private var incomeRecords = GallaIncomeStore.shared.list()

    private var monthSpendings: [SpendingEntity] {
        spendings.filter { Calendar.current.isDate($0.wrappedDate, equalTo: .now, toGranularity: .month) }
    }

    private var categories: [(String, Double)] {
        Dictionary(grouping: monthSpendings, by: \SpendingEntity.categoryName)
            .map { ($0.key, $0.value.reduce(0) { $0 + GallaStyle.convertedAmount($1) }) }
            .sorted { $0.1 > $1.1 }
    }

    private var total: Double { categories.reduce(0) { $0 + $1.1 } }

    private var monthIncome: Double {
        incomeRecords
            .filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month) }
            .reduce(0) { $0 + GallaStyle.convertedAmount($1) }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        GallaPill { Text("This month") }
                        Spacer()
                        Text("\(monthSpendings.count) transactions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 12) {
                        analyticsMetric(title: "Spent", value: total, color: .primary)
                        analyticsMetric(title: "Income", value: monthIncome, color: .green)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        Text("By category").font(.title2.bold())
                        if categories.isEmpty {
                            Text("Add expenses to see your category breakdown.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(Array(categories.prefix(8).enumerated()), id: \.offset) { _, item in
                                VStack(spacing: 8) {
                                    HStack {
                                        Text(GallaStyle.emoji(for: item.0))
                                        Text(GallaStyle.displayName(for: item.0)).fontWeight(.semibold)
                                        Spacer()
                                        Text(GallaStyle.amount(item.1)).fontWeight(.semibold)
                                    }
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(GallaStyle.softBackground)
                                            Capsule().fill(Color.primary)
                                                .frame(width: geometry.size.width * CGFloat(item.1 / max(total, 1)))
                                        }
                                    }
                                    .frame(height: 8)
                                }
                            }
                        }
                    }
                    .padding(22)
                    .background(RoundedRectangle(cornerRadius: GallaStyle.cornerRadius).fill(Color(uiColor: .systemBackground)))
                    .overlay(RoundedRectangle(cornerRadius: GallaStyle.cornerRadius).stroke(Color.secondary.opacity(0.18)))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Monthly insight").font(.title3.bold())
                        Text(monthSpendings.isEmpty ? "No expenses recorded this month yet." : "Your biggest category is \(categories.first?.0 ?? "—"), at \(GallaStyle.amount(categories.first?.1 ?? 0)).")
                            .foregroundColor(.secondary)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: GallaStyle.cornerRadius).fill(GallaStyle.softBackground))
                }
                .padding(GallaStyle.horizontalPadding)
            }
            .navigationTitle("Analytics")
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        }
        .navigationViewStyle(.stack)
        .onReceive(NotificationCenter.default.publisher(for: GallaIncomeStore.didChangeNotification)) { _ in
            incomeRecords = GallaIncomeStore.shared.list()
        }
    }

    private func analyticsMetric(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(GallaStyle.amount(value))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .foregroundColor(color)
            Text(title).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Add transaction

private struct GallaAddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CategoryEntity.name, ascending: true)], predicate: NSPredicate(format: "isShadowed == false"))
    private var categories: FetchedResults<CategoryEntity>
    @StateObject private var vm: AddSpendingViewModel
    private let coreDataModel: CoreDataModel
    @State private var showDetailsEditor = false
    @State private var detailsFocus: GallaTransactionDetailsEditor.Field = .place
    @State private var isIncome = false
    @State private var incomeCategory = "Salary"
    @State private var dateDragTranslation: CGFloat = 0
    @State private var datePreviewDayOffset = 0

    init(
        ratesViewModel: RatesViewModel,
        coreDataModel: CoreDataModel,
        initialDate: Date = .now
    ) {
        self.coreDataModel = coreDataModel
        _vm = StateObject(
            wrappedValue: AddSpendingViewModel(
                ratesViewModel: ratesViewModel,
                coreDataModel: coreDataModel,
                places: coreDataModel.places,
                initialDate: initialDate
            )
        )
    }

    private let keys = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [".", "0", "checkmark"]]

    private var orderedExpenseCategories: [CategoryEntity] {
        let ranks = Dictionary(uniqueKeysWithValues: GallaStyle.defaultExpenseCategories.enumerated().map { ($0.element.name.lowercased(), $0.offset) })
        return categories.sorted {
            let lhsRank = ranks[$0.name?.lowercased() ?? ""] ?? Int.max
            let rhsRank = ranks[$1.name?.lowercased() ?? ""] ?? Int.max
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return ($0.name ?? "") < ($1.name ?? "")
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationView {
                ScrollView {
                    VStack(spacing: 16) {
                        expenseToggle
                        dateStrip
                        amount
                        categoryPicker
                        optionalFields
                        keypad
                    }
                    .padding(.horizontal, GallaStyle.horizontalPadding)
                    .padding(.bottom, 28)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: { Image(systemName: "xmark").foregroundColor(.primary) }
                    }
                }
            }
            .navigationViewStyle(.stack)
            .ignoresSafeArea(.keyboard, edges: .bottom)

            if showDetailsEditor {
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
                    .onTapGesture { closeDetailsEditor() }

                GallaTransactionDetailsEditor(
                    initialPlace: vm.place,
                    initialNote: vm.comment,
                    initialFocus: detailsFocus,
                    onCancel: closeDetailsEditor,
                    onSave: { place, note in
                        vm.place = place
                        vm.comment = note
                        closeDetailsEditor()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .onAppear(perform: prepareCategories)
        .onChange(of: vm.dismiss) { if $0 { dismiss() } }
    }

    private var expenseToggle: some View {
        HStack(spacing: 0) {
            Button {
                isIncome = false
                if vm.selectedCategory == nil {
                    vm.selectedCategory = categories.first(where: { ($0.name ?? "").lowercased() == "food" }) ?? categories.first
                }
            } label: {
                Text("Expense")
                    .foregroundColor(isIncome ? .secondary : GallaStyle.actionForeground(for: colorScheme))
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(Capsule().fill(isIncome ? Color.clear : GallaStyle.actionBackground(for: colorScheme)))
            }
            Button {
                isIncome = true
                vm.selectedCategory = nil
            } label: {
                Text("Income")
                    .foregroundColor(isIncome ? GallaStyle.actionForeground(for: colorScheme) : .secondary)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(Capsule().fill(isIncome ? GallaStyle.actionBackground(for: colorScheme) : Color.clear))
            }
        }
        .background(Capsule().fill(GallaStyle.softBackground))
        .padding(.top, 4)
    }

    private var dateStrip: some View {
        GeometryReader { geometry in
            let cellWidth = max(34, (geometry.size.width - 48) / 7)
            let cellPitch = cellWidth + 8

            ZStack {
                movingDateRow(cellWidth: cellWidth)
                    .offset(x: dateDragTranslation)
                    .mask(dateStripSharpContentMask)

                movingDateRow(cellWidth: cellWidth)
                    .offset(x: dateDragTranslation)
                    .blur(radius: 2.8)
                    .mask(dateStripBlurredEdgesMask)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                fixedDateSelection(cellWidth: cellWidth)
                    .allowsHitTesting(false)
            }
            .frame(width: geometry.size.width, height: 64)
            .contentShape(Rectangle())
            .highPriorityGesture(dateDragGesture(cellPitch: cellPitch))
        }
        .frame(height: 64)
        .mask(dateStripFadeMask)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var dateCalendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }

    private func movingDateRow(cellWidth: CGFloat) -> some View {
        HStack(spacing: 8) {
            ForEach(-30...30, id: \.self) { dayOffset in
                let date = dateCalendar.date(byAdding: .day, value: dayOffset, to: vm.date) ?? vm.date

                Button {
                    selectDay(date)
                } label: {
                    VStack(spacing: 4) {
                        Text(date, format: .dateTime.weekday(.abbreviated))
                            .font(.caption2)
                        Text(date, format: .dateTime.day())
                            .font(.headline)
                    }
                    .foregroundColor(.primary)
                    .frame(width: cellWidth)
                    .frame(height: 58)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                .accessibilityAddTraits(dateCalendar.isDate(date, inSameDayAs: vm.date) ? .isSelected : [])
            }
        }
    }

    private func fixedDateSelection(cellWidth: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text(previewedDate, format: .dateTime.weekday(.abbreviated))
                .font(.caption2)
            Text(previewedDate, format: .dateTime.day())
                .font(.headline)
        }
        .foregroundColor(GallaStyle.actionForeground(for: colorScheme))
        .frame(width: cellWidth, height: 58)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GallaStyle.actionBackground(for: colorScheme))
        )
        .accessibilityHidden(true)
    }

    private var previewedDate: Date {
        dateCalendar.date(byAdding: .day, value: datePreviewDayOffset, to: vm.date) ?? vm.date
    }

    private var dateStripFadeMask: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: 28)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 28)
        }
    }

    private var dateStripSharpContentMask: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.14),
                .init(color: .black, location: 0.86),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var dateStripBlurredEdgesMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .clear, location: 0.2),
                .init(color: .clear, location: 0.8),
                .init(color: .black, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func dateDragGesture(cellPitch: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                dateDragTranslation = value.translation.width
                let rawOffset = Int((-value.translation.width / cellPitch).rounded())
                let clampedOffset = min(30, max(-30, rawOffset))
                if clampedOffset != datePreviewDayOffset {
                    datePreviewDayOffset = clampedOffset
                    HapticManager.shared.impact(.light)
                }
            }
            .onEnded { _ in
                commitDateDrag(cellPitch: cellPitch)
            }
    }

    private func commitDateDrag(cellPitch: CGFloat) {
        let selectedOffset = datePreviewDayOffset
        guard selectedOffset != 0,
              let selectedDate = dateCalendar.date(byAdding: .day, value: selectedOffset, to: vm.date) else {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                dateDragTranslation = 0
            }
            return
        }

        withAnimation(.easeOut(duration: 0.12)) {
            dateDragTranslation = -CGFloat(selectedOffset) * cellPitch
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                vm.date = selectedDate
                dateDragTranslation = 0
                datePreviewDayOffset = 0
            }
        }
    }

    private func selectDay(_ date: Date) {
        let changedDay = !dateCalendar.isDate(date, inSameDayAs: vm.date)
        var selectedComponents = dateCalendar.dateComponents([.year, .month, .day], from: date)
        let currentTime = dateCalendar.dateComponents([.hour, .minute, .second], from: vm.date)
        selectedComponents.hour = currentTime.hour
        selectedComponents.minute = currentTime.minute
        selectedComponents.second = currentTime.second
        vm.date = dateCalendar.date(from: selectedComponents) ?? date
        dateDragTranslation = 0
        datePreviewDayOffset = 0
        if changedDay {
            HapticManager.shared.impact(.light)
        }
    }

    private var amount: some View {
        ZStack(alignment: .trailing) {
            Text(GallaStyle.amount(Double(vm.amount) ?? 0, currency: vm.currency))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 52)

            deleteAmountButton
        }
        .padding(.vertical, 4)
    }

    private var deleteAmountButton: some View {
        Button {
            if !vm.amount.isEmpty { vm.amount.removeLast() }
        } label: {
            Image(systemName: "delete.left.fill")
                .font(.system(size: 24, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(vm.amount.isEmpty ? .secondary.opacity(0.35) : .secondary)
                .frame(width: 48, height: 44)
                .contentShape(Rectangle())
        }
        .disabled(vm.amount.isEmpty)
        .accessibilityLabel("Delete last digit")
    }

    private var categoryPicker: some View {
        Menu {
            if isIncome {
                Section("Income categories") {
                    ForEach(GallaStyle.defaultIncomeCategories, id: \.self) { category in
                        Button("\(GallaStyle.emoji(for: category))  \(GallaStyle.displayName(for: category))") { incomeCategory = category }
                    }
                }
            } else {
                Section("Expense categories") {
                    ForEach(orderedExpenseCategories) { category in
                        Button("\(GallaStyle.emoji(for: category.name ?? ""))  \(GallaStyle.displayName(for: category.name ?? "Untitled"))") { vm.selectedCategory = category }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(GallaStyle.emoji(for: isIncome ? incomeCategory : (vm.selectedCategory?.name ?? "")))
                    .font(.system(size: 26))
                Text(GallaStyle.displayName(for: isIncome ? incomeCategory : (vm.selectedCategory?.name ?? "Choose category"))).fontWeight(.semibold)
                Image(systemName: "chevron.down").font(.caption.bold())
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 20).padding(.vertical, 14)
            .overlay(Capsule().stroke(Color.secondary.opacity(0.35)))
        }
    }

    private var optionalFields: some View {
        HStack(spacing: 12) {
            Button { openDetailsEditor(focusedOn: .place) } label: {
                optionalFieldPill(
                    value: vm.place,
                    placeholder: "Add place",
                    systemImage: "mappin.and.ellipse"
                )
            }
            .frame(maxWidth: .infinity)
            .accessibilityValue(vm.place.isEmpty ? "Optional" : vm.place)

            Button { openDetailsEditor(focusedOn: .note) } label: {
                optionalFieldPill(
                    value: vm.comment,
                    placeholder: "Add note",
                    systemImage: "doc.text"
                )
            }
            .frame(maxWidth: .infinity)
            .accessibilityValue(vm.comment.isEmpty ? "Optional" : vm.comment)
        }
        .buttonStyle(.plain)
    }

    private func optionalFieldPill(value: String, placeholder: String, systemImage: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)

            Text(value.isEmpty ? placeholder : value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(Capsule().fill(GallaStyle.softBackground))
    }

    private var keypad: some View {
        VStack(spacing: 12) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 28) {
                    ForEach(row, id: \.self) { key in
                        Button { tap(key) } label: {
                            Group {
                                if key == "checkmark" { Image(systemName: "checkmark").font(.title.bold()) }
                                else { Text(key).font(.system(size: 30, weight: .medium, design: .rounded)) }
                            }
                            .foregroundColor(key == "checkmark" ? GallaStyle.actionForeground(for: colorScheme) : .primary)
                            .frame(width: 76, height: 76)
                            .background(Circle().fill(key == "checkmark" ? GallaStyle.actionBackground(for: colorScheme) : GallaStyle.softBackground))
                        }
                        .disabled(key == "checkmark" && (vm.amount.isEmpty || (Double(vm.amount) ?? 0) <= 0 || (!isIncome && vm.selectedCategory == nil)))
                        .opacity(key == "checkmark" && (vm.amount.isEmpty || (!isIncome && vm.selectedCategory == nil)) ? 0.45 : 1)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func tap(_ key: String) {
        if key == "checkmark" {
            if isIncome {
                saveIncome()
            } else {
                vm.done()
            }
            return
        }
        if key == "." && vm.amount.contains(".") { return }
        if key == "." && vm.amount.isEmpty { vm.amount = "0."; return }
        if vm.amount.count < 12 { vm.amount.append(key) }
    }

    private func saveIncome() {
        guard let amount = Double(vm.amount), amount > 0 else { return }
        let place = vm.place.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = vm.comment.trimmingCharacters(in: .whitespacesAndNewlines)
        GallaIncomeStore.shared.add(
            amount: amount,
            currency: vm.currency,
            date: vm.date,
            category: incomeCategory,
            place: place.isEmpty ? nil : place,
            note: note.isEmpty ? nil : note
        )
        dismiss()
    }

    private func openDetailsEditor(focusedOn field: GallaTransactionDetailsEditor.Field) {
        detailsFocus = field
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            showDetailsEditor = true
        }
    }

    private func closeDetailsEditor() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showDetailsEditor = false
        }
    }

    private func prepareCategories() {
        // Keep the starter set complete even when an older install already has
        // only a subset of categories saved.
        let existingNames = Set(categories.compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        for item in GallaStyle.defaultExpenseCategories where !existingNames.contains(item.name.lowercased()) {
            _ = coreDataModel.addCategory(name: item.name, color: item.color)
        }

        guard vm.selectedCategory == nil else { return }
        if let food = categories.first(where: { ($0.name ?? "").lowercased() == "food" }) ?? categories.first {
            vm.selectedCategory = food
        }
    }
}

private struct GallaTransactionDetailsEditor: View {
    @Environment(\.colorScheme) private var colorScheme

    enum Field: Hashable {
        case place
        case note
    }

    let initialFocus: Field
    let onCancel: () -> Void
    let onSave: (String, String) -> Void
    @State private var draftPlace: String
    @State private var draftNote: String
    @FocusState private var focusedField: Field?

    init(
        initialPlace: String,
        initialNote: String,
        initialFocus: Field,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String, String) -> Void
    ) {
        self.initialFocus = initialFocus
        self.onCancel = onCancel
        self.onSave = onSave
        _draftPlace = State(initialValue: initialPlace)
        _draftNote = State(initialValue: initialNote)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Transaction details")
                        .font(.title3.bold())
                    Text("Add a place, a note, or both")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(GallaStyle.softBackground))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close details")
            }

            VStack(spacing: 0) {
                detailField(
                    title: "Place",
                    prompt: "e.g. Starbucks, Pune",
                    systemImage: "mappin.and.ellipse",
                    text: $draftPlace,
                    field: .place
                )

                Divider().padding(.leading, 52)

                detailField(
                    title: "Note",
                    prompt: "What was this for?",
                    systemImage: "doc.text",
                    text: $draftNote,
                    field: .note
                )
            }
            .background(RoundedRectangle(cornerRadius: 18).fill(GallaStyle.softBackground))

            Button {
                onSave(cleaned(draftPlace), cleaned(draftNote))
            } label: {
                Text("Save details")
                    .font(.body.weight(.semibold))
                    .foregroundColor(GallaStyle.actionForeground(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(GallaStyle.actionBackground(for: colorScheme)))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.primary.opacity(0.08))
        )
        .shadow(color: .black.opacity(0.18), radius: 28, y: 10)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .onAppear {
            DispatchQueue.main.async {
                focusedField = initialFocus
            }
        }
    }

    private func detailField(
        title: String,
        prompt: String,
        systemImage: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .frame(width: 24)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField(prompt, text: text)
                    .focused($focusedField, equals: field)
                    .submitLabel(field == .place ? .next : .done)
                    .onSubmit {
                        if field == .place {
                            focusedField = .note
                        } else {
                            onSave(cleaned(draftPlace), cleaned(draftNote))
                        }
                    }
            }

            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.65))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear \(title.lowercased())")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func cleaned(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Transaction detail

private struct GallaTransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var cdm: CoreDataModel
    @EnvironmentObject private var rvm: RatesViewModel
    @EnvironmentObject private var privacyMonitor: PrivacyMonitor
    let spending: SpendingEntity
    @State private var showEditor = false
    @State private var editMode = false
    @State private var showReturn = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 26) {
                    Text(GallaStyle.emoji(for: spending.categoryName)).font(.system(size: 54))
                    VStack(spacing: 6) {
                        Text("−" + GallaStyle.amount(GallaStyle.convertedAmount(spending)))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text(GallaStyle.displayName(for: spending.categoryName)).font(.title3.weight(.semibold))
                        Text(spending.wrappedDate.formatted(date: .long, time: .shortened)).foregroundColor(.secondary)
                    }
                    VStack(spacing: 0) {
                        detailRow("Currency", spending.wrappedCurrency)
                        if let place = spending.place, !place.isEmpty { Divider(); detailRow("Place", place) }
                        if let note = spending.comment, !note.isEmpty { Divider(); detailRow("Note", note) }
                        if !spending.returnsArr.isEmpty { Divider(); detailRow("Returns", GallaStyle.amount(spending.returnsSum, currency: spending.wrappedCurrency)) }
                    }
                    .padding(.horizontal, 18)
                    .background(RoundedRectangle(cornerRadius: GallaStyle.cornerRadius).fill(GallaStyle.softBackground))

                    HStack(spacing: 12) {
                        Button { showReturn = true } label: { Label("Add return", systemImage: "arrow.uturn.backward") }
                            .buttonStyle(.bordered)
                        Button { editMode = true; showEditor = true } label: {
                            Label("Edit", systemImage: "pencil")
                                .foregroundColor(GallaStyle.actionForeground(for: colorScheme))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(GallaStyle.actionBackground(for: colorScheme))
                    }
                }
                .padding(GallaStyle.horizontalPadding)
            }
            .navigationTitle("Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .sheet(isPresented: $showEditor) {
            SpendingCompleteView(edit: $editMode, entity: spending)
                .environmentObject(cdm).environmentObject(rvm).environmentObject(privacyMonitor)
        }
        .sheet(isPresented: $showReturn) {
            AddReturnView(spending: spending, cdm: cdm, rvm: rvm)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).foregroundColor(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 16)
    }
}

// MARK: - Settings

private struct GallaSettingsView: View {
    @EnvironmentObject private var kvsManager: CloudKitKVSManager
    @EnvironmentObject private var privacyMonitor: PrivacyMonitor
    @AppStorage(UDKey.defaultCurrency.rawValue) private var currency = Locale.current.currencyCode ?? "USD"
    @AppStorage(UDKey.autoDarkMode.rawValue) private var automaticDarkMode = true
    @AppStorage(UDKey.darkMode.rawValue) private var darkMode = false
    @Binding var presentOnboarding: Bool
    let cloudSyncWasEnabled: Bool

    var body: some View {
        NavigationView {
            List {
                Section("Manage") {
                    NavigationLink { CategoriesEditView() } label: { row("Categories", "square.grid.2x2", "Organize expense types") }
                    NavigationLink { DefaultCurrencySelectorView() } label: { row("Currency", "indianrupeesign.circle", currency) }
                    NavigationLink { RatesView() } label: { row("Exchange rates", "arrow.left.arrow.right", "Latest saved rates") }
                }
                if #available(iOS 16.4, *) {
                    Section("Automation") {
                        NavigationLink {
                            ShortcutsTipView()
                        } label: {
                            row("Siri & Shortcuts", "wand.and.stars", "Siri, Double Back Tap & Action Button")
                        }
                    }
                }
                Section("Appearance") {
                    NavigationLink { ColorAndIconView() } label: { row("Color & app icon", "paintpalette", "Make Galla yours") }
                    NavigationLink { SettingsFormattingView() } label: { row("Formatting", "textformat", "Numbers and dates") }
                    Toggle(isOn: $automaticDarkMode) { row("System appearance", "circle.lefthalf.filled", "Match your iPhone") }
                    if !automaticDarkMode {
                        Toggle(isOn: $darkMode) { row("Dark mode", "moon.fill", darkMode ? "Always on" : "Always off") }
                    }
                }
                Section("Data & privacy") {
                    NavigationLink {
                        ICloudSyncView(cloudSyncWasEnabled: cloudSyncWasEnabled).environmentObject(kvsManager)
                    } label: { row("iCloud sync", "icloud", kvsManager.iCloudSync ? "On" : "Off") }
                    NavigationLink {
                        ExportAndBackupView().environmentObject(privacyMonitor)
                    } label: { row("Export & backup", "square.and.arrow.up", "Keep a copy of your data") }
                }
                Section("Galla") {
                    NavigationLink { AboutView(presentOnboarding: $presentOnboarding) } label: { row("About", "info.circle", "Version \(Bundle.main.releaseVersionNumber ?? "")") }
                    Button { presentOnboarding = true } label: { row("Replay welcome", "sparkles", "See the introduction again") }
                        .foregroundColor(.primary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
        }
        .navigationViewStyle(.stack)
    }

    private func row(_ title: String, _ icon: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title3).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
