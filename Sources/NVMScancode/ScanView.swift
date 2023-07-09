//  MIT License
//
//  Copyright (c) 2021 Paul Hudson
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
//  WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
//  OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
//  OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@available(iOS 13.0, macCatalyst 14.0, macOS 13.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
extension ScanView {
    
    #if os(iOS)
    public class ScannerViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, AVCaptureMetadataOutputObjectsDelegate, UIAdaptivePresentationControllerDelegate, AVCapturePhotoCaptureDelegate {
        private let photoOutput = AVCapturePhotoOutput()
        private var isCapturing = false
        private var handler: ((UIImage) -> Void)?
        var parentView: ScanView!
        var codesFound = Set<String>()
        var didFinishScanning = false
        var lastTime = Date(timeIntervalSince1970: 0)
        private let showViewfinder: Bool
        
        private var isGalleryShowing: Bool = false {
            didSet {
                // Update binding
                if parentView.isGalleryPresented.wrappedValue != isGalleryShowing {
                    parentView.isGalleryPresented.wrappedValue = isGalleryShowing
                }
            }
        }

        public init(showViewfinder: Bool = false, parentView: ScanView) {
            self.parentView = parentView
            self.showViewfinder = showViewfinder
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            self.showViewfinder = false
            super.init(coder: coder)
        }
        
        func openGallery() {
            isGalleryShowing = true
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.presentationController?.delegate = self
            present(imagePicker, animated: true, completion: nil)
        }
        
        @objc func openGalleryFromButton(_ sender: UIButton) {
            openGallery()
        }

        public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            isGalleryShowing = false
            
            if let qrcodeImg = info[.originalImage] as? UIImage {
                let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!
                let ciImage = CIImage(image:qrcodeImg)!
                var qrCodeLink = ""

                let features = detector.features(in: ciImage)

                for feature in features as! [CIQRCodeFeature] {
                    qrCodeLink = feature.messageString!
                    if qrCodeLink == "" {
                        didFail(reason: .badOutput)
                    } else {
                        let corners = [
                            feature.bottomLeft,
                            feature.bottomRight,
                            feature.topRight,
                            feature.topLeft
                        ]
                        let result = ScanResult(string: qrCodeLink, type: .qr, image: qrcodeImg, corners: corners)
                        found(result)
                    }

                }

            } else {
                print("Something went wrong")
            }

            dismiss(animated: true, completion: nil)
        }
        
        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            isGalleryShowing = false
            dismiss(animated: true, completion: nil)
        }

        public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            // Galery is no longer being presented
            isGalleryShowing = false
        }

        #if targetEnvironment(simulator)
        override public func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = true

            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.numberOfLines = 0
            label.text = "You're running in the simulator, which means the camera isn't available. Tap anywhere to send back some simulated data."
            label.textAlignment = .center

            let button = UIButton()
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setTitle("Select a custom image", for: .normal)
            button.setTitleColor(UIColor.systemBlue, for: .normal)
            button.setTitleColor(UIColor.gray, for: .highlighted)
            button.addTarget(self, action: #selector(openGalleryFromButton), for: .touchUpInside)

            let stackView = UIStackView()
            stackView.translatesAutoresizingMaskIntoConstraints = false
            stackView.axis = .vertical
            stackView.spacing = 50
            stackView.addArrangedSubview(label)
            stackView.addArrangedSubview(button)

            view.addSubview(stackView)

            NSLayoutConstraint.activate([
                button.heightAnchor.constraint(equalToConstant: 50),
                stackView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
                stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        }

        override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            // Send back their simulated data, as if it was one of the types they were scanning for
            found(ScanResult(
                string: parentView.simulatedData,
                type: parentView.codeTypes.first ?? .qr, image: nil, corners: []
            ))
        }
        #endif
        
        public func reset() {
            codesFound.removeAll()
            didFinishScanning = false
            lastTime = Date(timeIntervalSince1970: 0)
        }
        
        public func readyManualCapture() {
            guard parentView.scanMode == .manual else { return }
            self.reset()
            lastTime = Date()
        }

        public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }
                
                guard didFinishScanning == false else { return }
                
                let photoSettings = AVCapturePhotoSettings()
                guard !isCapturing else { return }
                isCapturing = true
                
                handler = { [self] image in
                    let result = ScanResult(string: stringValue, type: readableObject.type, image: image, corners: readableObject.corners)
                    
                    switch parentView.scanMode {
                    case .once:
                        found(result)
                        // make sure we only trigger scan once per use
                        didFinishScanning = true
                        
                    case .manual:
                        if !didFinishScanning, isWithinManualCaptureInterval() {
                            found(result)
                            didFinishScanning = true
                        }
                        
                    case .oncePerCode:
                        if !codesFound.contains(stringValue) {
                            codesFound.insert(stringValue)
                            found(result)
                        }
                        
                    case .continuous:
                        if isPastScanInterval() {
                            found(result)
                        }
                    }
                }
                photoOutput.capturePhoto(with: photoSettings, delegate: self)
            }
        }

        func isPastScanInterval() -> Bool {
            Date().timeIntervalSince(lastTime) >= parentView.scanInterval
        }
        
        func isWithinManualCaptureInterval() -> Bool {
            Date().timeIntervalSince(lastTime) <= 0.5
        }

        func found(_ result: ScanResult) {
            lastTime = Date()

            if parentView.shouldVibrateOnSuccess {
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            }

            parentView.completion(.success(result))
        }

        func didFail(reason: ScanError) {
            parentView.completion(.failure(reason))
        }
        
        func updateViewController(isTorchOn: Bool, isGalleryPresented: Bool, isManualCapture: Bool, isManualSelect: Bool) {
            if let backCamera = AVCaptureDevice.default(for: AVMediaType.video),
               backCamera.hasTorch
            {
                try? backCamera.lockForConfiguration()
                backCamera.torchMode = isTorchOn ? .on : .off
                backCamera.unlockForConfiguration()
            }
            
            if isGalleryPresented && !isGalleryShowing {
                openGallery()
            }
            
            #if !targetEnvironment(simulator)
            showManualCaptureButton(isManualCapture)
            showManualSelectButton(isManualSelect)
            #endif
        }
        
    }
    #elseif os(macOS)
    @available(macOS 13.0, *)
    public class ScannerViewController: NSViewController, AVCaptureMetadataOutputObjectsDelegate, AVCapturePhotoCaptureDelegate {
        private let photoOutput = AVCapturePhotoOutput()
        private var isCapturing = false
        private var handler: ((NSImage) -> Void)?
        var parentView: ScanView!
        var codesFound = Set<String>()
        var didFinishScanning = false
        var lastTime = Date(timeIntervalSince1970: 0)
        private let showViewfinder: Bool
        
        private var isGalleryShowing: Bool = false {
            didSet {
                // Update binding
                if parentView.isGalleryPresented.wrappedValue != isGalleryShowing {
                    parentView.isGalleryPresented.wrappedValue = isGalleryShowing
                }
            }
        }

        public init(showViewfinder: Bool = false, parentView: ScanView) {
            self.parentView = parentView
            self.showViewfinder = showViewfinder
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            self.showViewfinder = false
            super.init(coder: coder)
        }
        
        var captureSession: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer!
        let fallbackVideoCaptureDevice = AVCaptureDevice.default(for: .video)

        private lazy var viewFinder: NSImageView? = {
            guard let image = NSImage(named: "viewfinder") else {
                return nil
            }

            let imageView = NSImageView(image: image)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            return imageView
        }()
        
        private lazy var manualCaptureButton: NSButton = {
            let button = NSButton()
            let image = NSImage(named: "capture")
            button.image = image!
            button.bezelStyle = .shadowlessSquare
            button.isBordered = false
            button.imagePosition = .imageOnly
            button.action = #selector(manualCapturePressed)
            button.translatesAutoresizingMaskIntoConstraints = false
            return button
        }()

        override public func viewDidLoad() {
            super.viewDidLoad()
            self.setBackgroundColor()
            self.handleCameraPermission()
        }

        override public func viewDidAppear() {
            super.viewDidAppear()
        }

        override public func viewWillAppear() {
            super.viewWillAppear()

            setupSession()
        }
      
        private func setupSession() {
            guard let captureSession = captureSession else {
                return
            }
            
            if previewLayer == nil {
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            }

            if let bounds = view.layer?.bounds {
                previewLayer.frame = bounds
            }
            previewLayer.videoGravity = .resizeAspectFill
            view.layer?.addSublayer(previewLayer)
            addviewfinder()

            reset()

            if (captureSession.isRunning == false) {
                DispatchQueue.global(qos: .userInteractive).async {
                    self.captureSession?.startRunning()
                }
            }
        }

        private func handleCameraPermission() {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
                case .restricted:
                    break
                case .denied:
                    self.didFail(reason: .permissionDenied)
                case .notDetermined:
                    self.requestCameraAccess {
                        self.setupCaptureDevice()
                        DispatchQueue.main.async {
                            self.setupSession()
                        }
                    }
                case .authorized:
                    self.setupCaptureDevice()
                    self.setupSession()
                    
                default:
                    break
            }
        }

        private func requestCameraAccess(completion: (() -> Void)?) {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] status in
                guard status else {
                    self?.didFail(reason: .permissionDenied)
                    return
                }
                completion?()
            }
        }
      
        private func setBackgroundColor(_ color: NSColor = .black) {
            view.wantsLayer = true
            view.layer?.backgroundColor = color.cgColor
        }
      
        private func setupCaptureDevice() {
            captureSession = AVCaptureSession()

            guard let videoCaptureDevice = parentView.videoCaptureDevice ?? fallbackVideoCaptureDevice else {
                return
            }

            let videoInput: AVCaptureDeviceInput

            do {
                videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            } catch {
                didFail(reason: .initError(error))
                return
            }

            if (captureSession!.canAddInput(videoInput)) {
                captureSession!.addInput(videoInput)
            } else {
                didFail(reason: .badInput)
                return
            }
            let metadataOutput = AVCaptureMetadataOutput()

            if (captureSession!.canAddOutput(metadataOutput)) {
                captureSession!.addOutput(metadataOutput)
                captureSession?.addOutput(photoOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = parentView.codeTypes
            } else {
                didFail(reason: .badOutput)
                return
            }
        }

        private func addviewfinder() {
            guard showViewfinder, let imageView = viewFinder else { return }

            view.addSubview(imageView)

            NSLayoutConstraint.activate([
                imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 200),
                imageView.heightAnchor.constraint(equalToConstant: 200),
            ])
        }

        override public func viewDidDisappear() {
            super.viewDidDisappear()

            if (captureSession?.isRunning == true) {
                DispatchQueue.global(qos: .userInteractive).async {
                    self.captureSession?.stopRunning()
                }
            }

            NotificationCenter.default.removeObserver(self)
        }

        /** Click for autofocus */
        public override func mouseDown(with theEvent: NSEvent) {
            guard let mouseLocationInWindow = theEvent.window?.mouseLocationOutsideOfEventStream,
                  let device = parentView.videoCaptureDevice ?? fallbackVideoCaptureDevice,
                  device.isFocusPointOfInterestSupported
            else { return }
            let mouseLocationInView = view.convert(mouseLocationInWindow, from: view);
            
            let videoView = view
            let screenSize = videoView.bounds.size
            let xPoint = mouseLocationInView.y / screenSize.height
            let yPoint = mouseLocationInView.x / screenSize.width
            let focusPoint = CGPoint(x: xPoint, y: yPoint)
            
            do {
                try device.lockForConfiguration()
            } catch {
                return
            }
            
            // Focus to the correct point, make continiuous focus and exposure so the point stays sharp when moving the device closer
            device.focusPointOfInterest = focusPoint
            device.focusMode = .continuousAutoFocus
            device.exposurePointOfInterest = focusPoint
            device.exposureMode = AVCaptureDevice.ExposureMode.continuousAutoExposure
            device.unlockForConfiguration()
        }
        
        @objc func manualCapturePressed(_ sender: Any?) {
            self.readyManualCapture()
        }
        
        func showManualCaptureButton(_ isManualCapture: Bool) {
            if manualCaptureButton.superview == nil {
                view.addSubview(manualCaptureButton)
                NSLayoutConstraint.activate([
                    manualCaptureButton.heightAnchor.constraint(equalToConstant: 60),
                    manualCaptureButton.widthAnchor.constraint(equalTo: manualCaptureButton.heightAnchor),
                    view.centerXAnchor.constraint(equalTo: manualCaptureButton.centerXAnchor),
                    view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: manualCaptureButton.bottomAnchor, constant: 32)
                ])
            }
            
            view.bringSubviewToFront(manualCaptureButton)
            manualCaptureButton.isHidden = !isManualCapture
        }
        
        public func reset() {
            codesFound.removeAll()
            didFinishScanning = false
            lastTime = Date(timeIntervalSince1970: 0)
        }
        
        public func readyManualCapture() {
            guard parentView.scanMode == .manual else { return }
            self.reset()
            lastTime = Date()
        }

        public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }
                
                guard didFinishScanning == false else { return }
                
                let photoSettings = AVCapturePhotoSettings()
                guard !isCapturing else { return }
                isCapturing = true
                
                handler = { [self] image in
                    let result = ScanResult(string: stringValue, type: readableObject.type, image: image, corners: readableObject.corners)
                    
                    switch parentView.scanMode {
                    case .once:
                        found(result)
                        // make sure we only trigger scan once per use
                        didFinishScanning = true
                        
                    case .manual:
                        if !didFinishScanning, isWithinManualCaptureInterval() {
                            found(result)
                            didFinishScanning = true
                        }
                        
                    case .oncePerCode:
                        if !codesFound.contains(stringValue) {
                            codesFound.insert(stringValue)
                            found(result)
                        }
                        
                    case .continuous:
                        if isPastScanInterval() {
                            found(result)
                        }
                    }
                }
                photoOutput.capturePhoto(with: photoSettings, delegate: self)
            }
        }

        func isPastScanInterval() -> Bool {
            Date().timeIntervalSince(lastTime) >= parentView.scanInterval
        }
        
        func isWithinManualCaptureInterval() -> Bool {
            Date().timeIntervalSince(lastTime) <= 0.5
        }

        func found(_ result: ScanResult) {
            lastTime = Date()

            if parentView.shouldVibrateOnSuccess {
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            }

            parentView.completion(.success(result))
        }

        func didFail(reason: ScanError) {
            parentView.completion(.failure(reason))
        }
        
        func updateViewController(isTorchOn: Bool, isGalleryPresented: Bool, isManualCapture: Bool, isManualSelect: Bool) {
            if let backCamera = AVCaptureDevice.default(for: AVMediaType.video),
               backCamera.hasTorch
            {
                try? backCamera.lockForConfiguration()
                backCamera.torchMode = isTorchOn ? .on : .off
                backCamera.unlockForConfiguration()
            }
            
            #if !targetEnvironment(simulator)
            showManualCaptureButton(isManualCapture)
            #endif
        }
        
    }
    #endif
}

#if canImport(AVCaptureDevice)
@available(iOS 13.0, macCatalyst 14.0, macOS 13.0, *)
extension ScanView.ScannerViewController: AVCapturePhotoCaptureDelegate {
    
    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        isCapturing = false
        guard let imageData = photo.fileDataRepresentation() else {
            print("Error while generating image from photo capture data.");
            return
        }
        #if canImport(UIKit)
        guard let qrImage = UIImage(data: imageData) else {
            print("Unable to generate UIImage from image data.");
            return
        }
        #else
        guard let qrImage = NSImage(data: imageData) else {
            print("Unable to generate NSImage from image data.");
            return
        }
        #endif
        handler?(qrImage)
    }
    
    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings
    ) {
        AudioServicesDisposeSystemSoundID(1108)
    }
    
    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings
    ) {
        AudioServicesDisposeSystemSoundID(1108)
    }
    
}
#endif

    
#if os(iOS)
public extension AVCaptureDevice {
    
    /// This returns the Ultra Wide Camera on capable devices and the default Camera for Video otherwise.
    static var bestForVideo: AVCaptureDevice? {
        let deviceHasUltraWideCamera = !AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInUltraWideCamera],
                                                                         mediaType: .video,
                                                                         position: .back).devices.isEmpty
        return deviceHasUltraWideCamera ? AVCaptureDevice.default(.builtInUltraWideCamera,
                                                                  for: .video,
                                                                  position: .back) : AVCaptureDevice.default(for: .video)
    }
}
#elseif os(macOS)
public extension AVCaptureDevice {
    
    /// This returns the Ultra Wide Camera on capable devices and the default Camera for Video otherwise.
    static var bestForVideo: AVCaptureDevice? {
        let deviceHasUltraWideCamera = !AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                                         mediaType: .video,
                                                                         position: .back).devices.isEmpty
        return deviceHasUltraWideCamera ? AVCaptureDevice.default(.builtInWideAngleCamera,
                                                                  for: .video,
                                                                  position: .back) : AVCaptureDevice.default(for: .video)
    }
}
#endif


#if canImport(AppKit)
extension NSView {

    func bringSubviewToFront(_ view: NSView) {
            var theView = view
            self.sortSubviews({(viewA,viewB,rawPointer) in
                let view = rawPointer?.load(as: NSView.self)

                switch view {
                case viewA:
                    return ComparisonResult.orderedDescending
                case viewB:
                    return ComparisonResult.orderedAscending
                default:
                    return ComparisonResult.orderedSame
                }
            }, context: &theView)
    }

}
#endif

