import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SensorManager.self) var sensorManager: SensorManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GlucoseHomeView()
                .tabItem {
                    Label("Dashboard", systemImage: "waveform.path.ecg")
                }
                .tag(0)
            
            SensorView()
                .tabItem {
                    Label("Sensor", systemImage: "sensor")
                }
                .tag(1)
            
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "chart.xyaxis.line")
                }
                .tag(2)
            
            SettingsView()
                .environment(sensorManager)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
        }
        .onChange(of: sensorManager.simulatedErrorState) { oldValue, newValue in
            if let errorState = newValue {
                showErrorNotification(for: errorState)
            }
        }
    }
    
    private func showErrorNotification(for error: ErrorState) {
        // This would trigger local notifications in a real app
        print("Error notification: \(error.rawValue)")
    }
}

#Preview {
    ContentView()
        .environment(SensorManager.shared)
        .modelContainer(for: [GlucoseReading.self, SensorDevice.self, UserSettings.self], inMemory: true)
} 
