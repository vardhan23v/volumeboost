// VolumeBoost — boost your Mac's sound above 100%.
// Copyright (C) 2026 Vallur Sree Vardhan
// This program is free software: you can redistribute it and/or modify it under the terms of the
// GNU General Public License as published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version. See the LICENSE file.

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let booster = Booster()
    var item: NSStatusItem!
    var window: NSWindow!

    // Menu-bar controls
    let menuSlider = NSSlider(value: 200, minValue: 100, maxValue: 400, target: nil, action: nil)
    let menuLabel = NSTextField(labelWithString: "")
    let toggleItem = NSMenuItem(title: "Boost On", action: #selector(toggleBoost), keyEquivalent: "")

    // Window controls
    let bigLabel = NSTextField(labelWithString: "")
    let winSlider = NSSlider(value: 200, minValue: 100, maxValue: 400, target: nil, action: nil)
    let onSwitch = NSSwitch()
    let status = NSTextField(labelWithString: "")

    func applicationDidFinishLaunching(_ n: Notification) {
        buildMainMenu()
        buildStatusItem()
        buildWindow()
        booster.onError = { [weak self] msg in
            DispatchQueue.main.async { self?.refresh(error: msg) }
        }
        let saved = UserDefaults.standard.double(forKey: "gainPercent")
        setGain(saved >= 100 ? saved : 200)
        booster.start()
        refresh()
        showWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow(); return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ n: Notification) { booster.stop() }

    // MARK: UI construction
    func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Show VolumeBoost Window", action: #selector(showWindow), keyEquivalent: "0").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit VolumeBoost", action: #selector(quit), keyEquivalent: "q").target = self
        appItem.submenu = appMenu
        let winItem = NSMenuItem(); main.addItem(winItem)
        let winMenu = NSMenu(title: "Window")
        winMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        winMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        winItem.submenu = winMenu
        NSApp.mainMenu = main
    }

    func buildStatusItem() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 54))
        menuLabel.frame = NSRect(x: 16, y: 30, width: 210, height: 18)
        menuSlider.frame = NSRect(x: 14, y: 6, width: 212, height: 22)
        menuSlider.target = self; menuSlider.action = #selector(sliderMoved(_:)); menuSlider.isContinuous = true
        view.addSubview(menuLabel); view.addSubview(menuSlider)
        let sliderItem = NSMenuItem(); sliderItem.view = view
        let menu = NSMenu()
        menu.addItem(sliderItem)
        menu.addItem(.separator())
        toggleItem.target = self; menu.addItem(toggleItem)
        let show = NSMenuItem(title: "Open Window", action: #selector(showWindow), keyEquivalent: ""); show.target = self
        menu.addItem(show)
        let quit = NSMenuItem(title: "Quit VolumeBoost", action: #selector(quit), keyEquivalent: "q"); quit.target = self
        menu.addItem(quit)
        item.menu = menu
    }

    func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 250),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "VolumeBoost"
        window.isReleasedWhenClosed = false
        window.center()

        let icon = NSImageView(image: NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: nil)!)
        icon.symbolConfiguration = .init(pointSize: 34, weight: .regular)
        icon.contentTintColor = .controlAccentColor

        bigLabel.font = .systemFont(ofSize: 30, weight: .semibold)
        bigLabel.alignment = .center

        winSlider.numberOfTickMarks = 7
        winSlider.target = self; winSlider.action = #selector(sliderMoved(_:)); winSlider.isContinuous = true
        let lo = NSTextField(labelWithString: "100%"), hi = NSTextField(labelWithString: "400%")
        for l in [lo, hi] { l.font = .systemFont(ofSize: 11); l.textColor = .secondaryLabelColor }
        let sliderRow = NSStackView(views: [lo, winSlider, hi]); sliderRow.spacing = 8

        onSwitch.target = self; onSwitch.action = #selector(switchFlipped)
        let switchRow = NSStackView(views: [NSTextField(labelWithString: "Boost"), onSwitch]); switchRow.spacing = 10

        status.font = .systemFont(ofSize: 12); status.textColor = .secondaryLabelColor
        status.alignment = .center; status.maximumNumberOfLines = 3; status.lineBreakMode = .byWordWrapping
        status.preferredMaxLayoutWidth = 320

        let stack = NSStackView(views: [icon, bigLabel, sliderRow, switchRow, status])
        stack.orientation = .vertical; stack.spacing = 12; stack.alignment = .centerX
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView(); content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            winSlider.widthAnchor.constraint(equalToConstant: 240),
        ])
        window.contentView = content
    }

    // MARK: actions
    func setGain(_ raw: Double) {
        let pct = (raw / 10).rounded() * 10
        booster.gain = Float(pct / 100)
        UserDefaults.standard.set(pct, forKey: "gainPercent")
        menuSlider.doubleValue = pct; winSlider.doubleValue = pct
        menuLabel.stringValue = "Volume boost: \(Int(pct))%"
        bigLabel.stringValue = "Boost: \(Int(pct))%"
    }
    @objc func sliderMoved(_ s: NSSlider) { setGain(s.doubleValue) }
    @objc func toggleBoost() { booster.running ? booster.stop() : booster.start(); refresh() }
    @objc func switchFlipped() {
        if (onSwitch.state == .on) != booster.running { toggleBoost() }
    }
    @objc func showWindow() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func quit() { booster.stop(); NSApp.terminate(nil) }

    func refresh(error: String? = nil) {
        let on = booster.running
        toggleItem.state = on ? .on : .off
        onSwitch.state = on ? .on : .off
        item.button?.image = NSImage(systemSymbolName: on ? "speaker.wave.3.fill" : "speaker.slash",
                                     accessibilityDescription: "VolumeBoost")
        if let error { status.stringValue = error; status.textColor = .systemRed }
        else { status.stringValue = on ? "Boosting all sound on this Mac." : "Boost is off — sound is normal."; status.textColor = .secondaryLabelColor }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
