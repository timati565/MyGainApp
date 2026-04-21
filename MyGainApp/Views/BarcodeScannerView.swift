import SwiftUI
import AVFoundation

struct ScannedFood {
    let name: String
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let servingSize: Double?
}

struct BarcodeScannerView: UIViewControllerRepresentable {
    let completion: (ScannedFood?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.completion = { food in
            completion(food)
            dismiss()
        }
        vc.dismissAction = { dismiss() }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var completion: ((ScannedFood?) -> Void)?
    var dismissAction: (() -> Void)?
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            failed()
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            failed()
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean8, .ean13, .pdf417, .qr, .upce]
        } else {
            failed()
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Кнопка закрытия
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Закрыть", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        closeButton.layer.cornerRadius = 8
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 80),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession.stopRunning()
        }
    }
    
    private func failed() {
        let ac = UIAlertController(title: "Сканирование не поддерживается", message: "Ваше устройство не поддерживает сканирование штрих-кодов.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.dismissAction?()
        })
        present(ac, animated: true)
        captureSession = nil
    }
    
    @objc private func closeTapped() {
        dismissAction?()
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            fetchProductInfo(barcode: stringValue)
        }
    }
    
    private func fetchProductInfo(barcode: String) {
        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
        guard let url = URL(string: urlString) else {
            completion?(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let product = json["product"] as? [String: Any] else {
                DispatchQueue.main.async {
                    self?.completion?(nil)
                }
                return
            }
            
            let name = product["product_name"] as? String ?? "Неизвестный продукт"
            let nutriments = product["nutriments"] as? [String: Any]
            
            let calories = (nutriments?["energy-kcal_100g"] as? Double) ?? 0
            let protein = (nutriments?["proteins_100g"] as? Double) ?? 0
            let fat = (nutriments?["fat_100g"] as? Double) ?? 0
            let carbs = (nutriments?["carbohydrates_100g"] as? Double) ?? 0
            
            let servingSize: Double? = {
                if let quantity = product["product_quantity"] as? Double {
                    return quantity
                }
                return nil
            }()
            
            let scannedFood = ScannedFood(
                name: name,
                calories: calories,
                protein: protein,
                fat: fat,
                carbs: carbs,
                servingSize: servingSize
            )
            
            DispatchQueue.main.async {
                self?.completion?(scannedFood)
            }
        }.resume()
    }
    
    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}
