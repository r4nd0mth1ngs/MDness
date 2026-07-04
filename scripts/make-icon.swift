// Generates the MDness app icon: red ASCII-art "MD" on a dark terminal-style
// rounded rect. Usage: swift scripts/make-icon.swift <output.png>
// (scripts/make-icon.sh wraps this and produces MDness/AppIcon.icns)
import AppKit

let canvas: CGFloat = 1024

let art = """
#   #  ####
## ##  #   #
# # #  #   #
#   #  #   #
#   #  ####
"""

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvas),
    pixelsHigh: Int(canvas),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: canvas, height: canvas)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Standard macOS icon grid: 824pt shape centered on a 1024pt canvas.
let inset: CGFloat = 100
let shapeRect = NSRect(x: inset, y: inset, width: canvas - 2 * inset, height: canvas - 2 * inset)
NSColor(srgbRed: 0.09, green: 0.09, blue: 0.10, alpha: 1).setFill()
NSBezierPath(roundedRect: shapeRect, xRadius: 185, yRadius: 185).fill()

let paragraph = NSMutableParagraphStyle()
paragraph.lineHeightMultiple = 0.82
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "Menlo-Bold", size: 104)!,
    .foregroundColor: NSColor(srgbRed: 1.0, green: 0.23, blue: 0.19, alpha: 1),
    .paragraphStyle: paragraph,
]
let text = NSAttributedString(string: art, attributes: attributes)
let textSize = text.size()
text.draw(at: NSPoint(x: (canvas - textSize.width) / 2, y: (canvas - textSize.height) / 2))

NSGraphicsContext.restoreGraphicsState()

let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
