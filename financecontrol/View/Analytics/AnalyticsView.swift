//
//  AnalyticsView.swift
//  financecontrol
//
//  Created on 2026/09/14.
//

import SwiftUI
import Charts
import CoreData

// MARK: - Data Models

struct MonthlyBarData: Identifiable {
    let id = UUID()
    let month: Date
    let monthLabel: String
    let income: Double
    let expenses: Double
}

// MARK: - AnalyticsView

@available(iOS 16.0, *)
struct AnalyticsView: View {
    @EnvironmentObject
    private var cdm: CoreDataModel
    @EnvironmentObject
    private var rvm: RatesViewModel

    @AppStorage(UDKey.defaultCurrency.rawValue)
    private var defaultCurrency: String = Locale.current.currencyCode ?? "USD"

    @State private var monthlyIncome: Double = 0
    @State private var monthlyExpenses: Double = 0
    @State private var monthlyData: [MonthlyBarData] = []
    @State private var dailySpendings: [Int: Double] = [:]
    @State private var maxDailySpending: Double = 0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    incomeLeftCard

                    monthlyChart

                    calendarHeatmap
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Analytics")
            .onAppear {
                loadData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .UpdatePieChart)) { _ in
                loadData()
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Income Left Card

    private var incomeLeftCard: some View {
        let remaining = monthlyIncome - monthlyExpenses

        return VStack(spacing: 8) {
            Text("Income Left")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(formatSignedCurrency(remaining))
                .font(.system(.largeTitle, design: .rounded).bold())
                .foregroundStyle(remaining >= 0 ? .green : .red)
                .contentTransitionNumericText()

            HStack(spacing: 20) {
                Label {
                    Text(formatCurrency(monthlyIncome))
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.green)
                }

                Label {
                    Text(formatCurrency(monthlyExpenses))
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.pink)
                }
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Monthly Chart

    private var monthlyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Income vs Expenses")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            if monthlyData.allSatisfy({ $0.income == 0 && $0.expenses == 0 }) {
                Text("No data available")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart(monthlyData) { item in
                    BarMark(
                        x: .value("Month", item.monthLabel),
                        y: .value("Amount", item.income)
                    )
                    .foregroundStyle(Color.green.opacity(0.8))
                    .position(by: .value("Type", "Income"))

                    BarMark(
                        x: .value("Month", item.monthLabel),
                        y: .value("Amount", item.expenses)
                    )
                    .foregroundStyle(Color.pink.opacity(0.8))
                    .position(by: .value("Type", "Expenses"))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartLegend(position: .bottom) {
                    HStack(spacing: 16) {
                        Label("Income", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)

                        Label("Expenses", systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundStyle(.pink)
                    }
                }
                .frame(height: 220)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Calendar Heatmap

    private var calendarHeatmap: some View {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        let firstOfMonth = calendar.date(from: components) ?? now
        let range = calendar.range(of: .day, in: .month, for: firstOfMonth) ?? (1..<31)
        let daysInMonth = range.count

        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth)
        let firstWeekday = calendar.firstWeekday
        let startOffset = (weekdayOfFirst - firstWeekday + 7) % 7

        let symbols = calendar.shortWeekdaySymbols
        let reorderedSymbols: [String] = {
            let index = firstWeekday - 1
            return Array(symbols[index...]) + Array(symbols[..<index])
        }()

        let monthFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMMM yyyy"
            return f
        }()

        let todayDay = calendar.component(.day, from: now)

        return VStack(alignment: .leading, spacing: 8) {
            Text(monthFormatter.string(from: now))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                // Weekday headers
                ForEach(reorderedSymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                // Empty cells for offset
                ForEach(0..<startOffset, id: \.self) { _ in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }

                // Day cells
                ForEach(1...daysInMonth, id: \.self) { day in
                    let amount = dailySpendings[day] ?? 0
                    let intensity = maxDailySpending > 0 ? min(amount / maxDailySpending, 1.0) : 0
                    let isToday = day == todayDay

                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(amount > 0 ? max(intensity * 0.8, 0.1) : 0.03))

                        Text("\(day)")
                            .font(.caption2)
                            .fontWeight(isToday ? .bold : .regular)
                            .foregroundStyle(isToday ? Color.accentColor : .primary)
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Data Loading

    private func loadData() {
        let context = cdm.context
        context.perform {
            let rates = UserDefaults.standard.getUnwrapedRates()
            let defaultRate = rates[self.defaultCurrency] ?? 1
            let localDefaultCurrency = self.defaultCurrency

            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = now.getFirstDayOfMonth()
            let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? now

            // MARK: Current month data
            let currentMonthRequest = SpendingEntity.fetchRequest()
            currentMonthRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SpendingEntity.date, ascending: false)]
            currentMonthRequest.predicate = NSPredicate(
                format: "date >= %@ AND date < %@",
                startOfMonth as CVarArg,
                startOfNextMonth as CVarArg
            )

            var income: Double = 0
            var expenses: Double = 0
            var dailyMap: [Int: Double] = [:]

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

                        let day = calendar.component(.day, from: spending.wrappedDate)
                        dailyMap[day, default: 0] += amount
                    }
                }
            } catch {
                // Fail silently, data will show as zero
            }

            // MARK: Last 6 months data
            var monthlyItems: [MonthlyBarData] = []
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

                var monthIncome: Double = 0
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

                        if spending.category?.isIncome == true {
                            monthIncome += amount
                        } else {
                            monthExpenses += amount
                        }
                    }
                } catch {
                    // Fail silently
                }

                monthlyItems.append(MonthlyBarData(
                    month: monthStart,
                    monthLabel: monthFormatter.string(from: monthStart),
                    income: monthIncome,
                    expenses: monthExpenses
                ))
            }

            let maxDaily = dailyMap.values.max() ?? 0

            DispatchQueue.main.async {
                withAnimation(.easeOut) {
                    self.monthlyIncome = income
                    self.monthlyExpenses = expenses
                    self.monthlyData = monthlyItems
                    self.dailySpendings = dailyMap
                    self.maxDailySpending = maxDaily
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

    private func formatSignedCurrency(_ amount: Double) -> String {
        let formatted = formatCurrency(abs(amount))
        if amount < 0 {
            return "-\(formatted)"
        }
        return formatted
    }
}
