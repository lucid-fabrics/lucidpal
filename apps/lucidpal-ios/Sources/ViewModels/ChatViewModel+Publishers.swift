import Combine
import Foundation
import OSLog

@MainActor
extension ChatViewModel {

    func setupPublishers() {
        setupServicePublishers()
        setupPersistencePublisher()
        setupSpeechAutoSendPublisher()
    }

    // MARK: - Service binding publishers

    private func setupServicePublishers() {
        // Publishers — sink used instead of assign(to:) because existentials can't project @Published.
        llmService.isLoadingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isModelLoading = $0 }
            .store(in: &cancellables)
        llmService.isLoadedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loaded in
                self?.isModelLoaded = loaded
                guard loaded, self?.messages.isEmpty == true, self?.pendingInput == nil else { return }
                Task { [weak self] in await self?.generateSuggestedPrompts() }
            }
            .store(in: &cancellables)
        llmService.isGeneratingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isGenerating = $0 }
            .store(in: &cancellables)
        llmService.contextTruncatedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.showToast("Conversation too long — oldest messages were trimmed.", systemImage: "scissors")
            }
            .store(in: &cancellables)
        speechService.isRecordingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isSpeechRecording = $0 }
            .store(in: &cancellables)
        speechService.isAuthorizedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isSpeechAvailable = $0 }
            .store(in: &cancellables)
        speechService.isTranscribingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isSpeechTranscribing = $0 }
            .store(in: &cancellables)
        speechService.transcriptionErrorPublisher
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.errorMessage = $0 }
            .store(in: &cancellables)

        // Forward live transcript into the input field while recording
        speechService.transcriptPublisher
            .filter { !$0.isEmpty }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self, !self.discardNextTranscript else { return }
                self.inputText = $0
            }
            .store(in: &cancellables)

        // Observe AirPods auto-listening state
        airPodsCoordinator?.isAutoListeningPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isAutoListening = $0 }
            .store(in: &cancellables)

        // Auto-dismiss error banner after errorAutoDismissSeconds
        $errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                self?.errorDismissTask?.cancel()
                guard msg != nil else { return }
                self?.errorDismissTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(ChatConstants.errorAutoDismissSeconds))
                    self?.errorMessage = nil
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Persistence publisher

    private func setupPersistencePublisher() {
        // Persist messages on change — debounced on MainActor, disk write offloaded to background.
        $messages
            .debounce(for: .seconds(ChatConstants.persistenceDebounceSeconds), scheduler: RunLoop.main)
            .sink { [weak self] msgs in
                guard let self else { return }
                if let sm = self.sessionManager, let sid = self.sessionID {
                    let session = ChatSession(
                        id: sid, title: self.sessionTitle,
                        createdAt: self.sessionCreatedAt, updatedAt: .now, messages: msgs
                    )
                    sm.save(session)
                    self.onSessionUpdated?(session.meta)
                } else {
                    self.history.save(msgs)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Speech auto-send publisher

    private func setupSpeechAutoSendPublisher() {
        // Auto-submit when speech recognition ends naturally (final result / silence timeout).
        // If the user manually tapped the mic button to stop, suppressSpeechAutoSend is set
        // in toggleSpeech() and the observer skips the send.
        speechService.isRecordingPublisher
            .removeDuplicates()
            .filter { !$0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.discardNextTranscript {
                    self.discardNextTranscript = false
                    self.inputText = ""
                    self.suppressSpeechAutoSend = false
                    return
                }
                if self.suppressSpeechAutoSend {
                    self.suppressSpeechAutoSend = false
                    return
                }
                guard self.settings.speechAutoSendEnabled else { return }
                guard !self.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                Task { [weak self] in await self?.sendMessage() }
            }
            .store(in: &cancellables)
    }
}
