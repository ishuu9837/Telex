import AppKit

/// Runs independently of audio state. Speech arriving after silence can always resume playback.
@MainActor final class PrompterPlaybackClock {
    private var timer: Timer?
    private weak var model: PrompterViewModel?
    var refreshPointer: (() -> Void)?
    init(model: PrompterViewModel) { self.model = model }
    func setRunning(_ running: Bool) {
        if !running { timer?.invalidate(); timer = nil; return }
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.refreshPointer?()
                self.model?.tick(Date())
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    func stop() { setRunning(false) }
}
