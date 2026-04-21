import HealthKit
import SwiftUI

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    
    let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
    ]
    
    let writeTypes: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKObjectType.quantityType(forIdentifier: .dietaryProtein)!
    ]
    
    private init() {}
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                completion(success)
            }
        }
    }
    
    func fetchLatestWeight(completion: @escaping (Double?) -> Void) {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            completion(nil)
            return
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let weight = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            DispatchQueue.main.async { completion(weight) }
        }
        healthStore.execute(query)
    }
    
    func saveWeight(_ weightKg: Double, date: Date = Date(), completion: @escaping (Bool) -> Void) {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            completion(false)
            return
        }
        let quantity = HKQuantity(unit: HKUnit.gramUnit(with: .kilo), doubleValue: weightKg)
        let sample = HKQuantitySample(type: weightType, quantity: quantity, start: date, end: date)
        healthStore.save(sample) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }
    
    func saveFood(calories: Double, protein: Double, date: Date = Date(), completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var successCalories = false
        var successProtein = false
        
        if let energyType = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            let energyQuantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: calories)
            let energySample = HKQuantitySample(type: energyType, quantity: energyQuantity, start: date, end: date)
            group.enter()
            healthStore.save(energySample) { success, _ in
                successCalories = success
                group.leave()
            }
        }
        
        if let proteinType = HKObjectType.quantityType(forIdentifier: .dietaryProtein) {
            let proteinQuantity = HKQuantity(unit: HKUnit.gram(), doubleValue: protein)
            let proteinSample = HKQuantitySample(type: proteinType, quantity: proteinQuantity, start: date, end: date)
            group.enter()
            healthStore.save(proteinSample) { success, _ in
                successProtein = success
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(successCalories || successProtein)
        }
    }
    
    func saveWorkout(activityType: HKWorkoutActivityType = .traditionalStrengthTraining,
                     start: Date, end: Date, calories: Double? = nil,
                     completion: @escaping (Bool) -> Void) {
        let workout: HKWorkout
        let duration = end.timeIntervalSince(start)
        let energyBurned = calories.map { HKQuantity(unit: .kilocalorie(), doubleValue: $0) }
        
        if #available(iOS 17.0, *) {
            workout = HKWorkout(activityType: activityType,
                                start: start,
                                end: end,
                                duration: duration,
                                totalEnergyBurned: energyBurned,
                                totalDistance: nil,
                                metadata: nil)
        } else {
            workout = HKWorkout(activityType: activityType,
                                start: start,
                                end: end,
                                duration: duration,
                                totalEnergyBurned: energyBurned,
                                totalDistance: nil,
                                device: nil,
                                metadata: nil)
        }
        healthStore.save(workout) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }
}
