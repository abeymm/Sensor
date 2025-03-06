import SwiftUI
import Charts
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SensorManager.self) var sensorManager: SensorManager
    @Query(sort: \GlucoseReading.timestamp, order: .reverse) private var allReadings: [GlucoseReading]
    @Query private var userSettings: [UserSettings]
    
    @State private var selectedDay: Date = Date()
    @State private var selectedReading: GlucoseReading?
    @State private var showingReadingDetails = false
    @State private var viewMode: ViewMode = .daily
    
    public init() {
        // No parameters needed - @Query will fetch the data automatically
    }
    
    private var currentSettings: UserSettings {
        userSettings.first ?? UserSettings()
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode picker
                Picker("View Mode", selection: $viewMode) {
                    Text("Daily").tag(ViewMode.daily)
                    Text("Weekly").tag(ViewMode.weekly)
                    Text("Monthly").tag(ViewMode.monthly)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Date selector
                dateSelector
                
                // Wrap the main content in a ScrollView
                ScrollView {
                    // Main content based on view mode
                    switch viewMode {
                    case .daily:
                        dailyView
                    case .weekly:
                        weeklyView
                    case .monthly:
                        monthlyView
                    }
                    
                    // Add some bottom padding for scroll comfort
                    Spacer().frame(height: 30)
                }
            }
            .navigationTitle("Glucose History")
            .sheet(isPresented: $showingReadingDetails) {
                if let reading = selectedReading {
                    ReadingDetailView(reading: reading)
                }
            }
        }
    }
    
    private var dateSelector: some View {
        HStack {
            Button {
                adjustDate(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            Text(dateText)
                .font(.headline)
            
            Spacer()
            
            Button {
                adjustDate(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .fontWeight(.semibold)
            }
            .disabled(isToday)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    private var dailyView: some View {
        VStack(spacing: 16) {
            // Daily stats
            dailyStatsView
            
            // Hourly graph
            dailyChartView
            
            // Readings list
            readingsList
        }
    }
    
    private var weeklyView: some View {
        VStack(spacing: 16) {
            // Weekly stats
            weeklyStatsView
            
            // Daily averages
            weeklyChartView
            
            // Daily stats list
            dailyStatsList
        }
    }
    
    private var monthlyView: some View {
        VStack(spacing: 16) {
            // Monthly stats
            monthlyStatsView
            
            // Weekly averages
            monthlyChartView
            
            // Week stats list
            weeklyStatsList
        }
    }
    
    private var dailyStatsView: some View {
        let dailyReadings = readingsForSelectedDay
        
        let avgValue = dailyReadings.isEmpty ? 0 : dailyReadings.reduce(0) { $0 + $1.valueMgdl } / Double(dailyReadings.count)
        let minValue = dailyReadings.min(by: { $0.valueMgdl < $1.valueMgdl })?.valueMgdl ?? 0
        let maxValue = dailyReadings.max(by: { $0.valueMgdl < $1.valueMgdl })?.valueMgdl ?? 0
        
        return HStack {
            statsCard(title: "Average", value: formatGlucose(avgValue), color: glucoseColor(for: avgValue))
            statsCard(title: "Lowest", value: formatGlucose(minValue), color: glucoseColor(for: minValue))
            statsCard(title: "Highest", value: formatGlucose(maxValue), color: glucoseColor(for: maxValue))
        }
        .padding(.horizontal)
    }
    
    private var dailyChartView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hourly Trends")
                .font(.headline)
            
            if dailyReadings.isEmpty {
                Text("No data available for this day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
            } else {
                Chart {
                    // Fix the Line/Point mark issue by using ForEach
                    ForEach(dailyReadings, id: \.id) { reading in
                        PointMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("Glucose", currentSettings.glucoseUnit == .mgdl ? reading.valueMgdl : reading.valueInMmol)
                        )
                        .foregroundStyle(glucoseColor(for: reading.valueMgdl))
                    }
                    
                    // Connect points with a line
                    ForEach(dailyReadings, id: \.id) { reading in
                        LineMark(
                            x: .value("Time", reading.timestamp),
                            y: .value("Glucose", currentSettings.glucoseUnit == .mgdl ? reading.valueMgdl : reading.valueInMmol)
                        )
                        .foregroundStyle(Color.blue.opacity(0.7))
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // Target range rectangle
                    RectangleMark(
                        xStart: .value("", dailyReadings.map { $0.timestamp }.min() ?? Date()),
                        xEnd: .value("", dailyReadings.map { $0.timestamp }.max() ?? Date()),
                        yStart: .value("Low", currentSettings.glucoseUnit == .mgdl ? currentSettings.lowThreshold : currentSettings.lowThreshold / 18.0),
                        yEnd: .value("High", currentSettings.glucoseUnit == .mgdl ? currentSettings.highThreshold : currentSettings.highThreshold / 18.0)
                    )
                    .foregroundStyle(Color.green.opacity(0.1))
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        }
    }
    
    private var readingsList: some View {
        VStack(alignment: .leading) {
            Text("Readings")
                .font(.headline)
                .padding(.horizontal)
            
            List {
                if readingsForSelectedDay.isEmpty {
                    Text("No readings for this day")
                        .foregroundStyle(.secondary)
                        .padding(.vertical)
                } else {
                    ForEach(readingsForSelectedDay) { reading in
                        Button {
                            selectedReading = reading
                            showingReadingDetails = true
                        } label: {
                            readingRow(reading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
        }
    }
    
    private var weeklyStatsView: some View {
        let weekReadings = readingsForSelectedWeek
        
        let avgValue = weekReadings.isEmpty ? 0 : weekReadings.reduce(0) { $0 + $1.valueMgdl } / Double(weekReadings.count)
        let minValue = weekReadings.min(by: { $0.valueMgdl < $1.valueMgdl })?.valueMgdl ?? 0
        let maxValue = weekReadings.max(by: { $0.valueMgdl < $1.valueMgdl })?.valueMgdl ?? 0
        
        let inRange = calculateTimeInRange(readings: weekReadings, min: currentSettings.lowThreshold, max: currentSettings.highThreshold)
        
        return VStack(spacing: 16) {
            HStack {
                statsCard(title: "Average", value: formatGlucose(avgValue), color: glucoseColor(for: avgValue))
                statsCard(title: "In Range", value: "\(Int(inRange))%", color: .green)
            }
            
            HStack {
                statsCard(title: "Lowest", value: formatGlucose(minValue), color: glucoseColor(for: minValue))
                statsCard(title: "Highest", value: formatGlucose(maxValue), color: glucoseColor(for: maxValue))
            }
        }
        .padding(.horizontal)
    }
    
    private var weeklyChartView: some View {
        VStack(alignment: .leading) {
            Text("Daily Averages")
                .font(.headline)
                .padding(.horizontal)
            
            Chart {
                ForEach(0..<7, id: \.self) { dayOffset in
                    let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: startOfWeek)!
                    let dayReadings = allReadings.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }
                    
                    if !dayReadings.isEmpty {
                        let avgValue = dayReadings.reduce(0) { $0 + $1.valueMgdl } / Double(dayReadings.count)
                        
                        BarMark(
                            x: .value("Day", date, unit: .day),
                            y: .value("Average", currentSettings.glucoseUnit == .mgdl ? avgValue : avgValue / 18.0)
                        )
                        .foregroundStyle(glucoseColor(for: avgValue))
                    }
                }
                
                // Thresholds
                RuleMark(y: .value("High", currentSettings.glucoseUnit == .mgdl ? currentSettings.highThreshold : currentSettings.highThreshold / 18.0))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                
                RuleMark(y: .value("Low", currentSettings.glucoseUnit == .mgdl ? currentSettings.lowThreshold : currentSettings.lowThreshold / 18.0))
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            .chartYScale(domain: currentSettings.glucoseUnit == .mgdl ? 40...300 : 2...16.7)
            .frame(height: 220)
            .padding(.horizontal)
        }
    }
    
    private var dailyStatsList: some View {
        VStack(alignment: .leading) {
            Text("Daily Statistics")
                .font(.headline)
                .padding(.horizontal)
            
            List {
                ForEach(0..<7, id: \.self) { dayOffset in
                    let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: startOfWeek)!
                    let dayReadings = allReadings.filter { Calendar.current.isDate($0.timestamp, inSameDayAs: date) }
                    
                    if !dayReadings.isEmpty {
                        dailyStatsRow(date: date, readings: dayReadings)
                    }
                }
            }
            .listStyle(.plain)
        }
    }
    
    private var monthlyStatsView: some View {
        VStack(spacing: 12) {
            Text("Monthly Overview")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            GridLayout {
                statsCard(title: "Average", value: formatGlucose(calculateMonthlyAverage()), color: .blue)
                statsCard(title: "In Range", value: "\(Int(calculateMonthlyInRangePercentage()))%", color: .green)
                statsCard(title: "Readings", value: "\(monthlyReadings.count)", color: .purple)
                statsCard(title: "Highest", value: formatGlucose(monthlyHighest()), color: .orange)
            }
            .padding(.vertical, 4)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        }
    }
    
    private var monthlyChartView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly Trends")
                .font(.headline)
            
            if monthlyReadings.isEmpty {
                Text("No data available for this month")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
            } else {
                Chart {
                    // Group readings by day
                    ForEach(Array(monthlyDailyAverages.keys.sorted()), id: \.self) { day in
                        if let avg = monthlyDailyAverages[day] {
                            BarMark(
                                x: .value("Day", day, unit: .day),
                                y: .value("Glucose", avg)
                            )
                            .foregroundStyle(glucoseColor(for: avg))
                        }
                    }
                    
                    // Add target range rules
                    RuleMark(y: .value("High", currentSettings.glucoseUnit == .mgdl ? currentSettings.highThreshold : currentSettings.highThreshold / 18.0))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    
                    RuleMark(y: .value("Low", currentSettings.glucoseUnit == .mgdl ? currentSettings.lowThreshold : currentSettings.lowThreshold / 18.0))
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        }
    }
    
    private var weeklyStatsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Summaries")
                .font(.headline)
            
            if weeklyReadingsByDay.isEmpty {
                Text("No data available for this week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                List {
                    ForEach(Array(weeklyReadingsByDay.keys.sorted().reversed()), id: \.self) { day in
                        if let readings = weeklyReadingsByDay[day] {
                            HStack {
                                Text(formatDayShort(from: day))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(width: 100, alignment: .leading)
                                
                                Spacer()
                                
                                Text("Avg: \(formatGlucose(calculateDailyAverage(readings)))")
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Text("\(readings.count) readings")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    private var monthlyReadings: [GlucoseReading] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: selectedDay)
        guard let startOfMonth = calendar.date(from: components),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return []
        }
        
        return allReadings.filter { reading in
            reading.timestamp >= startOfMonth && reading.timestamp < nextMonth
        }
    }
    
    private var monthlyDailyAverages: [Date: Double] {
        let calendar = Calendar.current
        var averagesByDay: [Date: Double] = [:]
        
        let readingsByDay = Dictionary(grouping: monthlyReadings) { reading in
            calendar.startOfDay(for: reading.timestamp)
        }
        
        for (day, readings) in readingsByDay {
            let sum = readings.reduce(0.0) { $0 + $1.valueMgdl }
            averagesByDay[day] = sum / Double(readings.count)
        }
        
        return averagesByDay
    }
    
    private func calculateMonthlyAverage() -> Double {
        guard !monthlyReadings.isEmpty else { return 0 }
        let sum = monthlyReadings.reduce(0.0) { $0 + $1.valueMgdl }
        return sum / Double(monthlyReadings.count)
    }
    
    private func calculateMonthlyInRangePercentage() -> Double {
        guard !monthlyReadings.isEmpty else { return 0 }
        
        let inRangeCount = monthlyReadings.filter { reading in
            reading.valueMgdl >= currentSettings.lowThreshold && reading.valueMgdl <= currentSettings.highThreshold
        }.count
        
        return Double(inRangeCount) / Double(monthlyReadings.count) * 100
    }
    
    private func monthlyHighest() -> Double {
        monthlyReadings.map { $0.valueMgdl }.max() ?? 0
    }
    
    private var weeklyReadingsByDay: [Date: [GlucoseReading]] {
        let calendar = Calendar.current
        let readingsByDay = Dictionary(grouping: readingsForSelectedWeek) { reading in
            calendar.startOfDay(for: reading.timestamp)
        }
        return readingsByDay
    }
    
    private func calculateDailyAverage(_ readings: [GlucoseReading]) -> Double {
        guard !readings.isEmpty else { return 0 }
        let sum = readings.reduce(0.0) { $0 + $1.valueMgdl }
        return sum / Double(readings.count)
    }
    
    private func formatDayShort(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
    
    private func statsCard(title: String, value: String, color: Color) -> some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    struct GridLayout: Layout {
        var columnCount: Int = 2
        
        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let width = proposal.width ?? 0
            let spacing: CGFloat = 8
            let columnWidth = (width - (spacing * CGFloat(columnCount - 1))) / CGFloat(columnCount)
            
            var height: CGFloat = 0
            for row in 0..<(subviews.count + columnCount - 1) / columnCount {
                var rowHeight: CGFloat = 0
                for column in 0..<columnCount {
                    let index = row * columnCount + column
                    guard index < subviews.count else { continue }
                    
                    let _ = columnWidth // Use it or remove it
                    let subviewSize = subviews[index].sizeThatFits(.unspecified)
                    rowHeight = max(rowHeight, subviewSize.height)
                }
                
                if row > 0 {
                    height += spacing
                }
                height += rowHeight
            }
            
            return CGSize(width: width, height: height)
        }
        
        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            let width = bounds.width
            let spacing: CGFloat = 8
            let columnWidth = (width - (spacing * CGFloat(columnCount - 1))) / CGFloat(columnCount)
            
            var y: CGFloat = bounds.minY
            for row in 0..<(subviews.count + columnCount - 1) / columnCount {
                var rowHeight: CGFloat = 0
                var subviewSizes: [CGSize] = []
                
                // Calculate sizes and find tallest item in row
                for column in 0..<columnCount {
                    let index = row * columnCount + column
                    guard index < subviews.count else { continue }
                    
                    let _ = columnWidth // Use it or remove it
                    let subviewSize = subviews[index].sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
                    subviewSizes.append(subviewSize)
                    rowHeight = max(rowHeight, subviewSize.height)
                }
                
                // Place items in row
                for column in 0..<columnCount {
                    let index = row * columnCount + column
                    guard index < subviews.count else { continue }
                    
                    let x = bounds.minX + CGFloat(column) * (columnWidth + spacing)
                    subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: columnWidth, height: rowHeight))
                }
                
                y += rowHeight + spacing
            }
        }
    }
    
    private var dailyReadings: [GlucoseReading] {
        readingsForSelectedDay
    }
    
    private var readingsForSelectedDay: [GlucoseReading] {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: selectedDay)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        return allReadings.filter { reading in
            reading.timestamp >= startDate && reading.timestamp < endDate
        }
    }
    
    private var readingsForSelectedWeek: [GlucoseReading] {
        let startDate = startOfWeek
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
        
        return allReadings.filter { reading in
            reading.timestamp >= startDate && reading.timestamp < endDate
        }
    }
    
    private var startOfWeek: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDay))!
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDay)
    }
    
    private var dateText: String {
        let formatter = DateFormatter()
        
        switch viewMode {
        case .daily:
            formatter.dateFormat = "EEEE, MMM d, yyyy"
        case .weekly:
            formatter.dateFormat = "MMM d"
            let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek)!
            return "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek))"
        case .monthly:
            formatter.dateFormat = "MMMM yyyy"
        }
        
        return formatter.string(from: selectedDay)
    }
    
    private func adjustDate(by amount: Int) {
        let calendar = Calendar.current
        switch viewMode {
        case .daily:
            selectedDay = calendar.date(byAdding: .day, value: amount, to: selectedDay)!
        case .weekly:
            selectedDay = calendar.date(byAdding: .weekOfYear, value: amount, to: selectedDay)!
        case .monthly:
            selectedDay = calendar.date(byAdding: .month, value: amount, to: selectedDay)!
        }
    }
    
    private func readingRow(_ reading: GlucoseReading) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(formatGlucose(reading.valueMgdl))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(glucoseColor(for: reading.valueMgdl))
                
                Text(formatTime(reading.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Add any indicator for notes or other metadata
            if let metadata = reading.metadata, let note = metadata.note, !note.isEmpty {
                Image(systemName: "note.text")
                    .foregroundStyle(.secondary)
            }
            
            if let meal = reading.metadata?.meal {
                Image(systemName: meal == .preMeal ? "fork.knife" : "fork.knife.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func dailyStatsRow(date: Date, readings: [GlucoseReading]) -> some View {
        let avgValue = readings.reduce(0.0) { $0 + $1.valueMgdl } / Double(readings.count)
        
        return HStack {
            Text(formatDayOnly(date))
                .font(.subheadline)
                .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            Text(formatGlucose(avgValue))
                .font(.body)
                .foregroundStyle(glucoseColor(for: avgValue))
            
            Spacer()
            
            Text("\(readings.count) readings")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDayOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
    
    private func calculateTimeInRange(readings: [GlucoseReading], min: Double, max: Double) -> Double {
        guard !readings.isEmpty else { return 0 }
        
        let inRangeCount = readings.filter { $0.valueMgdl >= min && $0.valueMgdl <= max }.count
        return Double(inRangeCount) / Double(readings.count) * 100
    }
    
    private func formatGlucose(_ value: Double) -> String {
        if currentSettings.glucoseUnit == .mgdl {
            return "\(Int(value))"
        } else {
            return String(format: "%.1f", value / 18.0)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func glucoseColor(for value: Double) -> Color {
        if value < currentSettings.lowThreshold {
            return .red
        } else if value > currentSettings.highThreshold {
            return .orange
        } else {
            return .green
        }
    }
    
    enum ViewMode {
        case daily
        case weekly
        case monthly
    }
}

struct GridLayout_Previews: PreviewProvider {
    static var previews: some View {
        Text("Grid Layout")
            .frame(width: 200, height: 100)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .environment(SensorManager.shared)
    .modelContainer(for: [GlucoseReading.self, UserSettings.self], inMemory: true)
}
