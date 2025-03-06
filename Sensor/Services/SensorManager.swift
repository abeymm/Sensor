import Foundation
import CoreBluetooth
import CoreNFC
import Observation
import OSLog
import SwiftData
import SwiftUI

@Observable
final class SensorManager {
    static let shared = SensorManager()
    private let logger = Logger(subsystem: "com.expertcraft.sensor", category: "SensorManager")
    
    // Sensor state
    private(set) var currentSensorId: String?
    private var _currentSensor: SensorDevice?
    private(set) var connectionStatus: ConnectionStatus = .disconnected
    private(set) var lastReading: GlucoseReading?
    private(set) var readings: [GlucoseReading] = []
    private(set) var predictionCurve: [GlucoseDataPoint] = []
    
    // Error simulation
    var simulatedErrorState: ErrorState?
    var errorProbability: Double = 0.05
    
    // Simulation settings
    var simulationEnabled = true
    var simulationInterval: TimeInterval = 60 // 1 minute
    var simulationTimer: Timer?
    
    // Mock sensors
    private var mockBluetoothManager: CBCentralManager?
    private var mockNFCSession: NFCTagReaderSession?
    
    // Lifecycle
    private init() {
        setupBluetooth()
    }
    
    // MARK: - Public Methods
    
    func connectToSensor() {
        guard connectionStatus != .connected else { return }
        
        connectionStatus = .connecting
        logger.info("Connecting to sensor...")
        
        // Simulate connection delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            
            if Bool.random() && self.errorProbability > Double.random(in: 0...1) {
                self.connectionStatus = .error
                self.simulatedErrorState = .connectionFailed
                self.logger.error("Connection failed (simulated)")
            } else {
                self.connectionStatus = .connected
                self.startDataSimulation()
                self.logger.info("Connected to sensor (simulated)")
            }
        }
    }
    
    func disconnectFromSensor() {
        stopDataSimulation()
        connectionStatus = .disconnected
        logger.info("Disconnected from sensor")
    }
    
    func startSensorPairing() {
        connectionStatus = .pairing
        logger.info("Starting NFC pairing sequence...")
        
        // Simulate NFC session
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            
            if Bool.random() && self.errorProbability > Double.random(in: 0...1) {
                self.connectionStatus = .error
                self.simulatedErrorState = .pairingFailed
                self.logger.error("Pairing failed (simulated)")
            } else {
                // Create and activate new sensor
                let sensor = SensorDevice(
                    activationDate: Date(),
                    expirationDate: Date().addingTimeInterval(72 * 3600), // 72 hours
                    lastConnectionDate: Date(),
                    status: .active,
                    isCurrent: true
                )
                
                self.currentSensor = sensor
                self.connectionStatus = .connected
                
                Task {
                    await self.saveNewSensor(sensor)
                }
                
                self.startDataSimulation()
                self.logger.info("Pairing completed successfully (simulated)")
            }
        }
    }
    
    func simulateSensorExpiration() {
        guard let sensor = currentSensor else { return }
        
        let updatedSensor = SensorDevice(
            id: sensor.id,
            name: sensor.name,
            batteryLevel: 0.05,
            serialNumber: sensor.serialNumber,
            firmwareVersion: sensor.firmwareVersion,
            activationDate: sensor.activationDate,
            expirationDate: Date(), // Expired now
            lastConnectionDate: Date(),
            status: .expired,
            isCurrent: false
        )
        
        currentSensor = updatedSensor
        connectionStatus = .error
        simulatedErrorState = .sensorExpired
        stopDataSimulation()
        
        Task {
            await updateSensor(updatedSensor)
        }
    }
    
    public func generateReadingForActiveDevice() {
        guard let _ = currentSensor,
              connectionStatus == .connected else {
            return 
        }
        
        generateSimulatedReading()
    }
    
    // MARK: - Private Methods
    
    private func setupBluetooth() {
        // Mock Bluetooth setup
        mockBluetoothManager = CBCentralManager(delegate: nil, queue: nil)
        logger.info("Bluetooth manager initialized")
    }
    
    func startDataSimulation() {
        guard simulationEnabled else { return }
        
        stopDataSimulation() // Stop any existing simulation
        
        simulationTimer = Timer.scheduledTimer(withTimeInterval: simulationInterval, repeats: true) { [weak self] _ in
            self?.generateSimulatedReading()
        }
        
        // Generate first reading immediately
        generateSimulatedReading()
        logger.info("Started data simulation with interval: \(self.simulationInterval)s")
    }
    
    func stopDataSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        logger.info("Stopped data simulation")
    }
    
    private func generateSimulatedReading() {
        guard let sensor = currentSensor, connectionStatus == .connected else { 
            return
        }
        
        // Check for simulated errors
        if errorProbability > Double.random(in: 0...1) {
            simulateSensorError()
            return
        }
        
        // Generate a realistic glucose value based on previous readings
        let baseValue: Double
        if let last = lastReading {
            // Small random change from last reading
            let change = Double.random(in: -10...10)
            baseValue = max(40, min(400, last.valueMgdl + change))
        } else {
            // Starting value in normal range
            baseValue = Double.random(in: 80...120)
        }
        
        // Apply time-of-day effects (dawn phenomenon, etc)
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let timeOfDayEffect: Double
        
        switch hour {
        case 4...7: // Dawn phenomenon
            timeOfDayEffect = Double.random(in: 5...15)
        case 11...13: // Lunch effect
            timeOfDayEffect = Double.random(in: 10...30)
        case 17...19: // Dinner effect
            timeOfDayEffect = Double.random(in: 15...35)
        case 22...23: // Night drop
            timeOfDayEffect = Double.random(in: -15...(-5))
        default:
            timeOfDayEffect = Double.random(in: -5...5)
        }
        
        let finalValue = max(40, min(400, baseValue + timeOfDayEffect))
        
        let reading = GlucoseReading(
            valueMgdl: finalValue,
            sensorId: sensor.id,
            readingQuality: .good
        )
        
        lastReading = reading
        readings.append(reading)
        
        // Keep only last 24 hours of readings
        let dayAgo = Date().addingTimeInterval(-24 * 3600)
        readings = readings.filter { $0.timestamp > dayAgo }
        
        // Generate prediction curve
        generatePredictionCurve()
        
        // Update sensor connection date
        Task {
            await saveReading(reading)
        }
        
        logger.info("Generated reading: \(finalValue) mg/dL")
    }
    
    func simulateSensorError() {
        guard let errorType = ErrorState.allCases.randomElement() else { return }
        
        simulatedErrorState = errorType
        
        switch errorType {
        case .signalLoss:
            connectionStatus = .intermittent
            logger.warning("Simulated error: signal loss")
            
            // Recover after some time
            let recoveryTimes = [30.0, 120.0, 300.0] // 30s, 2m, 5m
            let recoveryTime = recoveryTimes.randomElement() ?? 30.0
            
            DispatchQueue.main.asyncAfter(deadline: .now() + recoveryTime) { [weak self] in
                guard let self = self else { return }
                if self.simulatedErrorState == .signalLoss {
                    self.connectionStatus = .connected
                    self.simulatedErrorState = nil
                    self.logger.info("Signal recovered after \(recoveryTime)s")
                }
            }
            
        case .dataCorruption:
            // Generate corrupt reading
            if let sensor = currentSensor {
                let corruptReading = GlucoseReading(
                    valueMgdl: Double.random(in: 40...400),
                    sensorId: sensor.id,
                    readingQuality: .uncertain
                )
                
                lastReading = corruptReading
                readings.append(corruptReading)
                
                Task {
                    await saveReading(corruptReading)
                }
            }
            
            simulatedErrorState = nil
            logger.warning("Simulated error: data corruption")
            
        case .pairingFailed:
            connectionStatus = .error
            logger.warning("Simulated error: pairing failed")
            
            // Auto-recover after 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self = self else { return }
                if self.simulatedErrorState == .pairingFailed {
                    self.simulatedErrorState = nil
                    self.connectionStatus = .disconnected
                    self.logger.info("Reset after pairing failure")
                }
            }
            
        case .connectionFailed:
            connectionStatus = .error
            logger.warning("Simulated error: connection failed")
            
            // Auto-recover after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self = self else { return }
                if self.simulatedErrorState == .connectionFailed {
                    self.simulatedErrorState = nil
                    self.connectionStatus = .disconnected
                    self.logger.info("Reset after connection failure")
                }
            }
            
        case .sensorExpired:
            simulateSensorExpiration()
            logger.warning("Simulated error: sensor expired")
        }
    }
    
    private func generatePredictionCurve() {
        guard readings.count >= 3 else {
            predictionCurve = []
            return
        }
        
        // Simple linear projection based on recent trend
        let recentReadings = Array(readings.suffix(10))
        guard recentReadings.count >= 3 else { return }
        
        // Calculate average rate of change
        var totalChange = 0.0
        var timeSpan = 0.0
        
        for i in 1..<recentReadings.count {
            let timeDiff = recentReadings[i].timestamp.timeIntervalSince(recentReadings[i-1].timestamp)
            let valueDiff = recentReadings[i].valueMgdl - recentReadings[i-1].valueMgdl
            if timeDiff > 0 {
                totalChange += valueDiff
                timeSpan += timeDiff
            }
        }
        
        // Calculate rate of change per minute
        let ratePerMinute = timeSpan > 0 ? (totalChange / timeSpan) * 60 : 0
        
        // Create prediction points
        var predictions: [GlucoseDataPoint] = []
        if let lastValue = lastReading?.valueMgdl {
            let now = Date()
            
            for minute in 1...30 {
                let predictedTime = now.addingTimeInterval(Double(minute) * 60)
                let predictedValue = lastValue + (ratePerMinute * Double(minute))
                let point = GlucoseDataPoint(timestamp: predictedTime, value: predictedValue)
                predictions.append(point)
            }
        }
        
        predictionCurve = predictions
    }
    
    @MainActor
    private func saveReading(_ reading: GlucoseReading) async {
        let context = DataManager.shared.container.mainContext
        context.insert(reading)
        
        do {
            try context.save()
        } catch {
            logger.error("Failed to save reading: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func saveNewSensor(_ sensor: SensorDevice) async {
        let context = DataManager.shared.container.mainContext
        
        // First set all other sensors to not current
        var descriptor = FetchDescriptor<SensorDevice>()
        descriptor.predicate = #Predicate<SensorDevice> { device in
            device.isCurrent == true
        }
        
        do {
            let currentSensors = try context.fetch(descriptor)
            for existingSensor in currentSensors {
                existingSensor.isCurrent = false
            }
            
            // Now add the new sensor
            context.insert(sensor)
            try context.save()
        } catch {
            logger.error("Failed to save sensor: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func updateSensor(_ sensor: SensorDevice) async {
        let context = DataManager.shared.container.mainContext
        
        let sensorId = sensor.id
        var descriptor = FetchDescriptor<SensorDevice>()
        descriptor.predicate = #Predicate { device in
            device.id == sensorId
        }
        
        do {
            let results = try context.fetch(descriptor)
            if let existingSensor = results.first {
                existingSensor.batteryLevel = sensor.batteryLevel
                existingSensor.lastConnectionDate = sensor.lastConnectionDate
                existingSensor.status = sensor.status
                existingSensor.isCurrent = sensor.isCurrent
                existingSensor.expirationDate = sensor.expirationDate
                try context.save()
            }
        } catch {
            logger.error("Failed to update sensor: \(error.localizedDescription)")
        }
    }
    
    var currentSensor: SensorDevice? {
        get {
            return _currentSensor
        }
        set {
            _currentSensor = newValue
            currentSensorId = newValue?.id
        }
    }
}

// MARK: - Supporting Types

struct GlucoseDataPoint: Identifiable {
    var id = UUID()
    var timestamp: Date
    var value: Double
}

enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case pairing
    case intermittent
    case error
}

enum ErrorState: String, CaseIterable {
    case signalLoss = "Signal Loss"
    case dataCorruption = "Data Corruption"
    case pairingFailed = "Pairing Failed"
    case connectionFailed = "Connection Failed"
    case sensorExpired = "Sensor Expired"
} 
