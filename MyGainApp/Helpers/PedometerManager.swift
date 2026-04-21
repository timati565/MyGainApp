import CoreMotion
import SwiftUI

class PedometerManager: ObservableObject {
    static let shared = PedometerManager()
    private let pedometer = CMPedometer()
    
    @Published var stepsToday: Int = 0
    @Published var distanceToday: Double = 0
    @Published var isPedometerAvailable: Bool = false
    
    private init() {
        isPedometerAvailable = CMPedometer.isStepCountingAvailable()
        if isPedometerAvailable {
            startUpdates()
        }
    }
    
    func startUpdates() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
            guard let data = data, error == nil else { return }
            DispatchQueue.main.async {
                self?.stepsToday = data.numberOfSteps.intValue
                if let distance = data.distance?.doubleValue {
                    self?.distanceToday = distance
                }
            }
        }
    }
    
    func refresh() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        
        pedometer.queryPedometerData(from: startOfDay, to: now) { [weak self] data, error in
            guard let data = data, error == nil else { return }
            DispatchQueue.main.async {
                self?.stepsToday = data.numberOfSteps.intValue
                if let distance = data.distance?.doubleValue {
                    self?.distanceToday = distance
                }
            }
        }
    }
}
