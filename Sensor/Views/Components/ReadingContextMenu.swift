import SwiftUI
import SwiftData

struct ReadingContextMenu: ViewModifier {
    let reading: GlucoseReading
    let onAddNote: () -> Void
    let onMarkMeal: (ReadingMetadata.MealProximity) -> Void
    let onMarkActivity: () -> Void
    let onDelete: () -> Void
    
    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
                    onAddNote()
                } label: {
                    Label("Add Note", systemImage: "note.text")
                }
                
                Menu("Mark as Meal") {
                    Button {
                        onMarkMeal(.preMeal)
                    } label: {
                        Label("Before Meal", systemImage: "fork.knife")
                    }
                    
                    Button {
                        onMarkMeal(.postMeal)
                    } label: {
                        Label("After Meal", systemImage: "fork.knife.circle.fill")
                    }
                }
                
                Button {
                    onMarkActivity()
                } label: {
                    Label("Log Activity", systemImage: "figure.run")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Reading", systemImage: "trash")
                }
            } preview: {
                ReadingPreview(reading: reading)
            }
    }
}

// Make sure ReadingPreview has a public initializer
struct ReadingPreview: View {
    let reading: GlucoseReading
    @State private var userSettings: UserSettings?
    
    // Add an explicit public initializer
    init(reading: GlucoseReading) {
        self.reading = reading
    }
    
    private var currentSettings: UserSettings {
        userSettings ?? UserSettings()
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Glucose Reading")
                .font(.headline)
            
            Text(formatGlucose(reading.valueMgdl))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(glucoseColor(for: reading.valueMgdl))
            
            Text(formatDate(reading.timestamp))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let metadata = reading.metadata {
                if let mealType = metadata.meal {
                    HStack {
                        Image(systemName: "fork.knife")
                        Text(mealType.rawValue.capitalized)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .frame(width: 200, height: 200)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        }
        .onAppear {
            // Fetch settings on appear
            Task {
                let context = DataManager.shared.container.mainContext
                let descriptor = FetchDescriptor<UserSettings>()
                do {
                    let settings = try context.fetch(descriptor)
                    if let firstSettings = settings.first {
                        self.userSettings = firstSettings
                    }
                } catch {
                    print("Error fetching settings: \(error)")
                }
            }
        }
    }
    
    private func formatGlucose(_ value: Double) -> String {
        if currentSettings.glucoseUnit == .mgdl {
            return "\(Int(value)) mg/dL"
        } else {
            return String(format: "%.1f mmol/L", value / 18.0)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
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
}

extension View {
    func readingContextMenu(reading: GlucoseReading, onAddNote: @escaping () -> Void, onMarkMeal: @escaping (ReadingMetadata.MealProximity) -> Void, onMarkActivity: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        modifier(ReadingContextMenu(reading: reading, onAddNote: onAddNote, onMarkMeal: onMarkMeal, onMarkActivity: onMarkActivity, onDelete: onDelete))
    }
}

// Add a preview for the context menu
#Preview {
    Text("Glucose Reading: 120 mg/dL")
        .readingContextMenu(
            reading: GlucoseReading(
                valueMgdl: 120,
                sensorId: "TEST-001"
            ),
            onAddNote: {},
            onMarkMeal: { _ in },
            onMarkActivity: {},
            onDelete: {}
        )
        .modelContainer(for: [UserSettings.self], inMemory: true)
} 