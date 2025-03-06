import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var userSettings: [UserSettings] = []
    @Environment(SensorManager.self) var sensorManager: SensorManager
    
    // Settings state
    @State private var glucoseUnit: UserSettings.GlucoseUnit = .mgdl
    @State private var lowThreshold: Double = 70
    @State private var highThreshold: Double = 180
    @State private var urgentLowThreshold: Double = 55
    @State private var urgentHighThreshold: Double = 250
    @State private var notificationsEnabled: Bool = true
    @State private var healthKitSyncEnabled: Bool = true
    @State private var predictionsEnabled: Bool = true
    
    // UI State
    @State private var showingResetConfirmation = false
    @State private var showingAbout = false
    
    public init() {
        // No parameters needed
    }
    
    var body: some View {
        NavigationStack {
            Form {
                unitsSection
                thresholdsSection
                notificationsSection
                healthIntegrationSection
                predictionsSection
                simulationSection
                miscSection
            }
            .navigationTitle("Settings")
            .toolbar {
                connectionButton
            }
            .alert("Reset to Default Settings?", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetToDefaultSettings()
                }
            } message: {
                Text("This will reset all settings to their default values.")
            }
            .sheet(isPresented: $showingAbout) {
                aboutView
            }
            .onAppear {
                loadSettings()
                loadCurrentSettings()
            }
        }
    }
    
    private var aboutView: some View {
        VStack(spacing: 20) {
            Image(systemName: "drop.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .padding(.top, 40)
            
            Text("Glucose Monitor")
                .font(.title.bold())
            
            Text("Version 1.0")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("This app demonstrates the use of modern SwiftUI and SwiftData to create a medical monitoring app with:")
                    .font(.headline)
                    .padding(.top)
                
                bulletPoint("Observable state management")
                bulletPoint("Simulated sensor communication")
                bulletPoint("Interactive charts and visualizations")
                bulletPoint("Comprehensive data storage")
                bulletPoint("Modern iOS 18 features")
                
                if sensorManager.connectionStatus == .connected {
                    Text("Status: Connected to sensor")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.top)
                }
            }
            .padding()
            
            Spacer()
        }
        .padding()
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top) {
            Text("•")
                .font(.headline)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
    
    private func thresholdSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, color: Color, mmol: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(formatThresholdValue(value.wrappedValue, mmol: mmol))
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
            
            Slider(value: value, in: range, step: step) {
                Text(title)
            } minimumValueLabel: {
                Text(formatThresholdValue(range.lowerBound, mmol: mmol))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text(formatThresholdValue(range.upperBound, mmol: mmol))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tint(color)
        }
    }
    
    private func formatThresholdValue(_ value: Double, mmol: Bool) -> String {
        if mmol {
            return String(format: "%.1f", value)
        } else {
            return "\(Int(value))"
        }
    }
    
    private func loadSettings() {
        let context = DataManager.shared.container.mainContext
        let descriptor = FetchDescriptor<UserSettings>()
        do {
            userSettings = try context.fetch(descriptor)
            if userSettings.isEmpty {
                // Create default settings if none exist
                let defaultSettings = UserSettings()
                context.insert(defaultSettings)
                userSettings = [defaultSettings]
                try context.save()
            }
        } catch {
            print("Error fetching settings: \(error)")
        }
    }
    
    private func loadCurrentSettings() {
        guard let settings = userSettings.first else { return }
        
        // Load values from saved settings
        glucoseUnit = settings.glucoseUnit
        lowThreshold = settings.lowThreshold
        highThreshold = settings.highThreshold
        urgentLowThreshold = settings.urgentLowThreshold
        urgentHighThreshold = settings.urgentHighThreshold
        notificationsEnabled = settings.notificationsEnabled
        healthKitSyncEnabled = settings.healthKitSyncEnabled
        predictionsEnabled = settings.predictionsEnabled
    }
    
    private func updateSettingsIfNeeded() {
        guard let settings = userSettings.first else { return }
        
        // Update settings only if they've changed
        if settings.glucoseUnit != glucoseUnit ||
           settings.lowThreshold != lowThreshold ||
           settings.highThreshold != highThreshold ||
           settings.urgentLowThreshold != urgentLowThreshold ||
           settings.urgentHighThreshold != urgentHighThreshold ||
           settings.notificationsEnabled != notificationsEnabled ||
           settings.healthKitSyncEnabled != healthKitSyncEnabled ||
           settings.predictionsEnabled != predictionsEnabled {
            
            // Update all settings
            settings.glucoseUnit = glucoseUnit
            settings.lowThreshold = lowThreshold
            settings.highThreshold = highThreshold
            settings.urgentLowThreshold = urgentLowThreshold
            settings.urgentHighThreshold = urgentHighThreshold
            settings.notificationsEnabled = notificationsEnabled
            settings.healthKitSyncEnabled = healthKitSyncEnabled
            settings.predictionsEnabled = predictionsEnabled
            
            // Save changes
            do {
                try modelContext.save()
            } catch {
                print("Error saving settings: \(error.localizedDescription)")
            }
        }
    }
    
    private func resetToDefaultSettings() {
        // Set default values
        glucoseUnit = .mgdl
        lowThreshold = 70
        highThreshold = 180
        urgentLowThreshold = 55
        urgentHighThreshold = 250
        notificationsEnabled = true
        healthKitSyncEnabled = true
        predictionsEnabled = true
        
        // Save changes
        updateSettingsIfNeeded()
    }
    
    private var unitsSection: some View {
        Section("Glucose Units") {
            Picker("Unit System", selection: $glucoseUnit) {
                Text("mg/dL").tag(UserSettings.GlucoseUnit.mgdl)
                Text("mmol/L").tag(UserSettings.GlucoseUnit.mmol)
            }
            .pickerStyle(.segmented)
            .onChange(of: glucoseUnit) { _, newValue in
                updateSettingsIfNeeded()
            }
        }
    }
    
    private var thresholdsSection: some View {
        Section("Glucose Thresholds") {
            if glucoseUnit == .mgdl {
                mgdlThresholds
            } else {
                mmolThresholds
            }
        }
        .onChange(of: lowThreshold) { _, _ in updateSettingsIfNeeded() }
        .onChange(of: highThreshold) { _, _ in updateSettingsIfNeeded() }
        .onChange(of: urgentLowThreshold) { _, _ in updateSettingsIfNeeded() }
        .onChange(of: urgentHighThreshold) { _, _ in updateSettingsIfNeeded() }
    }
    
    private var mgdlThresholds: some View {
        Group {
            thresholdSlider(title: "Low Threshold", value: $lowThreshold, range: 60...90, step: 5, color: .orange)
            thresholdSlider(title: "High Threshold", value: $highThreshold, range: 140...220, step: 5, color: .orange)
            thresholdSlider(title: "Urgent Low", value: $urgentLowThreshold, range: 40...60, step: 5, color: .red)
            thresholdSlider(title: "Urgent High", value: $urgentHighThreshold, range: 200...350, step: 5, color: .red)
        }
    }
    
    private var mmolThresholds: some View {
        Group {
            thresholdSlider(title: "Low Threshold", value: $lowThreshold, range: 3.3...5.0, step: 0.1, color: .orange, mmol: true)
            thresholdSlider(title: "High Threshold", value: $highThreshold, range: 7.8...12.2, step: 0.1, color: .orange, mmol: true)
            thresholdSlider(title: "Urgent Low", value: $urgentLowThreshold, range: 2.2...3.3, step: 0.1, color: .red, mmol: true)
            thresholdSlider(title: "Urgent High", value: $urgentHighThreshold, range: 11.1...19.4, step: 0.1, color: .red, mmol: true)
        }
    }
    
    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Enable Notifications", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, _ in updateSettingsIfNeeded() }
            
            if notificationsEnabled {
                NavigationLink("Notification Preferences") {
                    Text("Notification preferences would go here")
                }
            }
        }
    }
    
    private var healthIntegrationSection: some View {
        Section("Health Integration") {
            Toggle("Sync with HealthKit", isOn: $healthKitSyncEnabled)
                .onChange(of: healthKitSyncEnabled) { _, _ in updateSettingsIfNeeded() }
        }
    }
    
    private var predictionsSection: some View {
        Section("Glucose Predictions") {
            Toggle("Enable Predictions", isOn: $predictionsEnabled)
                .onChange(of: predictionsEnabled) { _, _ in 
                    updateSettingsIfNeeded()
                }
            
            if predictionsEnabled {
                Text("Predict glucose values up to 30 minutes in advance based on trend data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var simulationSection: some View {
        Section("Simulation Settings") {
            Toggle("Enable Simulation", isOn: Binding(
                get: { sensorManager.simulationEnabled },
                set: { newValue in
                    sensorManager.simulationEnabled = newValue
                    if newValue && sensorManager.connectionStatus == .connected {
                        sensorManager.startDataSimulation()
                    } else {
                        sensorManager.stopDataSimulation()
                    }
                }
            ))
            
            Stepper(
                value: Binding(
                    get: { sensorManager.errorProbability },
                    set: { sensorManager.errorProbability = $0 }
                ),
                in: 0...0.5,
                step: 0.05
            ) {
                HStack {
                    Text("Error Probability")
                    Spacer()
                    Text("\(Int(sensorManager.errorProbability * 100))%")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var miscSection: some View {
        Section {
            Button("Reset All Settings") {
                showingResetConfirmation = true
            }
            .foregroundStyle(.red)
            
            NavigationLink("About Glucose Monitor") {
                aboutView
            }
        }
    }
    
    private var connectionButton: some View {
        Button("Connection: \(sensorManager.connectionStatus == .connected ? "On" : "Off")") {
            if sensorManager.connectionStatus == .connected {
                sensorManager.disconnectFromSensor()
            } else {
                sensorManager.connectToSensor()
            }
        }
        .tint(sensorManager.connectionStatus == .connected ? .green : .red)
    }
}

#Preview {
    SettingsView()
        .environment(SensorManager.shared)
        .modelContainer(for: [UserSettings.self], inMemory: true)
} 
