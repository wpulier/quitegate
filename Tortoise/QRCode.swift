import CoreImage
import CoreImage.CIFilterBuiltins

/// Renders a string (a URL) to a QR `CGImage`. CoreImage is available on both
/// macOS and iOS, so this is shared. Views wrap the result in
/// `Image(decorative: cgImage, scale: 1)` on each platform.
enum QRCode {
  private static let context = CIContext(options: nil)

  static func cgImage(for string: String, scale: CGFloat = 12) -> CGImage? {
    guard !string.isEmpty, let data = string.data(using: .utf8) else { return nil }
    let filter = CIFilter.qrCodeGenerator()
    filter.message = data
    filter.correctionLevel = "M"
    guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else {
      return nil
    }
    return context.createCGImage(output, from: output.extent)
  }
}
