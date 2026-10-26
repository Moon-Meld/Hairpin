import AppKit
import CoreGraphics

// Function to render cover banner
func renderCover(isChinese: Bool, outputPath: String) {
    let width: CGFloat = 1280
    let height: CGFloat = 640
    let scale: CGFloat = 2.0

    let pixelWidth = Int(width * scale)
    let pixelHeight = Int(height * scale)

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: pixelWidth,
        height: pixelHeight,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Failed to create CGContext")
    }

    ctx.scaleBy(x: scale, y: scale)

    // 1. Background: Deep obsidian gradient (#080b11 to #101726)
    let bgColors = [
        NSColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1.0).cgColor,
        NSColor(red: 0.08, green: 0.11, blue: 0.18, alpha: 1.0).cgColor,
        NSColor(red: 0.04, green: 0.05, blue: 0.07, alpha: 1.0).cgColor
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 0.5, 1.0]
    if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])
    }

    // 2. Ambient radial glows
    ctx.saveGState()
    let amberGlow = NSColor(red: 0.94, green: 0.76, blue: 0.50, alpha: 0.14).cgColor
    let glowColors = [amberGlow, NSColor.clear.cgColor] as CFArray
    if let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        // Left glow behind icon
        ctx.drawRadialGradient(
            glowGrad,
            startCenter: CGPoint(x: 180, y: 440),
            startRadius: 0,
            endCenter: CGPoint(x: 180, y: 440),
            endRadius: 280,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        // Right glow behind mockup
        ctx.drawRadialGradient(
            glowGrad,
            startCenter: CGPoint(x: 920, y: 350),
            startRadius: 0,
            endCenter: CGPoint(x: 920, y: 350),
            endRadius: 360,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }
    ctx.restoreGState()

    // 3. Elegant outer border
    ctx.saveGState()
    let outerCardRect = CGRect(x: 20, y: 20, width: width - 40, height: height - 40)
    let outerPath = CGPath(roundedRect: outerCardRect, cornerWidth: 20, cornerHeight: 20, transform: nil)
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.08).cgColor)
    ctx.setLineWidth(1.0)
    ctx.addPath(outerPath)
    ctx.strokePath()
    ctx.restoreGState()

    // 4. Load & Draw the Hairpin App Icon
    let iconURL = URL(fileURLWithPath: "Hairpin/Resources/AppIcon-1024.png")
    if let iconImageSource = CGImageSourceCreateWithURL(iconURL as CFURL, nil),
       let iconCGImage = CGImageSourceCreateImageAtIndex(iconImageSource, 0, nil) {
        
        let iconSize: CGFloat = 140
        let iconRect = CGRect(x: 80, y: 410, width: iconSize, height: iconSize)
        
        // Icon drop shadow
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: NSColor(red: 0, green: 0, blue: 0, alpha: 0.6).cgColor)
        
        let iconClipPath = CGPath(roundedRect: iconRect, cornerWidth: 32, cornerHeight: 32, transform: nil)
        ctx.addPath(iconClipPath)
        ctx.clip()
        ctx.draw(iconCGImage, in: iconRect)
        ctx.restoreGState()
        
        // Border around icon
        ctx.saveGState()
        ctx.setStrokeColor(NSColor(red: 0.94, green: 0.76, blue: 0.50, alpha: 0.35).cgColor)
        ctx.setLineWidth(1.5)
        ctx.addPath(iconClipPath)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // Helper to draw text
    func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(str)
        ctx.saveGState()
        ctx.textPosition = point
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    // 5. Typography
    let titleFont = NSFont.systemFont(ofSize: 52, weight: .heavy)
    drawText("Hairpin", at: CGPoint(x: 80, y: 340), font: titleFont, color: .white)

    let starFont = NSFont.systemFont(ofSize: 34, weight: .bold)
    drawText("✦", at: CGPoint(x: 282, y: 348), font: starFont, color: NSColor(red: 0.94, green: 0.76, blue: 0.50, alpha: 1.0))

    if !isChinese {
        // English Text
        let subtitleFont = NSFont.systemFont(ofSize: 19, weight: .semibold)
        drawText("Tame your menu bar. Reclaim the notch.", at: CGPoint(x: 80, y: 298), font: subtitleFont, color: NSColor(red: 0.94, green: 0.76, blue: 0.50, alpha: 0.95))

        let descFont = NSFont.systemFont(ofSize: 14, weight: .regular)
        drawText("Minimalist, privacy-first macOS menu bar agent", at: CGPoint(x: 80, y: 262), font: descFont, color: NSColor(white: 0.68, alpha: 1.0))
        drawText("for notched MacBooks. Zero SIP. Zero permissions.", at: CGPoint(x: 80, y: 238), font: descFont, color: NSColor(white: 0.55, alpha: 1.0))

        let pills = [
            ("macOS 13+ Ventura / Sonoma / Sequoia", NSColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 1.0)),
            ("Zero Accessibility / Keylogging Risk", NSColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1.0)),
            ("100% Native Swift 6 & AppKit Engine", NSColor(red: 0.96, green: 0.45, blue: 0.35, alpha: 1.0)),
            ("Zero Telemetry / Physical Network Block", NSColor(red: 0.94, green: 0.76, blue: 0.50, alpha: 1.0))
        ]

        var pillY: CGFloat = 176
        for (text, accentColor) in pills {
            let pillRect = CGRect(x: 80, y: pillY, width: 350, height: 26)
            ctx.saveGState()
            let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
            ctx.setFillColor(NSColor(white: 1.0, alpha: 0.04).cgColor)
            ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.07).cgColor)
            ctx.setLineWidth(1.0)
            ctx.addPath(pillPath)
            ctx.drawPath(using: .fillStroke)
            ctx.setFillColor(accentColor.cgColor)
            ctx.fillEllipse(in: CGRect(x: 92, y: pillY + 9, width: 8, height: 8))
            ctx.restoreGState()
            let pillFont = NSFont.systemFont(ofSize: 11.5, weight: .medium)
            drawText(text, at: CGPoint(x: 108, y: pillY + 7), font: pillFont, color: NSColor(white: 0.86, alpha: 1.0))
            pillY -= 32
        }
    } else {
        // Chinese Text
        let subtitleFont = NSFont.systemFont(ofSize: 20, weight: .semibold)
        drawText("整理杂乱菜单栏，释放刘海屏空间。", at: CGPoint(x: 80, y: 298), font: subtitleFont, color: NSColor(red: 0.94, green: 0.76, blue: 0.50, alpha: 0.95))

        let descFont = NSFont.systemFont(ofSize: 14, weight: .regular)
        drawText("专为刘海屏 MacBook 打造的原生极简管理工具", at: CGPoint(x: 80, y: 262), font: descFont, color: NSColor(white: 0.68, alpha: 1.0))
        drawText("无需关闭 SIP · 零权限依赖 · 隐私零外传", at: CGPoint(x: 80, y: 238), font: descFont, color: NSColor(white: 0.55, alpha: 1.0))

        let pills = [
            ("macOS 13+ Ventura / Sonoma / Sequoia 原生适配", NSColor(red: 0.22, green: 0.74, blue: 0.97, alpha: 1.0)),
            ("无需辅助功能权限 · 杜绝键盘监听风险", NSColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1.0)),
            ("100% 原生 Swift 6 & AppKit 引擎驱动", NSColor(red: 0.96, green: 0.45, blue: 0.35, alpha: 1.0)),
            ("零网络外传 · 物理级 ATS 网络封锁", NSColor(red: 0.94, green: 0.76, blue: 0.50, alpha: 1.0))
        ]

        var pillY: CGFloat = 176
        for (text, accentColor) in pills {
            let pillRect = CGRect(x: 80, y: pillY, width: 350, height: 26)
            ctx.saveGState()
            let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
            ctx.setFillColor(NSColor(white: 1.0, alpha: 0.04).cgColor)
            ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.07).cgColor)
            ctx.setLineWidth(1.0)
            ctx.addPath(pillPath)
            ctx.drawPath(using: .fillStroke)
            ctx.setFillColor(accentColor.cgColor)
            ctx.fillEllipse(in: CGRect(x: 92, y: pillY + 9, width: 8, height: 8))
            ctx.restoreGState()
            let pillFont = NSFont.systemFont(ofSize: 11.5, weight: .medium)
            drawText(text, at: CGPoint(x: 108, y: pillY + 7), font: pillFont, color: NSColor(white: 0.86, alpha: 1.0))
            pillY -= 32
        }
    }

    // 6. Right Side: 3D MacBook notch render
    let bannerURL = URL(fileURLWithPath: "docs/assets/hero-banner.jpg")
    if let bannerSource = CGImageSourceCreateWithURL(bannerURL as CFURL, nil),
       let bannerCGImage = CGImageSourceCreateImageAtIndex(bannerSource, 0, nil) {
        
        let mockWidth: CGFloat = 680
        let mockHeight: CGFloat = 490
        let mockRect = CGRect(x: 540, y: 75, width: mockWidth, height: mockHeight)
        
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: NSColor(red: 0, green: 0, blue: 0, alpha: 0.75).cgColor)
        let mockClipPath = CGPath(roundedRect: mockRect, cornerWidth: 18, cornerHeight: 18, transform: nil)
        ctx.addPath(mockClipPath)
        ctx.clip()
        ctx.draw(bannerCGImage, in: mockRect)
        ctx.restoreGState()
        
        ctx.saveGState()
        ctx.setStrokeColor(NSColor(red: 0.94, green: 0.76, blue: 0.50, alpha: 0.28).cgColor)
        ctx.setLineWidth(1.2)
        ctx.addPath(mockClipPath)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // 7. Save output
    guard let finalCGImage = ctx.makeImage() else {
        fatalError("Failed to make final image")
    }

    let outURL = URL(fileURLWithPath: outputPath) as CFURL
    guard let destination = CGImageDestinationCreateWithURL(outURL, "public.png" as CFString, 1, nil) else {
        fatalError("Failed to create CGImageDestination")
    }

    CGImageDestinationAddImage(destination, finalCGImage, nil)
    if CGImageDestinationFinalize(destination) {
        print("✅ Created \(outputPath)")
    } else {
        fatalError("Failed to write PNG to \(outputPath)")
    }
}

renderCover(isChinese: false, outputPath: "docs/assets/cover.png")
renderCover(isChinese: true, outputPath: "docs/assets/cover_zh.png")
