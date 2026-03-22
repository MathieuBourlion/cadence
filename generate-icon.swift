#!/usr/bin/env swift
// Run: swift generate-icon.swift
// Outputs: AppIcon-1024.png in the current directory
import AppKit

func hex(_ s: String) -> CGColor {
    let h = s.hasPrefix("#") ? String(s.dropFirst()) : s
    var int: UInt64 = 0
    Scanner(string: h).scanHexInt64(&int)
    let r = CGFloat((int >> 16) & 0xFF) / 255
    let g = CGFloat((int >> 8) & 0xFF) / 255
    let b = CGFloat(int & 0xFF) / 255
    return CGColor(red: r, green: g, blue: b, alpha: 1)
}

func grad(_ c1: CGColor, _ c2: CGColor) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
               colors: [c1, c2] as CFArray, locations: [0, 1])!
}

let size: CGFloat = 1024
let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
                   bitsPerComponent: 8, bytesPerRow: 0,
                   space: CGColorSpaceCreateDeviceRGB(),
                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

let cr  = size * 0.215
let ins = size * 0.18
let uw  = size - 2 * ins
let uh  = size - 2 * ins
let bw  = uw * 0.13
let gap = (uw - bw * 6) / 5
let baseY = ins + uh
let cgap  = 6 * (size / 200)
let isw   = 0.5 * (size / 200)
let hf: [CGFloat] = [0.25, 0.38, 0.50, 0.35, 0.21, 0.29]
let ai = 2

// Background
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
                   cornerWidth: cr, cornerHeight: cr, transform: nil))
ctx.clip()
ctx.drawLinearGradient(grad(hex("#1E1D1C"), hex("#141312")),
                       start: .zero, end: CGPoint(x: 0, y: size), options: [])
ctx.restoreGState()

// Bars
for i in 0..<6 {
    let bh = hf[i] * uh
    let x  = ins + CGFloat(i) * (bw + gap)
    let y  = baseY - bh
    let br = 2 * (size / 200)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: bw, height: bh),
                       cornerWidth: br, cornerHeight: br, transform: nil))
    ctx.clip()
    let tc = i == ai ? hex("#F2F0EC") : hex("#3C3A37")
    let bc = i == ai ? hex("#C8C4BE") : hex("#2C2B28")
    ctx.drawLinearGradient(grad(tc, bc),
                           start: CGPoint(x: x, y: y),
                           end: CGPoint(x: x, y: y + bh), options: [])
    ctx.restoreGState()
}

// Circle above active bar
let abh  = hf[ai] * uh
let abx  = ins + CGFloat(ai) * (bw + gap)
let abty = baseY - abh
let cd   = bw * 0.55
let cr2  = cd / 2
let ccx  = abx + bw / 2
let ccy  = abty - cgap - cr2
ctx.setFillColor(hex("#F2F0EC"))
ctx.fillEllipse(in: CGRect(x: ccx - cr2, y: ccy - cr2, width: cd, height: cd))

// Baseline
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
ctx.setLineWidth(1)
ctx.move(to: CGPoint(x: ins, y: baseY))
ctx.addLine(to: CGPoint(x: ins + uw, y: baseY))
ctx.strokePath()

// Inner stroke
let ii = isw / 2
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.07))
ctx.setLineWidth(isw)
ctx.addPath(CGPath(roundedRect: CGRect(x: ii, y: ii, width: size - isw, height: size - isw),
                   cornerWidth: cr - ii, cornerHeight: cr - ii, transform: nil))
ctx.strokePath()

// Write PNG
let cgImage = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: cgImage)
let png = rep.representation(using: .png, properties: [:])!
let dest = "Cadence/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
try! png.write(to: URL(fileURLWithPath: dest))
print("Wrote \(dest)")
