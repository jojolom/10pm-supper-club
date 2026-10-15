// Draws the app icon (SupperClub/Assets.xcassets/AppIcon.appiconset/AppIcon.png) in the merch's style:
// cream Baskerville "10 PM" over a rule and spaced "SUPPER CLUB" on black. Opaque (no alpha), as the
// App Store requires.
//   swiftc -o /tmp/make-icon scripts/make-icon.swift && /tmp/make-icon
import AppKit
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(srgbRed: 0.043, green: 0.043, blue: 0.047, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
let cream = NSColor(srgbRed: 0.914, green: 0.882, blue: 0.812, alpha: 1)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
let width = CGFloat(size)
func draw(_ text: String, font: NSFont, kern: CGFloat, centerY: CGFloat) -> NSRect {
    let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: cream, .kern: kern])
    let bounds = string.size()
    let rect = NSRect(x: (width - bounds.width + kern) / 2, y: centerY - bounds.height / 2, width: bounds.width, height: bounds.height)
    string.draw(in: rect)
    return rect
}
let big = NSFont(name: "Baskerville-SemiBold", size: 262) ?? .systemFont(ofSize: 262)
let small = NSFont(name: "Baskerville-SemiBold", size: 80) ?? .systemFont(ofSize: 80)
let title = draw("10 PM", font: big, kern: -5, centerY: 600)
cream.setFill()
NSRect(x: title.minX + 16, y: 466, width: title.width - 32, height: 8).fill()   // the rule under "10 PM"
_ = draw("SUPPER CLUB", font: small, kern: 12, centerY: 392)
NSGraphicsContext.restoreGraphicsState()

let url = URL(fileURLWithPath: "SupperClub/Assets.xcassets/AppIcon.appiconset/AppIcon.png") as CFURL
let destination = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
CGImageDestinationFinalize(destination)
print("wrote AppIcon.png")
