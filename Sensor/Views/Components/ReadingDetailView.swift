import SwiftUI
import SwiftData

struct ReadingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let reading: GlucoseReading
    @State private var note: String = ""
    @State private var selectedMeal: ReadingMetadata.MealProximity?
    @State private var hasExercise: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Glucose Reading") {
                    HStack {
                        Text("Value")
                        Spacer()
                        Text("\(Int(reading.valueMgdl)) mg/dL")
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Text("Time")
                        Spacer()
                        Text(formattedTime)
                    }
                    
                    HStack {
                        Text("Quality")
                        Spacer()
                        Text(reading.readingQuality.rawValue.capitalized)
                            .foregroundStyle(reading.readingQuality == .good ? .green : .orange)
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $note)
                        .frame(height: 100)
                }
                
                Section("Metadata") {
                    Picker("Meal", selection: $selectedMeal) {
                        Text("None").tag(Optional<ReadingMetadata.MealProximity>.none)
                        Text("Before Meal").tag(Optional<ReadingMetadata.MealProximity>.some(.preMeal))
                        Text("After Meal").tag(Optional<ReadingMetadata.MealProximity>.some(.postMeal))
                    }
                    
                    Toggle("Exercise", isOn: $hasExercise)
                }
                
                Section {
                    Button("Save Changes", action: saveChanges)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.blue)
                }
            }
            .navigationTitle("Reading Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Load existing data
                if let metadata = reading.metadata {
                    note = metadata.note ?? ""
                    selectedMeal = metadata.meal
                    hasExercise = metadata.hasExercise
                }
            }
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: reading.timestamp)
    }
    
    private func saveChanges() {
        // Create or update metadata
        let metadata = reading.metadata ?? ReadingMetadata()
        metadata.note = note.isEmpty ? nil : note
        metadata.meal = selectedMeal
        metadata.hasExercise = hasExercise
        
        // Attach to reading if not already
        if reading.metadata == nil {
            reading.metadata = metadata
        }
        
        // Save to database - the context will handle saving because
        // we're modifying a managed object
        
        dismiss()
    }
} 