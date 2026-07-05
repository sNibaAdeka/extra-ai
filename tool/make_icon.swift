// Generates the Extra AI macOS app icon: Apple-style rounded rect with
// TRANSPARENT margins (no white edges), brand violet→ember gradient field,
// and the [|] bracket-cursor logo mark. Run:
//   swift tool/make_icon.swift <output.png>
import AppKit
import CoreGraphics

let sizePx = 1024
let out = CommandLine.arguments.count > 1
  ? CommandLine.arguments[1]
  : "app_icon_1024.png"

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
  CGColor(
    red: CGFloat((hex >> 16) & 0xFF) / 255,
    green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255,
    alpha: alpha
  )
}

// Brand tokens (mirror lib/theme/app_theme.dart).
let bgVoid = rgb(0x221327)
let bgViolet = rgb(0x321D4D)
let bgMid = rgb(0x45243C)
let ember = rgb(0xF46F3D)
let emberDeep = rgb(0xC85632)
let violet = rgb(0xA855F7)

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
  data: nil, width: sizePx, height: sizePx,
  bitsPerComponent: 8, bytesPerRow: 0, space: space,
  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!
let S = CGFloat(sizePx)

// Apple icon grid: 824x824 rounded rect centered in 1024, radius ~185.
let inset: CGFloat = 100
let rect = CGRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
let corner: CGFloat = 185
let shape = CGPath(
  roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil
)

// Subtle baked drop shadow like system icons.
ctx.saveGState()
ctx.setShadow(
  offset: CGSize(width: 0, height: -12), blur: 24,
  color: CGColor(gray: 0, alpha: 0.35)
)
ctx.addPath(shape)
ctx.setFillColor(bgVoid)
ctx.fillPath()
ctx.restoreGState()

// Clip to the rounded rect for everything else.
ctx.saveGState()
ctx.addPath(shape)
ctx.clip()

// Diagonal plum → violet → warm gradient (landing hero).
let grad = CGGradient(
  colorsSpace: space,
  colors: [bgVoid, bgViolet, bgMid] as CFArray,
  locations: [0.0, 0.55, 1.0]
)!
ctx.drawLinearGradient(
  grad,
  start: CGPoint(x: rect.minX, y: rect.maxY),
  end: CGPoint(x: rect.maxX, y: rect.minY),
  options: []
)

// Soft ember glow bottom-right + violet glow top-left (iridescent corners).
func glow(_ color: CGColor, at p: CGPoint, r: CGFloat, alphaTop: CGFloat) {
  let g = CGGradient(
    colorsSpace: space,
    colors: [color.copy(alpha: alphaTop)!, color.copy(alpha: 0)!] as CFArray,
    locations: [0, 1]
  )!
  ctx.drawRadialGradient(
    g, startCenter: p, startRadius: 0, endCenter: p, endRadius: r, options: []
  )
}
glow(ember, at: CGPoint(x: rect.maxX - 120, y: rect.minY + 80), r: 620, alphaTop: 0.34)
glow(violet, at: CGPoint(x: rect.minX + 100, y: rect.maxY - 60), r: 560, alphaTop: 0.30)

// ---- The [|] mark, geometry copied from lib/widgets/logo_mark.dart ----
// Content box ~56% of the icon, centered. CG y-axis is bottom-up; the mark
// is vertically symmetric so no flip is needed.
let m = S * 0.56
let ox = (S - m) / 2
let oy = (S - m) / 2
let stroke = m * 0.11
let bracketH = m * 0.62
let top = oy + (m - bracketH) / 2
let bottom = top + bracketH
let armLen = m * 0.16
let r = stroke * 0.9

func bracket(xAt: CGFloat, mirrored: Bool) -> CGPath {
  let p = CGMutablePath()
  let dir: CGFloat = mirrored ? -1 : 1
  p.move(to: CGPoint(x: xAt + dir * armLen, y: top))
  p.addLine(to: CGPoint(x: xAt + dir * r, y: top))
  p.addQuadCurve(
    to: CGPoint(x: xAt, y: top + r), control: CGPoint(x: xAt, y: top)
  )
  p.addLine(to: CGPoint(x: xAt, y: bottom - r))
  p.addQuadCurve(
    to: CGPoint(x: xAt + dir * r, y: bottom), control: CGPoint(x: xAt, y: bottom)
  )
  p.addLine(to: CGPoint(x: xAt + dir * armLen, y: bottom))
  return p
}

let emberGrad = CGGradient(
  colorsSpace: space, colors: [ember, emberDeep] as CFArray, locations: [0, 1]
)!
for path in [bracket(xAt: ox + m * 0.20, mirrored: false),
             bracket(xAt: ox + m * 0.80, mirrored: true)] {
  let stroked = path.copy(
    strokingWithWidth: stroke, lineCap: .round, lineJoin: .round, miterLimit: 10
  )
  ctx.saveGState()
  ctx.addPath(stroked)
  ctx.clip()
  ctx.drawLinearGradient(
    emberGrad,
    start: CGPoint(x: ox, y: oy + m),
    end: CGPoint(x: ox + m, y: oy),
    options: []
  )
  ctx.restoreGState()
}

// Center cursor | — glowing white line.
let cx = ox + m * 0.5
let cTop = oy + m * 0.30
let cBottom = oy + m * 0.70
ctx.saveGState()
ctx.setShadow(
  offset: .zero, blur: 34, color: CGColor(gray: 1, alpha: 0.85)
)
ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
ctx.setLineWidth(stroke * 0.75)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: cx, y: cTop))
ctx.addLine(to: CGPoint(x: cx, y: cBottom))
ctx.strokePath()
ctx.restoreGState()

ctx.restoreGState() // rounded-rect clip

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(sizePx)x\(sizePx), transparent margins)")
