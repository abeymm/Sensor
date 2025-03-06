import SwiftUI
import Charts
import SwiftData

struct GlucoseHomeView: View {
    @Environment(SensorManager.self) var sensorManager: SensorManager
    @Query private var userSettings: [UserSettings]
    @State private var selectedDataPoint: GlucoseDataPoint?
    @State private var chartTimeWindow: TimeWindow = .hours6
    
    // Default initializer 
    public init() {
        // No parameters needed
    }
    
    private var currentSettings: UserSettings {
        userSettings.first ?? UserSettings()
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Current glucose card
                    currentGlucoseCard
                    
                    // Trend Chart
                    glucoseChartView
                    
                    // Stats and insights
                    statsView
                }
                .padding(.horizontal)
            }
            .navigationTitle("Glucose Monitor")
            .refreshable {
                // Simulate refresh by generating a new reading
                if sensorManager.connectionStatus == .connected {
                    sensorManager.generateReadingForActiveDevice()
                }
            }
        }
    }
    
    private var currentGlucoseCard: some View {
        VStack(spacing: 8) {
            if let lastReading = sensorManager.lastReading {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Glucose")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatGlucose(lastReading.valueMgdl))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(glucoseColor(for: lastReading.valueMgdl))
                            
                            Text(currentSettings.glucoseUnit == .mgdl ? "mg/dL" : "mmol/L")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text(timeAgo(lastReading.timestamp))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if lastReading.readingQuality != .good {
                                Text("• \(lastReading.readingQuality.rawValue.capitalized)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        trendArrow(for: sensorManager.readings)
                            .font(.system(size: 32))
                            .foregroundStyle(glucoseColor(for: lastReading.valueMgdl))
                        
                        connectionStatusView
                    }
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Glucose")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("--")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        Text("No recent readings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    connectionStatusView
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        }
    }
    
    private var glucoseChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Glucose Trend")
                    .font(.headline)
                
                Spacer()
                
                Menu {
                    Button {
                        withAnimation { chartTimeWindow = .hours3 }
                    } label: {
                        Label("3 Hours", systemImage: chartTimeWindow == .hours3 ? "checkmark" : "")
                    }
                    
                    Button {
                        withAnimation { chartTimeWindow = .hours6 }
                    } label: {
                        Label("6 Hours", systemImage: chartTimeWindow == .hours6 ? "checkmark" : "")
                    }
                    
                    Button {
                        withAnimation { chartTimeWindow = .hours12 }
                    } label: {
                        Label("12 Hours", systemImage: chartTimeWindow == .hours12 ? "checkmark" : "")
                    }
                    
                    Button {
                        withAnimation { chartTimeWindow = .hours24 }
                    } label: {
                        Label("24 Hours", systemImage: chartTimeWindow == .hours24 ? "checkmark" : "")
                    }
                } label: {
                    Label("\(timeWindowString) \(Image(systemName: "chevron.down"))", systemImage: "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            chartView
                .frame(height: 220)
            
            if selectedDataPoint != nil {
                selectedPointInfo
            } else {
                thresholdLegend
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        }
    }
    
    private var chartView: some View {
        Chart {
            // Actual readings
            ForEach(Array(zip(filteredReadings.indices, filteredReadings)), id: \.0) { _, reading in
                PointMark(
                    x: .value("Time", reading.timestamp),
                    y: .value("Glucose", currentSettings.glucoseUnit == .mgdl ? reading.valueMgdl : reading.valueInMmol)
                )
                .foregroundStyle(glucoseColor(for: reading.valueMgdl))
                .symbol {
                    Circle()
                        .fill(glucoseColor(for: reading.valueMgdl))
                        .frame(width: 8, height: 8)
                }
            }
            
            if filteredReadings.count > 1 {
                ForEach(Array(zip(filteredReadings.indices, filteredReadings)), id: \.0) { _, reading in
                    LineMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("Glucose", currentSettings.glucoseUnit == .mgdl ? reading.valueMgdl : reading.valueInMmol)
                    )
                    .foregroundStyle(Color.blue.opacity(0.7))
                    .interpolationMethod(.catmullRom)
                }
            }
            
            // Prediction curve
            if currentSettings.predictionsEnabled && filteredPredictions.count > 1 {
                ForEach(filteredPredictions, id: \.timestamp) { prediction in
                    LineMark(
                        x: .value("Time", prediction.timestamp),
                        y: .value("Glucose", currentSettings.glucoseUnit == .mgdl ? prediction.value : prediction.value / 18.0)
                    )
                    .foregroundStyle(.blue.opacity(0.5))
                }
            }
            
            // Target range rectangle
            RectangleMark(
                xStart: .value("", minTime),
                xEnd: .value("", maxTime),
                yStart: .value("Low", currentSettings.glucoseUnit == .mgdl ? currentSettings.lowThreshold : currentSettings.lowThreshold / 18.0),
                yEnd: .value("High", currentSettings.glucoseUnit == .mgdl ? currentSettings.highThreshold : currentSettings.highThreshold / 18.0)
            )
            .foregroundStyle(Color.green.opacity(0.1))
            
            // Threshold lines
            RuleMark(y: .value("High", currentSettings.glucoseUnit == .mgdl ? currentSettings.highThreshold : currentSettings.highThreshold / 18.0))
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            
            RuleMark(y: .value("Low", currentSettings.glucoseUnit == .mgdl ? currentSettings.lowThreshold : currentSettings.lowThreshold / 18.0))
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            
            // Selection point
            if let point = selectedDataPoint {
                PointMark(
                    x: .value("Selected Time", point.timestamp),
                    y: .value("Selected Glucose", currentSettings.glucoseUnit == .mgdl ? point.value : point.value / 18.0)
                )
                .foregroundStyle(.purple)
                .symbol {
                    Circle()
                        .stroke(.purple, lineWidth: 2)
                        .background(Circle().fill(.white))
                        .frame(width: 12, height: 12)
                }
            }
        }
        .chartYScale(domain: calculateYDomain())
        .chartXScale(domain: [minTime, maxTime])
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let plotFrame = proxy.plotFrame else {
                                    selectedDataPoint = nil
                                    return
                                }
                                let x = value.location.x - geometry[plotFrame].origin.x
                                guard x >= 0, x <= geometry[plotFrame].width else {
                                    selectedDataPoint = nil
                                    return
                                }
                                
                                let timestamp = proxy.value(atX: x, as: Date.self)!
                                
                                // Find the nearest data point
                                let allDataPoints = filteredReadings.map { 
                                    GlucoseDataPoint(timestamp: $0.timestamp, value: $0.valueMgdl)
                                } + filteredPredictions
                                
                                if let nearest = allDataPoints.min(by: { 
                                    abs($0.timestamp.timeIntervalSince(timestamp)) < abs($1.timestamp.timeIntervalSince(timestamp))
                                }) {
                                    selectedDataPoint = nearest
                                }
                            }
                            .onEnded { _ in
                                // Keep the selected point visible
                            }
                    )
                    .onTapGesture {
                        // Clear selection on tap outside a point
                        selectedDataPoint = nil
                    }
            }
        }
    }
    
    private var selectedPointInfo: some View {
        guard let point = selectedDataPoint else { return AnyView(EmptyView()) }
        
        return AnyView(
            HStack {
                VStack(alignment: .leading) {
                    Text("\(formatTime(point.timestamp))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(formatGlucose(point.value))
                            .font(.headline)
                        
                        Text(currentSettings.glucoseUnit == .mgdl ? "mg/dL" : "mmol/L")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Only show prediction badge for predicted points
                if sensorManager.predictionCurve.contains(where: { $0.id == point.id }) {
                    Text("Predicted")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background {
                            Capsule()
                                .fill(Color.purple.opacity(0.2))
                        }
                }
                
                Button {
                    selectedDataPoint = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        )
    }
    
    private var thresholdLegend: some View {
        HStack(spacing: 20) {
            legendItem(color: .red, label: "Low", value: formatGlucose(currentSettings.lowThreshold))
            legendItem(color: .green, label: "Target", value: "In Range")
            legendItem(color: .orange, label: "High", value: formatGlucose(currentSettings.highThreshold))
            
            if currentSettings.predictionsEnabled {
                HStack {
                    Circle()
                        .stroke(Color.purple, lineWidth: 2)
                        .frame(width: 8, height: 8)
                    
                    Text("Predicted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var statsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
            
            HStack {
                statCard(
                    value: calculateInRangePercentage(),
                    label: "In Range",
                    color: .green
                )
                
                Spacer()
                
                statCard(
                    value: calculateAverageGlucose(),
                    label: "Average",
                    color: .blue,
                    isGlucose: true
                )
                
                Spacer()
                
                statCard(
                    value: calculateReadingCount(),
                    label: "Readings",
                    color: .purple,
                    isSuffix: " 📊"
                )
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        }
    }
    
    private var connectionStatusView: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(connectionStatusText)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(statusColor.opacity(0.1))
        }
    }
    
    // MARK: - Helper Views
    
    private func legendItem(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.caption.bold())
            }
        }
    }
    
    private func statCard(value: Double, label: String, color: Color, isGlucose: Bool = false, isSuffix: String = "") -> some View {
        VStack {
            if isGlucose {
                Text(formatGlucose(value))
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            } else {
                Text("\(Int(value))\(isSuffix)")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            }
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func trendArrow(for readings: [GlucoseReading]) -> some View {
        let arrowName: String
        
        // Need at least 3 readings to determine trend
        guard readings.count >= 3 else {
            return Image(systemName: "arrow.forward")
        }
        
        // Calculate the average rate of change over the last 3 readings
        let recentReadings = Array(readings.suffix(3))
        var totalChange = 0.0
        var timeSpan = 0.0
        
        for i in 1..<recentReadings.count {
            let timeDiff = recentReadings[i].timestamp.timeIntervalSince(recentReadings[i-1].timestamp)
            let valueDiff = recentReadings[i].valueMgdl - recentReadings[i-1].valueMgdl
            totalChange += valueDiff
            timeSpan += timeDiff
        }
        
        // Calculate rate of change per minute
        let avgChange = timeSpan > 0 ? (totalChange / timeSpan) * 15 : 0
        
        // Determine arrow direction based on rate of change
        if abs(avgChange) < 1 {
            arrowName = "arrow.forward"
        } else if avgChange > 10 {
            arrowName = "arrow.up.right.circle.fill"
        } else if avgChange > 3 {
            arrowName = "arrow.up.right"
        } else if avgChange > 1 {
            arrowName = "arrow.up.forward"
        } else if avgChange < -10 {
            arrowName = "arrow.down.right.circle.fill"
        } else if avgChange < -3 {
            arrowName = "arrow.down.right"
        } else {
            arrowName = "arrow.down.forward"
        }
        
        return Image(systemName: arrowName)
    }
    
    // MARK: - Helper Functions
    
    private var filteredReadings: [GlucoseReading] {
        let cutoff = maxTime.addingTimeInterval(-getTimeWindowInSeconds())
        return sensorManager.readings.filter { $0.timestamp >= cutoff }
    }
    
    private var filteredPredictions: [GlucoseDataPoint] {
        sensorManager.predictionCurve.filter { $0.timestamp <= maxTime }
    }
    
    private var minTime: Date {
        maxTime.addingTimeInterval(-getTimeWindowInSeconds())
    }
    
    private var maxTime: Date {
        Date()
    }
    
    private func getTimeWindowInSeconds() -> TimeInterval {
        switch chartTimeWindow {
        case .hours3:
            return 3 * 60 * 60
        case .hours6:
            return 6 * 60 * 60
        case .hours12:
            return 12 * 60 * 60
        case .hours24:
            return 24 * 60 * 60
        }
    }
    
    private var timeWindowString: String {
        switch chartTimeWindow {
        case .hours3:
            return "3 Hours"
        case .hours6:
            return "6 Hours"
        case .hours12:
            return "12 Hours"
        case .hours24:
            return "24 Hours"
        }
    }
    
    private func calculateYDomain() -> ClosedRange<Double> {
        let unit = currentSettings.glucoseUnit
        
        // Base domain
        var minValue: Double = unit == .mgdl ? 40 : 2.2
        var maxValue: Double = unit == .mgdl ? 300 : 16.7
        
        // Adjust based on data if available
        if !filteredReadings.isEmpty {
            let readingValues = filteredReadings.map { unit == .mgdl ? $0.valueMgdl : $0.valueInMmol }
            let dataMin = readingValues.min() ?? minValue
            let dataMax = readingValues.max() ?? maxValue
            
            // Provide some padding
            minValue = min(minValue, max(0, dataMin * 0.9))
            maxValue = max(maxValue, dataMax * 1.1)
        }
        
        return minValue...maxValue
    }
    
    private func calculateInRangePercentage() -> Double {
        guard !filteredReadings.isEmpty else { return 0 }
        
        let inRangeCount = filteredReadings.filter { reading in
            reading.valueMgdl >= currentSettings.lowThreshold && 
            reading.valueMgdl <= currentSettings.highThreshold
        }.count
        
        return Double(inRangeCount) / Double(filteredReadings.count) * 100
    }
    
    private func calculateAverageGlucose() -> Double {
        guard !filteredReadings.isEmpty else { return 0 }
        
        let sum = filteredReadings.reduce(0.0) { $0 + $1.valueMgdl }
        return sum / Double(filteredReadings.count)
    }
    
    private func calculateReadingCount() -> Double {
        Double(filteredReadings.count)
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
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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
    
    private var statusColor: Color {
        switch sensorManager.connectionStatus {
        case .connected:
            return .green
        case .connecting, .pairing:
            return .blue
        case .disconnected:
            return .gray
        case .intermittent:
            return .yellow
        case .error:
            return .red
        }
    }
    
    private var connectionStatusText: String {
        switch sensorManager.connectionStatus {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .pairing:
            return "Pairing..."
        case .intermittent:
            return "Signal Weak"
        case .error:
            return "Error"
        }
    }
}

enum TimeWindow {
    case hours3
    case hours6
    case hours12
    case hours24
}

#Preview {
    GlucoseHomeView()
        .environment(SensorManager.shared)
        .modelContainer(for: [UserSettings.self, GlucoseReading.self], inMemory: true)
} 
