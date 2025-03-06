import SwiftUI

struct SensorPairingView: View {
    @Environment(SensorManager.self) var sensorManager: SensorManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep = 0
    @State private var isScanning = false
    @State private var pairingError: String?
    
    var body: some View {
        NavigationStack {
            VStack {
                pairingStepView
            }
            .navigationTitle("Pair New Sensor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var pairingStepView: some View {
        switch currentStep {
        case 0:
            instructionsView
        case 1:
            scanningView
        case 2:
            completionView
        default:
            EmptyView()
        }
    }
    
    private var instructionsView: some View {
        VStack(spacing: 25) {
            Image(systemName: "sensor.tag.radiowaves.forward.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            Text("Pair a New Glucose Sensor")
                .font(.title2.bold())
            
            VStack(alignment: .leading, spacing: 15) {
                instructionStep(number: 1, text: "Remove the new sensor from its packaging")
                instructionStep(number: 2, text: "Clean the application site with alcohol and let it dry")
                instructionStep(number: 3, text: "Apply the sensor to the back of your upper arm")
                instructionStep(number: 4, text: "Tap 'Continue' to activate your sensor")
            }
            .padding(.vertical)
            
            Spacer()
            
            Button {
                currentStep = 1
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.blue.gradient)
                    }
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    private var scanningView: some View {
        VStack(spacing: 30) {
            // Animation for scanning
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 8)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(Angle(degrees: isScanning ? 360 : 0))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isScanning)
                
                Image(systemName: "sensor.tag.radiowaves.forward")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
            }
            
            Text("Scanning for Sensor")
                .font(.title2.bold())
            
            if let error = pairingError {
                Text(error)
                    .font(.headline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                Text("Hold your phone near the sensor to establish connection")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button {
                // Cancel scanning
                currentStep = 0
                pairingError = nil
            } label: {
                Text("Cancel Scan")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.gray.opacity(0.2))
                    }
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .onAppear {
            isScanning = true
            startSensorPairing()
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 25) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            Text("Sensor Paired Successfully!")
                .font(.title2.bold())
            
            Text("Your glucose sensor is now active and will begin taking readings automatically.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                infoRow(icon: "timer", title: "Sensor Duration", value: "14 days")
                infoRow(icon: "gauge", title: "Reading Interval", value: "Every 5 minutes")
                infoRow(icon: "arrow.clockwise", title: "Warm-up Period", value: "1 hour")
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.blue.gradient)
                    }
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    private func instructionStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(.blue))
            
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
    
    private func infoRow(icon: String, title: String, value: String) -> some View {
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
    
    private func startSensorPairing() {
        // Simulate the pairing process
        sensorManager.startSensorPairing()
        
        // Monitor connection status to update UI
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            switch sensorManager.connectionStatus {
            case .connected:
                timer.invalidate()
                currentStep = 2
            case .error:
                timer.invalidate()
                if let errorState = sensorManager.simulatedErrorState, errorState == .pairingFailed {
                    pairingError = "Failed to pair with sensor. Please try again."
                    // Automatically reset after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        isScanning = false
                        currentStep = 0
                    }
                }
            default:
                break
            }
        }
    }
}

#Preview {
    SensorPairingView()
        .environment(SensorManager.shared)
} 
