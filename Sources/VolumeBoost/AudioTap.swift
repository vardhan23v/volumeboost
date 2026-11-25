// VolumeBoost — Copyright (C) 2026 Vallur Sree Vardhan
// Licensed under the GNU General Public License v3.0 or later. See the LICENSE file.

import CoreAudio
import AudioToolbox
import Foundation

/// Captures all system audio with a muted process tap, boosts it, and plays it on the real speakers.
final class Booster {
    var gain: Float = 1.0          // 1.0 = 100%
    private(set) var running = false
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "VolumeBoost.io", qos: .userInteractive)
    private var listenerInstalled = false
    var onError: ((String) -> Void)?

    // MARK: helpers
    private static func defaultOutputDevice() -> AudioObjectID {
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return id
    }
    private static func stringProp(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var str: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, &str) == noErr, let s = str else { return nil }
        return s.takeRetainedValue() as String
    }
    private static func ownProcessObject() -> AudioObjectID {
        var pid = getpid()
        var obj = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
                                              mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr,
                                   UInt32(MemoryLayout<pid_t>.size), &pid, &size, &obj)
        return obj
    }

    // MARK: start / stop
    func start() {
        guard !running else { return }
        installDeviceListener()
        let outDev = Booster.defaultOutputDevice()
        guard let outUID = Booster.stringProp(outDev, kAudioDevicePropertyDeviceUID) else { return fail("No output device found") }

        let me = Booster.ownProcessObject()
        let desc = CATapDescription(stereoGlobalTapButExcludeProcesses: me == kAudioObjectUnknown ? [] : [me])
        desc.name = "VolumeBoost tap"
        desc.isPrivate = true
        desc.muteBehavior = .muted
        var err = AudioHardwareCreateProcessTap(desc, &tapID)
        guard err == noErr else { return fail("Could not capture system audio (\(err)). Allow VolumeBoost under System Settings › Privacy & Security › Screen & System Audio Recording.") }
        let tapUID = desc.uuid.uuidString

        let aggDesc: [String: Any] = [
            kAudioAggregateDeviceNameKey: "VolumeBoost",
            kAudioAggregateDeviceUIDKey: "VolumeBoost-" + UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outUID]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: tapUID]],
        ]
        err = AudioHardwareCreateAggregateDevice(aggDesc as CFDictionary, &aggID)
        guard err == noErr else { return fail("Could not create audio device (\(err))") }

        err = AudioDeviceCreateIOProcIDWithBlock(&procID, aggID, queue) { [unowned self] _, inData, _, outData, _ in
            self.process(UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inData)),
                         UnsafeMutableAudioBufferListPointer(outData))
        }
        guard err == noErr else { return fail("Could not start audio (\(err))") }
        err = AudioDeviceStart(aggID, procID)
        guard err == noErr else { return fail("Could not start audio (\(err))") }
        running = true
    }

    func stop() {
        if let p = procID { AudioDeviceStop(aggID, p); AudioDeviceDestroyIOProcID(aggID, p); procID = nil }
        if aggID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(aggID); aggID = AudioObjectID(kAudioObjectUnknown) }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID); tapID = AudioObjectID(kAudioObjectUnknown) }
        running = false
    }

    private func fail(_ msg: String) { stop(); onError?(msg) }

    private func installDeviceListener() {
        guard !listenerInstalled else { return }
        listenerInstalled = true
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main) { [weak self] _, _ in
            guard let self, self.running else { return }
            self.stop(); self.start()   // follow the new speakers/headphones
        }
    }

    // MARK: DSP
    private struct Chan { let ptr: UnsafeMutablePointer<Float>; let stride: Int; let frames: Int }
    private func channels(_ list: UnsafeMutableAudioBufferListPointer) -> [Chan] {
        var out: [Chan] = []
        for b in list {
            guard let d = b.mData else { continue }
            let n = max(Int(b.mNumberChannels), 1)
            let frames = Int(b.mDataByteSize) / (4 * n)
            let p = d.assumingMemoryBound(to: Float.self)
            for c in 0..<n { out.append(Chan(ptr: p + c, stride: n, frames: frames)) }
        }
        return out
    }

    @inline(__always) private func limit(_ x: Float) -> Float {
        let t: Float = 0.89            // about -1 dBFS: above this, round off smoothly instead of clipping
        let a = abs(x)
        if a <= t { return x }
        let y = t + (1 - t) * tanh((a - t) / (1 - t))
        return x < 0 ? -y : y
    }

    private func process(_ input: UnsafeMutableAudioBufferListPointer, _ output: UnsafeMutableAudioBufferListPointer) {
        let ins = channels(input), outs = channels(output)
        let g = gain
        for (i, o) in outs.enumerated() {
            if ins.isEmpty { for f in 0..<o.frames { o.ptr[f * o.stride] = 0 }; continue }
            let src = ins[min(i, ins.count - 1)]
            let n = min(o.frames, src.frames)
            for f in 0..<n { o.ptr[f * o.stride] = limit(src.ptr[f * src.stride] * g) }
            if n < o.frames { for f in n..<o.frames { o.ptr[f * o.stride] = 0 } }
        }
    }
}
