import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Converts photos (e.g. HEIC) to JPEG while keeping EXIF date and GPS metadata,
/// which the Fotospur plugin needs to place photos on the track.
enum PhotoConverter {
    static func jpegData(from data: Data, maxPixelSize: Int = 2560, quality: Double = 0.85) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              var metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else { return nil }

        // The rotation is already applied to the pixels, and the size changed.
        metadata[kCGImagePropertyOrientation] = 1
        if var tiff = metadata[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = 1
            metadata[kCGImagePropertyTIFFDictionary] = tiff
        }
        if var exif = metadata[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            exif[kCGImagePropertyExifPixelXDimension] = image.width
            exif[kCGImagePropertyExifPixelYDimension] = image.height
            metadata[kCGImagePropertyExifDictionary] = exif
        }
        metadata.removeValue(forKey: kCGImagePropertyPixelWidth)
        metadata.removeValue(forKey: kCGImagePropertyPixelHeight)
        metadata[kCGImageDestinationLossyCompressionQuality] = quality

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, metadata as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
