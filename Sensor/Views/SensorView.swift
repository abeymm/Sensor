import SwiftUI
import SwiftData

struct SensorView: View {
    @Environment(SensorManager.self) var sensorManager: SensorManager
    @Query private var sensors: [SensorDevice]
    @State private var showingPairSheet = false
    
    public init() {
        // No parameters needed - @Query will fetch the data automatically
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if let currentSensor = sensorManager.currentSensor {
                    currentSensorView(currentSensor)
                } else {
                    noSensorView
                }
                
                Spacer()
                
                // Sensor simulation controls (for demo purposes)
                VStack {
                    Text("Simulation Controls")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    Button("Simulate Sensor Error") {
                        sensorManager.simulateSensorError()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Simulate Sensor Expiration") {
                        sensorManager.simulateSensorExpiration()
                    }
                    .buttonStyle(.bordered)
                    
                    Button(sensorManager.simulationEnabled ? "Disable Simulation" : "Enable Simulation") {
                        sensorManager.simulationEnabled.toggle()
                        if sensorManager.simulationEnabled && sensorManager.connectionStatus == .connected {
                            sensorManager.startDataSimulation()
                        } else {
                            sensorManager.stopDataSimulation()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.regularMaterial)
                )
                .padding()
                
                if !sensors.isEmpty {
                    // List of previously used sensors
                    sensorHistoryList
                }
            }
            .navigationTitle("Sensor Management")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPairSheet = true
                    } label: {
                        Label("Pair New", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingPairSheet) {
                SensorPairingView()
            }
        }
    }
    
    @ViewBuilder
    private func currentSensorView(_ sensor: SensorDevice) -> some View {
        VStack(spacing: 20) {
            // Sensor icon and name
            VStack {
                Image(systemName: "sensor.tag.radiowaves.forward.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                    .padding(.bottom, 8)
                
                Text(sensor.name)
                    .font(.title2.bold())
                
                Text(sensor.serialNumber)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // Status badge
                HStack {
                    Circle()
                        .fill(statusColor(for: sensor))
                        .frame(width: 8, height: 8)
                    
                    Text(statusText(for: sensor))
                        .font(.caption.bold())
                        .foregroundStyle(statusColor(for: sensor))
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background {
                    Capsule()
                        .fill(statusColor(for: sensor).opacity(0.1))
                }
            }
            .padding(.bottom, 16)
            
            // Sensor details
            VStack(spacing: 16) {
                detailRow(icon: "battery.100", title: "Battery Level", value: "\(Int(sensor.batteryLevel * 100))%")
                
                if let activationDate = sensor.activationDate {
                    detailRow(icon: "calendar.badge.clock", title: "Activated", value: dateFormatter.string(from: activationDate))
                }
                
                if let expirationDate = sensor.expirationDate {
                    detailRow(icon: "timer", title: "Expires", value: dateFormatter.string(from: expirationDate))
                    
                    // Time remaining bar
                    if sensor.status == .active, let activationDate = sensor.activationDate {
                        timeRemainingBar(activationDate: activationDate, expirationDate: expirationDate)
                    }
                }
                
                if let lastConnectionDate = sensor.lastConnectionDate {
                    detailRow(icon: "antenna.radiowaves.left.and.right", title: "Last Connection", value: timeAgo(lastConnectionDate))
                }
                
                detailRow(icon: "doc.badge.arrow.up", title: "Firmware", value: sensor.firmwareVersion)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
            }
            
            // Action buttons
            HStack(spacing: 20) {
                Button {
                    if sensorManager.connectionStatus == .connected {
                        sensorManager.disconnectFromSensor()
                    } else {
                        sensorManager.connectToSensor()
                    }
                } label: {
                    Label(
                        sensorManager.connectionStatus == .connected ? "Disconnect" : "Connect",
                        systemImage: sensorManager.connectionStatus == .connected ? "link.badge.minus" : "link"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(role: .destructive) {
                    if sensor.status == .active {
                        sensorManager.simulateSensorExpiration()
                    }
                } label: {
                    Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(sensor.status != .active)
            }
        }
        .padding()
    }
    
    private var noSensorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sensor.tag.radiowaves.forward.slash")
                .font(.system(size: 64))
                .foregroundStyle(.gray)
                .padding(.bottom, 20)
            
            Text("No Sensor Paired")
                .font(.title2.bold())
            
            Text("Pair a new sensor to start monitoring your glucose levels")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showingPairSheet = true
            } label: {
                Text("Pair Sensor")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.blue.gradient)
                    }
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        }
        .padding()
    }
    
    private var sensorHistoryList: some View {
        VStack(alignment: .leading) {
            Text("Sensor History")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(sensors.filter { !$0.isCurrent }) { sensor in
                        historySensorCard(for: sensor)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func historySensorCard(for sensor: SensorDevice) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "sensor.tag.radiowaves.forward")
                    .foregroundStyle(.secondary)
                
                Text(sensor.name)
                    .font(.headline)
                
                Spacer()
                
                // Status badge
                Text(sensor.status.rawValue.capitalized)
                    .font(.caption.bold())
                    .foregroundStyle(statusColor(for: sensor))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background {
                        Capsule()
                            .fill(statusColor(for: sensor).opacity(0.1))
                    }
            }
            
            Text(sensor.serialNumber)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if let activationDate = sensor.activationDate, let expirationDate = sensor.expirationDate {
                Text("Used \(dateRange(from: activationDate, to: expirationDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 200, height: 120)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        }
    }
    
    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(title)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .bold()
        }
    }
    
    private func timeRemainingBar(activationDate: Date, expirationDate: Date) -> some View {
        let maxLifespan = expirationDate.timeIntervalSince(activationDate)
        let elapsed = Date().timeIntervalSince(activationDate)
        let progress = min(1.0, max(0.0, elapsed / maxLifespan))
        let remaining = max(0, expirationDate.timeIntervalSince(Date()))
        let days = Int(remaining / 86400)  // seconds in a day
        let hours = Int((remaining.truncatingRemainder(dividingBy: 86400)) / 3600)
        
        return VStack(alignment: .leading, spacing: 6) {
            Text("Sensor Life")
                .foregroundStyle(.secondary)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.gray.opacity(0.2))
                        .cornerRadius(10)
                    
                    Rectangle()
                        .fill(progressColor(for: progress))
                        .cornerRadius(10)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 10)
            
            Text(days > 0 ? "\(days)d \(hours)h left" : "\(hours)h left")
                .font(.caption.bold())
                .foregroundStyle(progressColor(for: progress))
        }
    }
    
    // MARK: - Helper Methods
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func dateRange(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
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
    
    private func statusText(for sensor: SensorDevice) -> String {
        sensor.status.rawValue.capitalized
    }
    
    private func progressColor(for progress: Double) -> Color {
        if progress < 0.25 {
            return .red
        } else if progress < 0.75 {
            return .green
        } else {
            return .orange
        }
    }
}

#Preview {
    SensorView()
        .environment(SensorManager.shared)
        .modelContainer(for: [SensorDevice.self], inMemory: true)
} 
