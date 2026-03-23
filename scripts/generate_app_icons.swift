//
//  generate_app_icons.swift
//  router monitor
//
//  Created by Codex on 22.03.2026.
//

import AppKit
import Foundation

struct IconSpec {
    let relativePath: String
    let pixelSize: Int
}

let fileManager = FileManager.default
let repositoryRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)

let iconSpecs: [IconSpec] = [
    IconSpec(relativePath: "router monitor/Assets.xcassets/AppIcon.appiconset/icon-mac-16.png", pixelSize: 16),
    IconSpec(relativePath: "router monitor/Assets.xcassets/AppIcon.appiconset/icon-mac-16@2x.png", pixelSize: 32),
    IconSpec(relativePath: "router monitor/Assets.xcassets/AppIcon.appiconset/icon-mac-32.png", pixelSize: 32),
    IconSpec(relativePath: "router monitor/Assets.xcassets/AppIcon.appiconset/icon-mac-32@2x.png", pixelSize: 64),
    IconSpec(relativePath: "router monitor/Assets.xcassets/AppIcon.appiconset/icon-mac-128.png", pixelSize: 128),
    IconSpec(relativePath: "router monitor/Assets.xcassets/AppIcon.appiconset/icon-mac-128@2x.png", pixelSize: 256),
    IconSpec(relativePath: "router monitor/Assets.xcassets/AppIcon.appiconset/icon-mac-256.png", pixelSize: 256),
    IconSpec(relativePath: "router monitor/Assets.xcassets/AppIcon.appiconset/icon-mac-256@2x.png", pixelSize: 512),
    IconSpec(relativePath: "router monitor/Assets.xcassets/AppIcon.appiconset/icon-mac-512.png", pixelSize: 512),
    IconSpec(relativePath: "router monitor/Assets.xcassets/AppIcon.appiconset/icon-mac-512@2x.png", pixelSize: 1024),
    IconSpec(relativePath: "router monitor iPhone/Assets.xcassets/AppIcon.appiconset/icon-20@2x.png", pixelSize: 40),
    IconSpec(relativePath: "router monitor iPhone/Assets.xcassets/AppIcon.appiconset/icon-20@3x.png", pixelSize: 60),
    IconSpec(relativePath: "router monitor iPhone/Assets.xcassets/AppIcon.appiconset/icon-29@2x.png", pixelSize: 58),
    IconSpec(relativePath: "router monitor iPhone/Assets.xcassets/AppIcon.appiconset/icon-29@3x.png", pixelSize: 87),
    IconSpec(relativePath: "router monitor iPhone/Assets.xcassets/AppIcon.appiconset/icon-40@2x.png", pixelSize: 80),
    IconSpec(relativePath: "router monitor iPhone/Assets.xcassets/AppIcon.appiconset/icon-40@3x.png", pixelSize: 120),
    IconSpec(relativePath: "router monitor iPhone/Assets.xcassets/AppIcon.appiconset/icon-60@2x.png", pixelSize: 120),
    IconSpec(relativePath: "router monitor iPhone/Assets.xcassets/AppIcon.appiconset/icon-60@3x.png", pixelSize: 180),
    IconSpec(relativePath: "router monitor iPhone/Assets.xcassets/AppIcon.appiconset/icon-marketing-1024.png", pixelSize: 1024),
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1.0) -> NSColor {
    NSColor(calibratedRed: red / 255.0, green: green / 255.0, blue: blue / 255.0, alpha: alpha)
}

func drawIcon(in rect: NSRect) {
    let inset = rect.width * 0.045
    let canvas = rect.insetBy(dx: inset, dy: inset)
    let cornerRadius = canvas.width * 0.23
    let backgroundPath = NSBezierPath(roundedRect: canvas, xRadius: cornerRadius, yRadius: cornerRadius)

    let backgroundGradient = NSGradient(colors: [
        color(10, 20, 48),
        color(20, 66, 120),
        color(27, 123, 162),
    ])!
    backgroundGradient.draw(in: backgroundPath, angle: -58)

    NSGraphicsContext.saveGraphicsState()
    backgroundPath.addClip()

    let topGlowRect = NSRect(
        x: canvas.minX - canvas.width * 0.1,
        y: canvas.midY,
        width: canvas.width * 0.95,
        height: canvas.height * 0.75
    )
    let topGlow = NSGradient(colors: [
        color(78, 227, 227, 0.34),
        color(78, 227, 227, 0.0),
    ])!
    topGlow.draw(in: NSBezierPath(ovalIn: topGlowRect), relativeCenterPosition: .zero)

    let bottomGlowRect = NSRect(
        x: canvas.midX - canvas.width * 0.4,
        y: canvas.minY - canvas.height * 0.08,
        width: canvas.width * 0.8,
        height: canvas.height * 0.58
    )
    let bottomGlow = NSGradient(colors: [
        color(255, 145, 77, 0.26),
        color(255, 145, 77, 0.0),
    ])!
    bottomGlow.draw(in: NSBezierPath(ovalIn: bottomGlowRect), relativeCenterPosition: .zero)

    let radarCenter = NSPoint(x: canvas.midX, y: canvas.midY + canvas.height * 0.05)
    let ringFractions: [CGFloat] = [0.2, 0.3, 0.4]
    for (index, fraction) in ringFractions.enumerated() {
        let ringSize = canvas.width * fraction * 2.0
        let ringRect = NSRect(
            x: radarCenter.x - ringSize / 2.0,
            y: radarCenter.y - ringSize / 2.0,
            width: ringSize,
            height: ringSize
        )
        let ringPath = NSBezierPath(ovalIn: ringRect)
        ringPath.lineWidth = canvas.width * 0.015
        color(182, 239, 255, 0.12 + (CGFloat(index) * 0.06)).setStroke()
        ringPath.stroke()
    }

    let sweepPath = NSBezierPath()
    sweepPath.appendArc(
        withCenter: radarCenter,
        radius: canvas.width * 0.31,
        startAngle: 34,
        endAngle: 84
    )
    sweepPath.lineWidth = canvas.width * 0.11
    sweepPath.lineCapStyle = .round
    color(74, 231, 231, 0.28).setStroke()
    sweepPath.stroke()

    let routerRect = NSRect(
        x: canvas.midX - canvas.width * 0.22,
        y: canvas.minY + canvas.height * 0.16,
        width: canvas.width * 0.44,
        height: canvas.height * 0.13
    )
    let routerPath = NSBezierPath(roundedRect: routerRect, xRadius: canvas.width * 0.05, yRadius: canvas.width * 0.05)
    color(245, 250, 255, 0.95).setFill()
    routerPath.fill()

    color(13, 33, 62, 0.12).setStroke()
    routerPath.lineWidth = canvas.width * 0.008
    routerPath.stroke()

    let antennaYOffset = routerRect.maxY - canvas.height * 0.005
    for xPosition in [routerRect.minX + routerRect.width * 0.18, routerRect.maxX - routerRect.width * 0.18] {
        let antenna = NSBezierPath()
        antenna.move(to: NSPoint(x: xPosition, y: antennaYOffset))
        antenna.line(to: NSPoint(x: xPosition, y: antennaYOffset + canvas.height * 0.08))
        antenna.lineWidth = canvas.width * 0.012
        antenna.lineCapStyle = .round
        color(224, 244, 255, 0.95).setStroke()
        antenna.stroke()
    }

    let wifiCenter = NSPoint(x: canvas.midX, y: routerRect.maxY + canvas.height * 0.04)
    let arcFractions: [CGFloat] = [0.11, 0.18, 0.25]
    let arcWidths: [CGFloat] = [0.035, 0.028, 0.021]
    let arcColors = [
        color(255, 191, 92, 0.96),
        color(126, 239, 235, 0.96),
        color(211, 247, 255, 0.92),
    ]

    for index in 0..<arcFractions.count {
        let arcPath = NSBezierPath()
        arcPath.appendArc(
            withCenter: wifiCenter,
            radius: canvas.width * arcFractions[index],
            startAngle: 36,
            endAngle: 144
        )
        arcPath.lineWidth = canvas.width * arcWidths[index]
        arcPath.lineCapStyle = .round
        arcColors[index].setStroke()
        arcPath.stroke()
    }

    let beaconRect = NSRect(
        x: wifiCenter.x - canvas.width * 0.028,
        y: wifiCenter.y - canvas.width * 0.028,
        width: canvas.width * 0.056,
        height: canvas.width * 0.056
    )
    let beaconPath = NSBezierPath(ovalIn: beaconRect)
    color(255, 185, 90, 1.0).setFill()
    beaconPath.fill()

    let rimPath = NSBezierPath(roundedRect: canvas, xRadius: cornerRadius, yRadius: cornerRadius)
    rimPath.lineWidth = canvas.width * 0.015
    color(255, 255, 255, 0.12).setStroke()
    rimPath.stroke()

    NSGraphicsContext.restoreGraphicsState()
}

func pngData(for pixelSize: Int) -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Unable to create bitmap image rep")
    }

    bitmap.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)
    graphicsContext?.imageInterpolation = .high
    NSGraphicsContext.current = graphicsContext

    let rect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    NSColor.clear.setFill()
    rect.fill()
    drawIcon(in: rect)

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to convert icon to PNG")
    }

    return data
}

for spec in iconSpecs {
    let destinationURL = repositoryRoot.appendingPathComponent(spec.relativePath)
    try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try pngData(for: spec.pixelSize).write(to: destinationURL)
    print("Generated \(spec.relativePath)")
}
