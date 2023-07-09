//  MIT License
//
//  Copyright © 2021 Paul Hudson
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
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// An enum describing the ways CodeScannerView can hit scanning problems.
public enum ScanError: Error {
    /// The camera could not be accessed.
    case badInput

    /// The camera was not capable of scanning the requested codes.
    case badOutput

    /// Initialization failed.
    case initError(_ error: Error)
  
    /// The camera permission is denied
    case permissionDenied
}

/// The result from a successful scan: the string that was scanned, and also the type of data that was found.
/// The type is useful for times when you've asked to scan several different code types at the same time, because
/// it will report the exact code type that was found.
@available(macCatalyst 14.0, macOS 13.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
public struct ScanResult {
    /// The contents of the code.
    public let string: String

    /// The type of code that was matched.
    public let type: AVMetadataObject.ObjectType
    
    #if canImport(UIKit)
    /// The image of the code that was matched
    public let image: UIImage?
    #else
    /// The image of the code that was matched
    public let image: NSImage?
    #endif
  
    /// The corner coordinates of the scanned code.
    public let corners: [CGPoint]
}

/// The operating mode for CodeScannerView.
public enum ScanMode {
    /// Scan exactly one code, then stop.
    case once

    /// Scan each code no more than once.
    case oncePerCode

    /// Keep scanning all codes until dismissed.
    case continuous

    /// Scan only when capture button is tapped.
    case manual
}

/// A SwiftUI view that is able to scan barcodes, QR codes, and more, and send back what was found.
/// To use, set `codeTypes` to be an array of things to scan for, e.g. `[.qr]`, and set `completion` to
/// a closure that will be called when scanning has finished. This will be sent the string that was detected or a `ScanError`.
/// For testing inside the simulator, set the `simulatedData` property to some test data you want to send back.
@available(iOS 13.0, macCatalyst 14.0, macOS 13.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
public struct ScanView {
    
    public let codeTypes: [AVMetadataObject.ObjectType]
    public let scanMode: ScanMode
    public let manualSelect: Bool
    public let scanInterval: Double
    public let showViewfinder: Bool
    public var simulatedData = ""
    public var shouldVibrateOnSuccess: Bool
    public var isTorchOn: Bool
    public var isGalleryPresented: Binding<Bool>
    public var videoCaptureDevice: AVCaptureDevice?
    public var completion: (Result<ScanResult, ScanError>) -> Void
    
    public init(
        codeTypes: AVMetadataObject.ObjectType...,
        scanMode: ScanMode = .once,
        manualSelect: Bool = false,
        scanInterval: Double = 2.0,
        showViewfinder: Bool = false,
        simulatedData: String = "",
        shouldVibrateOnSuccess: Bool = true,
        isTorchOn: Bool = false,
        isGalleryPresented: Binding<Bool> = .constant(false),
        videoCaptureDevice: AVCaptureDevice? = nil,
        completion: @escaping (Result<ScanResult, ScanError>) -> Void
    ) {
        self.codeTypes = codeTypes
        self.scanMode = scanMode
        self.manualSelect = manualSelect
        self.showViewfinder = showViewfinder
        self.scanInterval = scanInterval
        self.simulatedData = simulatedData
        self.shouldVibrateOnSuccess = shouldVibrateOnSuccess
        self.isTorchOn = isTorchOn
        self.isGalleryPresented = isGalleryPresented
        if let videoCaptureDevice {
            self.videoCaptureDevice = videoCaptureDevice
        } else {
            #if os(iOS)
            self.videoCaptureDevice = AVCaptureDevice.bestForVideo
            #elseif os(macOS)
            self.videoCaptureDevice = AVCaptureDevice.bestForVideo
            #else
            self.videoCaptureDevice = nil
            #endif
        }
        self.completion = completion
    }
}

#if os(iOS)
@available(iOS 13.0, macCatalyst 14.0, macOS 13.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
extension ScanView: UIViewControllerRepresentable {

    public func makeUIViewController(context: Context) -> ScannerViewController {
        return ScannerViewController(showViewfinder: showViewfinder, parentView: self)
    }

    public func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        uiViewController.parentView = self
        uiViewController.updateViewController(
            isTorchOn: isTorchOn,
            isGalleryPresented: isGalleryPresented.wrappedValue,
            isManualCapture: scanMode == .manual,
            isManualSelect: manualSelect
        )
    }
    
}
#elseif os(macOS)
@available(iOS 13.0, macCatalyst 14.0, macOS 13.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
extension ScanView: NSViewControllerRepresentable {
    
    public func makeNSViewController(context: Context) -> ScannerViewController {
        return ScannerViewController(showViewfinder: showViewfinder, parentView: self)
    }
    
    public func updateNSViewController(_ nsViewController: ScannerViewController, context: Context) {
        nsViewController.parentView = self
        nsViewController.updateViewController(
            isTorchOn: isTorchOn,
            isGalleryPresented: isGalleryPresented.wrappedValue,
            isManualCapture: scanMode == .manual,
            isManualSelect: manualSelect
        )
    }
    
}
#else
@available(iOS 13.0, macCatalyst 14.0, macOS 13.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
extension ScanView: View {
    
    public var body: some View {
        Text("Unavailable for this version")
    }
}
#endif

@available(iOS 13.0, macCatalyst 14.0, macOS 13.0, *)
@available(watchOS, unavailable)
@available(tvOS, unavailable)
struct ScanView_Previews: PreviewProvider {
    static var previews: some View {
        ScanView(codeTypes: .qr) { result in
            // do nothing
        }
    }
}
