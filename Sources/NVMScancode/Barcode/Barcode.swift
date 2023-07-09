//
//  Barcode.swift
//  
//
//  Created by Damian Van de Kauter on 09/07/2023.
//

import SwiftUI
#if canImport(CoreImage)
import CoreImage
#endif

public struct NVMBarcode: View {
    private let string: String
    private let type: BarcodeType
    private let size: CGSize
    
    public init(from string: String, type: BarcodeType, size: CGSize) {
        self.string = string
        self.type = type
        self.size = size
    }
    
    public var body: some View {
        #if canImport(CoreImage)
        self.generate(from: string, type: type, size: size)
        #else
        Text(string)
        #endif
    }
    
    #if canImport(CoreImage)
    private func generate(from string: String, type: BarcodeType, size: CGSize) -> Image? {
        guard let scaledImage = self.ciImage(from: string, type: type, size: size) else { return nil }
        
        #if os(macOS)
        let rep = NSCIImageRep(ciImage: scaledImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return Image(nsImage: nsImage)
        #else
        return Image(uiImage: UIImage(ciImage: scaledImage))
        #endif
    }
    
    private func ciImage(from string: String, type: BarcodeType, size: CGSize) -> CIImage? {
        var adjustedSize = size
        if type == .qr {
            adjustedSize.width = size.height
        }
        let filterName = type.rawValue

        guard let data = string.data(using: .ascii),
            let filter = CIFilter(name: filterName) else {
                return nil
        }

        filter.setValue(data, forKey: "inputMessage")

        guard let image = filter.outputImage else {
            return nil
        }

        let imageSize = image.extent.size
        let transform = CGAffineTransform(scaleX: adjustedSize.width / imageSize.width, y: adjustedSize.height / imageSize.height)
        let scaledImage = image.transformed(by: transform)

        return scaledImage
    }
    #endif
    
    public enum BarcodeType: String {
        case code128 = "CICode128BarcodeGenerator"
        case pdf417 = "CIPDF417BarcodeGenerator"
        case aztec = "CIAztecCodeGenerator"
        case qr = "CIQRCodeGenerator"
    }
}
