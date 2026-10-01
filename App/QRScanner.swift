import PresenterCore
import SwiftUI
import AVFoundation

struct QRScanner: UIViewControllerRepresentable {
    let onScan: (URL) -> Void
    func makeUIViewController(context: Context) -> ScannerController { ScannerController(onScan: onScan) }
    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}
}
final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let camera = AVCaptureSession()
    private let queue = DispatchQueue(label: "nodus.qr.camera")
    private var layer: AVCaptureVideoPreviewLayer?
    private var scanned = false
    private let onScan: (URL) -> Void
    init(onScan: @escaping (URL) -> Void) { self.onScan = onScan; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .black
        let close = UIButton(type: .system); close.setTitle(L10n.text("Close"), for: .normal); close.tintColor = .white
        close.addTarget(self, action: #selector(closeScanner), for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(close)
        NSLayoutConstraint.activate([close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20), close.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)])
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            if granted { self.queue.async { self.configure() } }
            else { DispatchQueue.main.async { self.showMessage(L10n.text("Allow camera access in Settings to scan Nodus’s QR code.")) } }
        }
    }
    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device), camera.canAddInput(input) else {
            DispatchQueue.main.async { self.showMessage(L10n.text("No camera is available. You can paste the session link on the home screen.")) }; return
        }
        camera.addInput(input)
        let output = AVCaptureMetadataOutput(); guard camera.canAddOutput(output) else { return }
        camera.addOutput(output); output.setMetadataObjectsDelegate(self, queue: .main); output.metadataObjectTypes = [.qr]
        DispatchQueue.main.async {
            let layer = AVCaptureVideoPreviewLayer(session: self.camera); layer.videoGravity = .resizeAspectFill
            layer.frame = self.view.bounds; self.view.layer.insertSublayer(layer, at: 0); self.layer = layer
        }
        camera.startRunning()
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); layer?.frame = view.bounds }
    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); queue.async { self.camera.stopRunning() } }
    @objc private func closeScanner() { dismiss(animated: true) }
    private func showMessage(_ text: String) {
        let label = UILabel(); label.text = text; label.textColor = .white; label.numberOfLines = 0; label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(label)
        NSLayoutConstraint.activate([label.centerYAnchor.constraint(equalTo: view.centerYAnchor), label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32), label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)])
    }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !scanned, let raw = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue,
              let url = URL(string: raw), url.scheme == "nodus-presenter" else { return }
        scanned = true; onScan(url)
    }
}
