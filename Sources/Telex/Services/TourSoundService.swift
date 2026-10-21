import AppKit

@MainActor final class TourSoundService {
    private var sound: NSSound?
    func play(enabled: Bool) {
        guard enabled else { stop(); return }
        sound?.stop()
        let next = NSSound(named: NSSound.Name("Tink"))
        next?.volume = 0.22
        next?.play()
        sound = next
    }
    func stop() { sound?.stop(); sound = nil }
}
