import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    @Binding var isPresented: Bool
    var onBarcodeScan: (String) -> Void
    var onClose: () -> Void
    
    @StateObject private var viewModel = BarcodeScannerViewModel()
    
    var body: some View {
        ZStack {
            // Camera preview
            BarcodePreviewView(session: viewModel.session)
                .edgesIgnoringSafeArea(.all)
            
            // Overlay
            VStack {
                // Header with close button
                HStack {
                    Button(action: {
                        onClose()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 40, height: 40)
                            Image(systemName: "xmark")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.toggleTorch()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 40, height: 40)
                            Image(systemName: viewModel.isTorchOn ? "bolt.fill" : "bolt.slash")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                Spacer()
                
                // Barcode scanner guide
                VStack(spacing: 16) {
                    // Scanner rectangle with corners
                    ZStack {
                        Rectangle()
                            .strokeBorder(Color.white, lineWidth: 3)
                            .frame(width: 280, height: 180)
                            .background(Color.clear)
                        
                        // Scan line animation
                        if viewModel.isScanning && !viewModel.isPaused {
                            Rectangle()
                                .fill(Color.red.opacity(0.5))
                                .frame(width: 280, height: 2)
                                .offset(y: viewModel.scanLinePosition)
                                .animation(
                                    Animation.easeInOut(duration: 2)
                                        .repeatForever(autoreverses: true),
                                    value: viewModel.scanLinePosition
                                )
                        }
                    }
                    
                    // Instruction text
                    Text("Align barcode within frame")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(10)
                }
                
                Spacer()
                
                // Status text
                if viewModel.lastScannedCode != "" {
                    Text("Scanned: \(viewModel.lastScannedCode)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            viewModel.checkPermissions()
            viewModel.setupSession()
            viewModel.startScanning()
            
            // Start scan line animation
            viewModel.scanLinePosition = -90
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    viewModel.scanLinePosition = 90
                }
            }
        }
        .onDisappear {
            viewModel.stopScanning()
        }
        .onChange(of: viewModel.scannedBarcode) { _, newValue in
            if let code = newValue {
                viewModel.lastScannedCode = code
                viewModel.pauseScanning()
                
                // Give visual feedback before dismissal
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onBarcodeScan(code)
                    isPresented = false
                }
            }
        }
    }
}

class BarcodeScannerViewModel: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var session = AVCaptureSession()
    @Published var isScanning = false
    @Published var isPaused = false
    @Published var isTorchOn = false
    @Published var scannedBarcode: String? = nil
    @Published var lastScannedCode = ""
    @Published var scanLinePosition: CGFloat = 0
    
    private var captureDevice: AVCaptureDevice?
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupSession()
                    }
                }
            }
        default:
            break
        }
    }
    
    func setupSession() {
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        self.captureDevice = captureDevice
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            let metadataOutput = AVCaptureMetadataOutput()
            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [
                    .ean8,
                    .ean13,
                    .pdf417,
                    .qr,
                    .code128,
                    .code39,
                    .code93,
                    .upce
                ]
            }
        } catch {
            print("Error setting up capture session: \(error.localizedDescription)")
        }
    }
    
    func startScanning() {
        if !session.isRunning {
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.session.startRunning()
                DispatchQueue.main.async {
                    self?.isScanning = true
                    self?.isPaused = false
                }
            }
        }
    }
    
    func stopScanning() {
        if session.isRunning {
            session.stopRunning()
            isScanning = false
        }
    }
    
    func pauseScanning() {
        isPaused = true
    }
    
    func resumeScanning() {
        isPaused = false
        scannedBarcode = nil
    }
    
    func toggleTorch() {
        guard let device = captureDevice, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.torchMode == .on {
                device.torchMode = .off
                isTorchOn = false
            } else {
                try device.setTorchModeOn(level: 1.0)
                isTorchOn = true
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used: \(error.localizedDescription)")
        }
    }
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if isPaused { return }
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  let stringValue = readableObject.stringValue else { return }
            
            // Haptic feedback
            let feedbackGenerator = UINotificationFeedbackGenerator()
            feedbackGenerator.notificationOccurred(.success)
            
            // Publish scanned result
            DispatchQueue.main.async { [weak self] in
                self?.scannedBarcode = stringValue
            }
        }
    }
}

struct BarcodePreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct BarcodeScannerView_Previews: PreviewProvider {
    static var previews: some View {
        BarcodeScannerView(
            isPresented: .constant(true),
            onBarcodeScan: { _ in },
            onClose: {}
        )
    }
}

