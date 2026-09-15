//
//  HomeView.swift
//  Squirrel
//
//  Created by PinkXaciD on 2023/06/26.
//

import SwiftUI
#if canImport(Charts)
import Charts
#endif

// MARK: - TodayTransaction Model

struct TodayTransaction: Identifiable {
    let id: UUID
    let emoji: String
    let name: String
    let amount: Double
    let isIncome: Bool
    let currency: String
}

// MARK: - MonthlyChartPoint Model

struct MonthlyChartPoint: Identifiable {
    let id = UUID()
    let month: String
    let amount: Double
    let isCurrent: Bool
}

// MARK: - HomeView

struct HomeView: View {
    @Environment(\.managedObjectContext)
    private var viewContext
    @Environment(\.colorScheme)
    private var colorScheme

    @EnvironmentObject
    private var cdm: CoreDataModel
    @EnvironmentObject
    private var rvm: RatesViewModel

    // Keep BarChartViewModel environment object to avoid crashes (injected from ContentView)
    @EnvironmentObject
    private var barChartViewModel: BarChartViewModel

    @AppStorage(UDKey.updateRates.rawValue)
    private var updateRates: Bool = false
    @AppStorage("LatestLaunchedBuild")
    private var latestLaunchedBuild: Int = -1
    @AppStorage(UDKey.defaultCurrency.rawValue)
    private var defaultCurrency: String = Locale.current.currencyCode ?? "USD"

    @State
    private var ratesAreFetching: Bool = UserDefaults.standard.bool(forKey: UDKey.updateRates.rawValue)
    @State
    private var showWhatsNew: Bool = false
    @State
    private var animateWhatsNewButton: Bool = false

    // New Home data state
    @State private var monthlyIncome: Double = 0
    @State private var monthlyExpenses: Double = 0
    @State private var monthlyChartData: [MonthlyChartPoint] = []
    @State private var todayTransactions: [TodayTransaction] = []

    @Binding
    var showingSheet: Bool
    @Binding
    var presentOnboarding: Bool

    let cloudSyncWasEnabled: Bool
    let currentBuild = Int(Bundle.main.buildVersionNumber ?? "") ?? 0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Header
                    headerSection

                    // 2. Month Selector
                    monthSelectorSection

                    // 3. Income Left Summary
                    incomeLeftSection

                    // 4. Income / Spent Breakdown
                    incomeSpentBreakdown

                    // 5. Line Chart
                    lineChartSection

                    // 6 & 7. Today Section
                    todaySection

                    // What's new button (if applicable)
                    if latestLaunchedBuild < 91 {
                        whatsNewButton
                    }

                    // Rates fetch status
                    if ratesAreFetching {
                        ratesFetchStatus
                    }

                    // Bottom spacer for tab bar clearance
                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 20)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationBarHidden(true)
            .overlay(alignment: .bottomTrailing) {
                addExpenseButton
            }
            .sheet(isPresented: $showingSheet) {
                AddSpendingView(
                    ratesViewModel: rvm,
                    codeDataModel: cdm
                )
                .addColorPresentationBackground()
            }
            .sheet(isPresented: $showWhatsNew) {
                latestLaunchedBuild = currentBuild
            } content: {
                WhatsNewView()
            }
            .onChange(of: rvm.status) { newValue in
                if newValue == .success || newValue == .failed {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            ratesAreFetching = false
                        }
                    }
                } else if newValue == .downloading {
                    withAnimation {
                        ratesAreFetching = true
                    }
                }
            }
            .onAppear {
                loadHomeData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .UpdatePieChart)) { _ in
                loadHomeData()
            }
        }
        .navigationViewStyle(.stack)
        .animation(.default, value: latestLaunchedBuild)
    }

    // MARK: - 1. Header

    private var headerSection: some View {
        HStack {
            Text("Galla")
                .font(.system(size: 32, weight: .bold, design: .default))

            Spacer()

            Button(action: {}) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.primary)
            }
        }
        .padding(.top, 16)
    }

    // MARK: - 2. Month Selector

    private var monthSelectorSection: some View {
        HStack {
            Spacer()

            HStack(spacing: 6) {
                Text("This month")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .stroke(Color(uiColor: .separator), lineWidth: 1)
            )

            Spacer()
        }
    }

    // MARK: - 3. Income Left Summary

    private var incomeLeftSection: some View {
        let remaining = monthlyIncome - monthlyExpenses

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formatCurrency(abs(remaining)))
                    .font(.system(size: 54, weight: .bold, design: .default))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text("left")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
            }

            Divider()
                .padding(.top, 4)
        }
    }

    // MARK: - 4. Income / Spent Breakdown

    private var incomeSpentBreakdown: some View {
        HStack(spacing: 0) {
            // Income column
            VStack(alignment: .leading, spacing: 4) {
                Text(formatCurrency(monthlyIncome))
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("income")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Vertical divider
            Rectangle()
                .fill(Color(uiColor: .separator))
                .frame(width: 1, height: 44)

            // Spent column
            VStack(alignment: .leading, spacing: 4) {
                Text(formatCurrency(monthlyExpenses))
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("spent")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
        }
    }

    // MARK: - 5. Line Chart

    private var lineChartSection: some View {
        VStack(spacing: 12) {
            if #available(iOS 16.0, *) {
                lineChartContent
            } else {
                // Fallback for older iOS: simple text summary
                Text(formatCurrency(monthlyExpenses))
                    .font(.title2.bold())
                    .foregroundStyle(Color.primary)
                Text("spent this month")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }

            // Month labels below the chart
            if !monthlyChartData.isEmpty {
                HStack {
                    ForEach(monthlyChartData) { point in
                        Text(point.month)
                            .font(.caption)
                            .fontWeight(point.isCurrent ? .bold : .regular)
                            .foregroundStyle(point.isCurrent ? Color.primary : Color.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    @available(iOS 16.0, *)
    private var lineChartContent: some View {
        Group {
            if monthlyChartData.isEmpty || monthlyChartData.allSatisfy({ $0.amount == 0 }) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 120)
                    .overlay {
                        Text("No spending data yet")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
            } else {
                Chart(monthlyChartData) { item in
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Amount", item.amount)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    if item.isCurrent {
                        PointMark(
                            x: .value("Month", item.month),
                            y: .value("Amount", item.amount)
                        )
                        .symbol {
                            ZStack {
                                Circle()
                                    .fill(Color(uiColor: .systemBackground))
                                    .frame(width: 10, height: 10)
                                Circle()
                                    .stroke(Color.primary, lineWidth: 2)
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .frame(height: 120)
            }
        }
    }

    // MARK: - 6 & 7. Today Section

    private var todaySection: some View {
        VStack(spacing: 12) {
            // Section header
            HStack {
                Text("Today")
                    .font(.system(size: 24, weight: .bold))

                Spacer()

                HStack(spacing: 4) {
                    Text("See all")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
            }

            // Transaction list
            if todayTransactions.isEmpty {
                VStack(spacing: 8) {
                    Text("No transactions today")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(todayTransactions.enumerated()), id: \.element.id) { index, transaction in
                        transactionRow(transaction)

                        if index < todayTransactions.count - 1 {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                }
            }
        }
    }

    private func transactionRow(_ transaction: TodayTransaction) -> some View {
        HStack(spacing: 12) {
            // Emoji icon
            Text(transaction.emoji)
                .font(.system(size: 28))
                .frame(width: 36, height: 36)

            // Name
            Text(transaction.name)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(Color.primary)
                .lineLimit(1)

            Spacer()

            // Amount
            if transaction.isIncome {
                Text("+" + formatCurrency(transaction.amount))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color(red: 0.149, green: 0.831, blue: 0.522)) // #26D485
            } else {
                Text("\u{2212}" + formatCurrency(transaction.amount))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primary)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Floating Add Button

    private var addExpenseButton: some View {
        Button(action: toggleSheet) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 16)
    }

    // MARK: - What's New Button

    private var whatsNewButton: some View {
        Button {
            showWhatsNew.toggle()
        } label: {
            ZStack {
                Text("What's new in \(Bundle.main.releaseVersionNumber ?? "")")
                    .foregroundStyle(gradient)
                    .opacity(animateWhatsNewButton ? 0 : 0.75)
                    .blur(radius: 5)

                Text("What's new in \(Bundle.main.releaseVersionNumber ?? "")")
                    .foregroundStyle(gradient)
            }
        }
        .hueRotation(.degrees(animateWhatsNewButton ? 720 : 0))
        .onAppear {
            withAnimation(.linear(duration: 5).delay(0.5)) {
                animateWhatsNewButton = true
            }
        }
        .onDisappear {
            animateWhatsNewButton = false
        }
    }

    // MARK: - Gradient (preserved from original)

    private var gradient: LinearGradient {
        let colors = stride(from: 0, to: 1, by: 0.05).map { value in
            Color(
                lightness: colorScheme.colorLightness,
                chroma: 0.12,
                hue: value * 360
            )
        }

        return .init(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - Rates Fetch Status

    private var ratesFetchStatus: some View {
        HStack(spacing: 7) {
            switch rvm.status {
            case .downloading:
                ProgressView()
                    .tint(.secondary)

                Text("Updating rates...")

            case .waitingForNetwork:
                if #available(iOS 17.0, *) {
                    Image(systemName: "network.slash")
                        .font(.body.bold())
                } else {
                    Image(systemName: "network")
                        .font(.body.bold())
                }

                Text("No network")

            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.body.bold())

                Text("Failed to update rates")

            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.body.bold())

                Text("Rates updated")

            case .tryingAgain:
                ProgressView()
                    .tint(.secondary)

                Text("Trying again...")

            default:
                ProgressView()
                    .tint(.secondary)

                Text("Updating rates...")
            }
        }
        .padding(.vertical, 3)
        .foregroundStyle(Color.secondary)
        .font(.footnote)
        .animation(.default, value: rvm.status)
    }

    // MARK: - Data Loading

    private func loadHomeData() {
        let context = cdm.context
        context.perform {
            let rates = UserDefaults.standard.getUnwrapedRates()
            let localDefaultCurrency = self.defaultCurrency
            let defaultRate = rates[localDefaultCurrency] ?? 1

            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = now.getFirstDayOfMonth()
            let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? now

            // MARK: Current month income & expenses
            let currentMonthRequest = SpendingEntity.fetchRequest()
            currentMonthRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SpendingEntity.date, ascending: false)]
            currentMonthRequest.predicate = NSPredicate(
                format: "date >= %@ AND date < %@",
                startOfMonth as CVarArg,
                startOfNextMonth as CVarArg
            )

            var income: Double = 0
            var expenses: Double = 0

            do {
                let spendings = try context.fetch(currentMonthRequest)

                for spending in spendings {
                    let amount: Double = {
                        if spending.wrappedCurrency == localDefaultCurrency {
                            return spending.amountWithReturns
                        }
                        return spending.amountUSDWithReturns * defaultRate
                    }()

                    if spending.category?.isIncome == true {
                        income += amount
                    } else {
                        expenses += amount
                    }
                }
            } catch {
                // Fail silently
            }

            // MARK: Last 6 months spending data for line chart
            var chartPoints: [MonthlyChartPoint] = []
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMM"

            for offset in stride(from: 5, through: 0, by: -1) {
                let monthStart = now.getFirstDayOfMonth(-offset)
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now

                let request = SpendingEntity.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \SpendingEntity.date, ascending: false)]
                request.predicate = NSPredicate(
                    format: "date >= %@ AND date < %@",
                    monthStart as CVarArg,
                    monthEnd as CVarArg
                )

                var monthExpenses: Double = 0

                do {
                    let monthSpendings = try context.fetch(request)

                    for spending in monthSpendings {
                        let amount: Double = {
                            if spending.wrappedCurrency == localDefaultCurrency {
                                return spending.amountWithReturns
                            }
                            return spending.amountUSDWithReturns * defaultRate
                        }()

                        if spending.category?.isIncome != true {
                            monthExpenses += amount
                        }
                    }
                } catch {
                    // Fail silently
                }

                chartPoints.append(MonthlyChartPoint(
                    month: monthFormatter.string(from: monthStart),
                    amount: monthExpenses,
                    isCurrent: offset == 0
                ))
            }

            // MARK: Today's transactions
            let startOfToday = calendar.startOfDay(for: now)
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now

            let todayRequest = SpendingEntity.fetchRequest()
            todayRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SpendingEntity.date, ascending: false)]
            todayRequest.predicate = NSPredicate(
                format: "date >= %@ AND date < %@",
                startOfToday as CVarArg,
                startOfTomorrow as CVarArg
            )

            var transactions: [TodayTransaction] = []

            do {
                let todaySpendings = try context.fetch(todayRequest)

                for spending in todaySpendings {
                    let amount: Double = {
                        if spending.wrappedCurrency == localDefaultCurrency {
                            return spending.amountWithReturns
                        }
                        return spending.amountUSDWithReturns * defaultRate
                    }()

                    let categoryName = spending.category?.name ?? "Uncategorized"
                    let placeName = spending.place
                    let isIncome = spending.category?.isIncome ?? false

                    let emoji = extractEmoji(from: categoryName)
                    let displayName: String = {
                        if let place = placeName, !place.isEmpty {
                            return place
                        }
                        return extractName(from: categoryName)
                    }()

                    transactions.append(TodayTransaction(
                        id: spending.wrappedId,
                        emoji: emoji,
                        name: displayName,
                        amount: amount,
                        isIncome: isIncome,
                        currency: spending.wrappedCurrency
                    ))
                }
            } catch {
                // Fail silently
            }

            DispatchQueue.main.async {
                withAnimation(.easeOut) {
                    self.monthlyIncome = income
                    self.monthlyExpenses = expenses
                    self.monthlyChartData = chartPoints
                    self.todayTransactions = transactions
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Double) -> String {
        Locale.autoupdatingCurrent.currencyNarrowFormat(
            amount,
            currency: defaultCurrency,
            showCurrencySymbol: true
        ) ?? amount.formatted(.currency(code: defaultCurrency))
    }

    private func extractEmoji(from name: String) -> String {
        guard let first = name.first, first.isEmoji else { return "\u{1F4C1}" }
        return String(first)
    }

    private func extractName(from name: String) -> String {
        let trimmed = name.drop(while: { !$0.isLetter && !$0.isNumber })
        return String(trimmed).trimmingCharacters(in: .whitespaces)
    }

    func toggleSheet() {
        showingSheet = true
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(showingSheet: .constant(false), presentOnboarding: .constant(false), cloudSyncWasEnabled: false)
            .environmentObject(CoreDataModel())
    }
}
