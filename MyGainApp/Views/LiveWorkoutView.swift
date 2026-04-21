import SwiftUI
import CoreMotion
import MapKit
import CoreLocation

struct LiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var workoutManager = LiveWorkoutManager()
    @State private var mapPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Карта с маршрутом
                Map(position: $mapPosition) {
                    UserAnnotation()
                    
                    if !workoutManager.routeCoordinates.isEmpty {
                        MapPolyline(coordinates: workoutManager.routeCoordinates)
                            .stroke(
                                LinearGradient(
                                    colors: [.green, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 6
                            )
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapScaleView()
                }
                .ignoresSafeArea(edges: .bottom)
                
                // Поверх карты — метрики и кнопки
                VStack {
                    // Верхняя панель с таймером
                    HStack {
                        Spacer()
                        TimerBadge(time: workoutManager.elapsedTime)
                        Spacer()
                    }
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Нижняя панель с метриками
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            MetricCard(
                                title: "Дистанция",
                                value: String(format: "%.2f", workoutManager.distance / 1000),
                                unit: "км",
                                icon: "figure.run",
                                color: .green
                            )
                            
                            MetricCard(
                                title: "Калории",
                                value: "\(Int(workoutManager.caloriesBurned))",
                                unit: "ккал",
                                icon: "flame.fill",
                                color: .orange
                            )
                        }
                        
                        HStack(spacing: 16) {
                            MetricCard(
                                title: "Темп",
                                value: workoutManager.paceString,
                                unit: "/км",
                                icon: "speedometer",
                                color: .blue
                            )
                            
                            MetricCard(
                                title: "Шаги",
                                value: "\(workoutManager.steps)",
                                unit: "",
                                icon: "shoeprints.fill",
                                color: .purple
                            )
                        }
                        
                        // Кнопки управления
                        HStack(spacing: 20) {
                            if workoutManager.isRunning {
                                Button {
                                    workoutManager.pause()
                                } label: {
                                    Label("Пауза", systemImage: "pause.circle.fill")
                                        .font(.title2.bold())
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                            } else {
                                Button {
                                    workoutManager.start()
                                } label: {
                                    Label("Старт", systemImage: "play.circle.fill")
                                        .font(.title2.bold())
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                            }
                            
                            Button {
                                workoutManager.stop()
                                dismiss()
                            } label: {
                                Label("Финиш", systemImage: "flag.checkered.circle.fill")
                                    .font(.title2.bold())
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                workoutManager.requestAuthorization()
            }
        }
    }
}

// MARK: - TimerBadge
struct TimerBadge: View {
    let time: TimeInterval
    
    var body: some View {
        Text(formatTime(time))
            .font(.system(size: 56, weight: .bold, design: .monospaced))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 10)
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - MetricCard
struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - LiveWorkoutManager
class LiveWorkoutManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var elapsedTime: TimeInterval = 0
    @Published var distance: Double = 0 // метры
    @Published var caloriesBurned: Double = 0
    @Published var steps: Int = 0
    @Published var paceString: String = "0'00\""
    @Published var isRunning = false
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    
    private let locationManager = CLLocationManager()
    private let pedometer = CMPedometer()
    private var timer: Timer?
    private var startDate: Date?
    private var lastLocation: CLLocation?
    private var accumulatedDistance: Double = 0
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
    }
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func start() {
        isRunning = true
        startDate = Date()
        accumulatedDistance = 0
        routeCoordinates = []
        
        locationManager.startUpdatingLocation()
        
        if CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, error in
                guard let data = data, error == nil else { return }
                DispatchQueue.main.async {
                    self?.steps = data.numberOfSteps.intValue
                    if let distance = data.distance?.doubleValue {
                        self?.accumulatedDistance = distance
                        self?.distance = distance
                    }
                    self?.caloriesBurned = Double(self?.steps ?? 0) * 0.04
                }
            }
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startDate else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
            self.updatePace()
        }
    }
    
    func pause() {
        isRunning = false
        locationManager.stopUpdatingLocation()
        pedometer.stopUpdates()
        timer?.invalidate()
    }
    
    func stop() {
        isRunning = false
        locationManager.stopUpdatingLocation()
        pedometer.stopUpdates()
        timer?.invalidate()
        // Здесь можно добавить сохранение тренировки в SwiftData
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        routeCoordinates.append(location.coordinate)
        
        if let last = lastLocation {
            let delta = location.distance(from: last)
            accumulatedDistance += delta
            distance = accumulatedDistance
        }
        lastLocation = location
    }
    
    private func updatePace() {
        guard distance > 10 else {
            paceString = "0'00\""
            return
        }
        let paceSeconds = elapsedTime / (distance / 1000) // секунд на км
        let minutes = Int(paceSeconds) / 60
        let seconds = Int(paceSeconds) % 60
        paceString = String(format: "%d'%02d\"", minutes, seconds)
    }
}
