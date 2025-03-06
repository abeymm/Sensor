import SwiftUI
import SwiftData

#if os(watchOS)
import WatchKit
#endif

import OSLog

struct WatchContentView: View {
    @Environment(SensorManager.self) var sensorManager: SensorManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            WatchGlucoseView()
                .tag(0)
            
            WatchHistoryView()
                .tag(1)
            
            WatchSensorView()
                .tag(2)
        }
        .tabViewStyle(.page)
        .onChange(of: sensorManager.simulatedErrorState) { oldValue, newValue in
            if let errorState = newValue {
                // In a real app, this would trigger haptic feedback
                #if os(watchOS)
                // WKInterfaceDevice.current().play(.notification)
                #endif
                print("Watch error notification: \(errorState.rawValue)")
            }
        }
    }
}

struct WatchGlucoseView: View {
    @Environment(SensorManager.self) var sensorManager: SensorManager
    @Query private var userSettings: [UserSettings]
    
    public init() {
        // No parameters needed - @Query will fetch data automatically
    }
    
    private var currentSettings: UserSettings {
        userSettings.first ?? UserSettings()
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if let lastReading = sensorManager.lastReading {
                // Current glucose
                Text(formatGlucose(lastReading.valueMgdl))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(glucoseColor(for: lastReading.valueMgdl))
                
                // Unit
                Text(currentSettings.glucoseUnit == .mgdl ? "mg/dL" : "mmol/L")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Time ago
                Text(timeAgo(lastReading.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                // Trend
                trendArrow(for: sensorManager.readings)
                    .font(.system(size: 18))
                    .foregroundStyle(glucoseColor(for: lastReading.valueMgdl))
                
                // Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    
                    Text(connectionStatusText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
                
            } else {
                Text("--")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                
                Text(currentSettings.glucoseUnit == .mgdl ? "mg/dL" : "mmol/L")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if sensorManager.connectionStatus == .disconnected {
                    Button("Connect") {
                        sensorManager.connectToSensor()
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .padding(.top, 4)
                } else {
                    ProgressView()
                        .padding(.top, 8)
                }
            }
        }
        .navigationTitle("Glucose")
    }
    
    private func formatGlucose(_ value: Double) -> String {
        if currentSettings.glucoseUnit == .mgdl {
            return "\(Int(value))"
        } else {
            return String(format: "%.1f", value / 18.0)
        }
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
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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
    
    private var statusColor: Color {
        switch sensorManager.connectionStatus {
        case .connected:
            return .green
        case .intermittent:
            return .yellow
        case .connecting, .pairing:
            return .blue
        case .disconnected, .error:
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

struct WatchHistoryView: View {
    @Environment(SensorManager.self) var sensorManager: SensorManager
    
    var body: some View {
        List {
            if sensorManager.readings.isEmpty {
                Text("No readings available")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(sensorManager.readings.suffix(10).reversed())) { reading in
                    VStack(alignment: .leading) {
                        HStack {
                            Text("\(Int(reading.valueMgdl))")
                                .font(.system(.title3, design: .rounded))
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Text(formatTime(reading.timestamp))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(formatDate(reading.timestamp))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("History")
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

struct WatchSensorView: View {
    @Environment(SensorManager.self) var sensorManager: SensorManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let sensor = sensorManager.currentSensor {
                    // Sensor Status
                    HStack {
                        Circle()
                            .fill(statusColor(for: sensor))
                            .frame(width: 12, height: 12)
                        
                        Text(sensor.status.rawValue.capitalized)
                            .font(.headline)
                            .foregroundStyle(statusColor(for: sensor))
                    }
                    
                    // Battery
                    batteryView(level: sensor.batteryLevel)
                    
                    // Actions
                    if sensor.status == .active && sensorManager.connectionStatus != .connected {
                        Button("Connect") {
                            sensorManager.connectToSensor()
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    } else if sensorManager.connectionStatus == .connected {
                        Button("Disconnect") {
                            sensorManager.disconnectFromSensor()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                } else {
                    Text("No Active Sensor")
                        .font(.headline)
                    
                    Text("Use your iPhone to pair a new sensor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .navigationTitle("Sensor")
    }
    
    private func batteryView(level: Double) -> some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: batteryIcon(for: level))
                    .foregroundStyle(batteryColor(for: level))
                
                Text("\(Int(level * 100))%")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(batteryColor(for: level))
            }
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(batteryColor(for: level).gradient)
                    .frame(width: max(4, 80 * level), height: 6)
            }
        }
    }
    
    private func batteryIcon(for level: Double) -> String {
        if level <= 0.1 {
            return "battery.0"
        } else if level <= 0.25 {
            return "battery.25"
        } else if level <= 0.5 {
            return "battery.50"
        } else if level <= 0.75 {
            return "battery.75"
        } else {
            return "battery.100"
        }
    }
    
    private func batteryColor(for level: Double) -> Color {
        if level <= 0.1 {
            return .red
        } else if level <= 0.25 {
            return .orange
        } else {
            return .green
        }
    }
    
    private func statusColor(for sensor: SensorDevice) -> Color {
        switch sensor.status {
        case .active:
            return .green
        case .inactive:
            return .gray
        case .expired:
            return .orange
        case .error:
            return .red
        case .unknown:
            return .purple
        }
    }
}

#if os(watchOS)
class NotificationController: WKNotificationHostingController<NotificationView> {
    override var body: NotificationView {
        return NotificationView()
    }
}
#endif

struct NotificationView: View {
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.red)
            
            Text("Glucose Alert")
                .font(.headline)
            
            Text("Your glucose level is outside of your target range")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    WatchContentView()
        .environment(SensorManager.shared)
        .modelContainer(for: [GlucoseReading.self, UserSettings.self, SensorDevice.self], inMemory: true)
} 
