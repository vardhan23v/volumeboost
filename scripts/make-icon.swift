// Draws the VolumeBoost app icon (1024×1024 PNG). Usage: swift scripts/make-icon.swift out.png
// Copyright (C) 2026 Vallur Sree Vardhan — GPL-3.0-or-later
import AppKit
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let inset: CGFloat = 100, rect = NSRect(x: inset, y: inset, width: size - 2*inset, height: size - 2*inset)
let path = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
NSGradient(colors: [NSColor(calibratedRed: 0.36, green: 0.30, blue: 0.95, alpha: 1),
                    NSColor(calibratedRed: 0.10, green: 0.62, blue: 0.98, alpha: 1)])!.draw(in: path, angle: 60)
let cfg = NSImage.SymbolConfiguration(pointSize: 420, weight: .semibold)
    .applying(.init(paletteColors: [.white]))
let sym = NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
let s = sym.size
sym.draw(in: NSRect(x: (size - s.width)/2 - 20, y: (size - s.height)/2 + 40, width: s.width, height: s.height))
let plus = NSAttributedString(string: "400%", attributes: [.font: NSFont.systemFont(ofSize: 120, weight: .heavy),
                                                          .foregroundColor: NSColor.white.withAlphaComponent(0.9)])
plus.draw(at: NSPoint(x: (size - plus.size().width)/2, y: 175))
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
