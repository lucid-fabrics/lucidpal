import AVFoundation
import Combine
import Foundation
import OSLog

private let coordinatorLogger = Logger(subsystem: "com.pocketmind", category: "AirPodsVoiceCoordinator")

/// Coordinates auto-voice activation based on AirPods connection state and user settings.
@MainActor
final class AirPodsVoiceCoordinator: ObservableObject {
    @Published private(set) var isAutoListening = false

    private let audioRouteMonitor: any AudioRouteMonitorProtocol
    private let speechService: any SpeechServiceProtocol
    private let settings: AppSettingsProtocol

    private var cancellables = Set<AnyCancellable>()
    private var shouldAutoResume = false

    init(audioRouteMonitor: any AudioRouteMonitorProtocol, speechService: any SpeechServiceProtocol, settings: AppSettingsProtocol) {
        self.audioRouteMonitor = audioRouteMonitor
        self.speechService = speechService
        self.settings = settings

        observeAudioRoute()
        observeInterruptions()
    }

    // MARK: - Public Methods

    func startMonitoring() {
        evaluateAutoVoice()
    }

    func stopMonitoring() {
        isAutoListening = false
        if speechService.isRecording {
            speechService.stopRecording()
        }
    }

    // MARK: - Private Methods

    private func observeAudioRoute() {
        audioRouteMonitor.isAirPodsConnectedPublisher
            .sink { [weak self] isConnected in
                self?.handleAirPodsConnectionChange(isConnected)
            }
            .store(in: &cancellables)
    }

    private func observeInterruptions() {
        speechService.isInterruptedPublisher
            .sink { [weak self] isInterrupted in
                self?.handleInterruptionChange(isInterrupted)
            }
            .store(in: &cancellables)
    }

    private func handleAirPodsConnectionChange(_ isConnected: Bool) {
        guard settings.airpodsAutoVoiceEnabled else { return }

        if isConnected {
            coordinatorLogger.debug("AirPods connected — starting auto-voice")
            startAutoVoice()
        } else {
            coordinatorLogger.debug("AirPods disconnected — stopping auto-voice")
            stopAutoVoice()
        }
    }

    private func handleInterruptionChange(_ isInterrupted: Bool) {
        guard settings.airpodsAutoVoiceEnabled, audioRouteMonitor.isAirPodsConnected else { return }

        if isInterrupted {
            coordinatorLogger.debug("Audio interrupted — marking for auto-resume")
            shouldAutoResume = isAutoListening
        } else if shouldAutoResume {
            coordinatorLogger.debug("Audio interruption ended — resuming auto-voice")
            shouldAutoResume = false
            // Delay slightly to ensure audio session is ready
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                self?.startAutoVoice()
            }
        }
    }

    private func evaluateAutoVoice() {
        guard settings.airpodsAutoVoiceEnabled, audioRouteMonitor.isAirPodsConnected else {
            stopAutoVoice()
            return
        }
        startAutoVoice()
    }

    private func startAutoVoice() {
        guard !speechService.isRecording, speechService.isAuthorized else { return }

        do {
            try speechService.startRecording()
            isAutoListening = true
            coordinatorLogger.debug("Auto-voice started")
        } catch {
            coordinatorLogger.error("Failed to start auto-voice: \(error)")
            isAutoListening = false
        }
    }

    private func stopAutoVoice() {
        if speechService.isRecording {
            speechService.stopRecording()
        }
        isAutoListening = false
        coordinatorLogger.debug("Auto-voice stopped")
    }
}
