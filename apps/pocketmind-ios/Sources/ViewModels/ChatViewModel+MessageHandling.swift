import Combine
import Foundation
import OSLog

private let messageHandlingLogger = Logger(subsystem: "app.pocketmind", category: "Chat")

extension ChatViewModel {

    // MARK: - Stream token helper

    /// Parses a token from the LLM stream and updates the assistant message in-place.
    /// `thinkDone` tracks whether we've exited Qwen3's <think>...</think> wrapper that Qwen3 emits before its response.
    func applyStreamToken(
        _ token: String,
        rawBuffer: inout String,
        thinkDone: inout Bool,
        showThinking: Bool,
        idx: Int
    ) {
        rawBuffer += token
        let openTag  = ChatConstants.thinkOpenTag
        let closeTag = ChatConstants.thinkCloseTag
        if thinkDone {
            messages[idx].content += token
        } else if rawBuffer.hasPrefix(openTag) {
            if let closeRange = rawBuffer.range(of: closeTag) {
                let thinkText = String(rawBuffer[rawBuffer.index(rawBuffer.startIndex, offsetBy: openTag.count) ..< closeRange.lowerBound])
                let response  = String(rawBuffer[closeRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if showThinking {
                    messages[idx].thinkingContent = thinkText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                messages[idx].isThinking = false
                messages[idx].content = response
                thinkDone = true
            } else {
                // Still inside <think> — buffer or show depending on setting
                if showThinking {
                    messages[idx].isThinking = true
                    messages[idx].thinkingContent = String(rawBuffer.dropFirst(openTag.count))
                }
            }
        } else if openTag.hasPrefix(rawBuffer) {
            // Still buffering opening tag — don't display yet
        } else {
            thinkDone = true
            messages[idx].content = rawBuffer
        }
    }

    // MARK: - sendMessage

    func sendMessage() async {
        cancelSuggestionsGeneration()
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachments = imageAttachments

        // Auto-load vision model if needed but not loaded
        let hasImages = !attachments.isEmpty
        let needsVision = hasImages && settings.visionEnabled
        if needsVision && !llmService.isVisionModelLoaded {
            let visionModel = settings.selectedVisionModel
            if visionModel.isDownloaded {
                // Download mmproj if needed (CLIP vision encoder)
                if let mmprojURL = visionModel.mmprojURL,
                   !visionModel.isMmprojDownloaded,
                   let destURL = visionModel.mmprojLocalURL {
                    showToast("Downloading vision encoder…", systemImage: "arrow.down.circle")
                    do {
                        let (tempURL, _) = try await URLSession.shared.download(from: mmprojURL)
                        if FileManager.default.fileExists(atPath: destURL.path) {
                            try FileManager.default.removeItem(at: destURL)
                        }
                        try FileManager.default.moveItem(at: tempURL, to: destURL)
                    } catch {
                        showToast("Vision encoder download failed: \(error.localizedDescription)", systemImage: "exclamationmark.triangle")
                        return
                    }
                }

                do {
                    showToast("Loading vision model…", systemImage: "eye")
                    let loadRole: ModelType = visionModel.isIntegrated ? .text : .vision
                    let mmprojPath = visionModel.isMmprojDownloaded ? visionModel.mmprojLocalURL : nil
                    // Vision needs at least 8192 context — CLIP image embeddings use ~4000+ tokens
                    let visionContextSize = max(UInt32(settings.contextSize), UInt32(LLMConstants.largeContextSize))
                    try await llmService.loadModel(
                        at: visionModel.localURL,
                        contextSize: visionContextSize,
                        role: loadRole,
                        isIntegrated: visionModel.isIntegrated,
                        mmprojURL: mmprojPath
                    )
                } catch {
                    showToast("Vision model failed to load: \(error.localizedDescription)", systemImage: "exclamationmark.triangle")
                    return
                }
            } else {
                showToast("Vision model required. Go to Settings → Models to download one.", systemImage: "photo.badge.plus")
                return
            }
        }

        guard !text.isEmpty || !attachments.isEmpty, !isGenerating, isModelLoaded else { return }

        hapticService.impact(.light)
        inputText = ""
        imageAttachments.removeAll()
        replyingTo = nil

        // Build user message with image attachments
        let userMessage = ChatMessage(
            role: .user,
            content: text,
            imageAttachments: attachments,
            processedWithVision: false
        )
        messages.append(userMessage)
        DebugLogStore.shared.log("USER: \(text) | images: \(attachments.count)", category: "LLM")

        // Auto-title: derive session title from the first user message.
        if sessionManager != nil && sessionTitle == "New Chat" {
            sessionTitle = String(text.prefix(ChatConstants.maxSessionTitleLength))
        }
        errorMessage = nil

        // Build system prompt before showing the assistant placeholder.
        isPreparing = true
        defer { isPreparing = false }
        let systemPrompt = await systemPromptBuilder.buildSystemPrompt()

        let assistantMsg = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMsg)
        let assistantID = assistantMsg.id

        // Snapshot history without the empty assistant placeholder.
        let ramGB = Int(ProcessInfo.processInfo.physicalMemory / ChatConstants.bytesPerGB)
        let historyLimit = ramGB >= ChatConstants.largeContextRAMThresholdGB ? ChatConstants.largeHistoryLimit : ChatConstants.smallHistoryLimit
        let historyMessages = Array(messages.dropLast().suffix(historyLimit))

        let showThinking = thinkingEnabled

        // Determine model role: vision if images attached and vision is enabled
        let useVision = needsVision
        let modelRole: ModelType = useVision ? .vision : .text

        do {
            try await streamLLMResponse(
                systemPrompt: systemPrompt,
                messages: historyMessages,
                assistantID: assistantID,
                showThinking: showThinking,
                modelRole: modelRole
            )
            // Mark message as processed with vision if applicable
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx].processedWithVision = useVision
                messageHandlingLogger.info("📤 USER: \(text, privacy: .public)")
                messageHandlingLogger.info("RAW_LLM: \(self.messages[idx].content, privacy: .public)")
                DebugLogStore.shared.log("RAW_LLM: \(messages[idx].content)", category: "LLM")
            }
        } catch is CancellationError {
            // User cancelled — leave partial content visible
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[idx].content = "Error: \(error.localizedDescription)"
            }
            errorMessage = error.localizedDescription
        }

        await finalizeResponse(assistantID: assistantID, text: text, showThinking: showThinking)
    }

    // MARK: - Post-streaming finalization

    private func finalizeResponse(assistantID: UUID, text: String, showThinking: Bool) async {
        guard let idx = messages.firstIndex(where: { $0.id == assistantID }) else { return }

        // Web search: if LLM output contains [WEB_SEARCH:{...}], execute and re-generate.
        if let searchSvc = webSearchService,
           settings.webSearchEnabled,
           let args = systemPromptBuilder.extractWebSearchQuery(from: messages[idx].content) {
            messages[idx].content = ""
            await performWebSearch(
                query: args.query,
                maxResults: args.maxResults,
                searchSvc: searchSvc,
                assistantID: assistantID,
                showThinking: showThinking
            )
        } else if messages[idx].content.contains("[WEB_SEARCH:") {
            let rawContent = String(messages[idx].content.prefix(ChatConstants.rawLogPreviewLength))
            messageHandlingLogger.warning("🔍 WEB_SEARCH block detected but extractWebSearchQuery returned nil — content: '\(rawContent, privacy: .public)'")
        }

        // Calendar actions on final output
        if let finalIdx = messages.firstIndex(where: { $0.id == assistantID }) {
            messages[finalIdx].isThinking = false
            let (content, previews, freeSlots) = await systemPromptBuilder.executeCalendarActions(in: messages[finalIdx].content)
            messages[finalIdx].content = content
            messages[finalIdx].calendarEventPreviews = previews
            messages[finalIdx].calendarFreeSlots = freeSlots
            messageHandlingLogger.info("✅ FINAL: \(content, privacy: .public) | events=\(previews.count) slots=\(freeSlots.count)")
            DebugLogStore.shared.log("FINAL: events=\(previews.count) slots=\(freeSlots.count) — \(String(content.prefix(ChatConstants.rawLogPreviewLength)))", category: "LLM")
        }
    }

    // MARK: - Stream helpers

    func streamLLMResponse(
        systemPrompt: String,
        messages historyMessages: [ChatMessage],
        assistantID: UUID,
        showThinking: Bool,
        modelRole: ModelType
    ) async throws {
        var raw = ""
        var thinkDone = false

        for try await token in llmService.generate(systemPrompt: systemPrompt, messages: historyMessages, thinkingEnabled: showThinking, modelRole: modelRole) {
            guard let idx = messages.firstIndex(where: { $0.id == assistantID }) else { break }
            applyStreamToken(token, rawBuffer: &raw, thinkDone: &thinkDone, showThinking: showThinking, idx: idx)
        }
    }

    func performWebSearch(
        query: String,
        maxResults: Int,
        searchSvc: any WebSearchServiceProtocol,
        assistantID: UUID,
        showThinking: Bool
    ) async {
        messageHandlingLogger.info("🔍 WEB_SEARCH extracted query='\(query, privacy: .public)' maxResults=\(maxResults)")
        DebugLogStore.shared.log("WEB_SEARCH query='\(query)' maxResults=\(maxResults)", category: "Search")
        do {
            let results = try await searchSvc.search(query: query, maxResults: maxResults)
            messageHandlingLogger.info("🔍 WEB_SEARCH got \(results.count) results for '\(query, privacy: .public)'")
            DebugLogStore.shared.log("WEB_SEARCH got \(results.count) results for '\(query)'", category: "Search")
            let resultText = results.enumerated().map { i, r in
                "[\(i + 1)] \(r.title)\nURL: \(r.url)\n\(r.snippet)"
            }.joined(separator: "\n\n")
            let toolMsg = ChatMessage(
                role: .user,
                content: "[SEARCH_RESULTS for \"\(query)\"]:\n\(resultText)\n\nAnswer the original question directly. No preamble. No disclaimers. Be concise. Use location/timezone from context."
            )
            let synthesisPrompt = await systemPromptBuilder.buildSynthesisPrompt()
            messageHandlingLogger.info("🔍 WEB_SEARCH starting synthesis pass")
            DebugLogStore.shared.log("WEB_SEARCH starting synthesis pass", category: "Search")
            var raw2 = ""
            var thinkDone2 = false
            for try await token in llmService.generate(
                systemPrompt: synthesisPrompt,
                messages: [toolMsg],
                thinkingEnabled: showThinking,
                modelRole: .text
            ) {
                guard let i = messages.firstIndex(where: { $0.id == assistantID }) else { break }
                applyStreamToken(token, rawBuffer: &raw2, thinkDone: &thinkDone2, showThinking: showThinking, idx: i)
            }
            let synthesisPreview = String(messages.first(where: { $0.id == assistantID })?.content.prefix(ChatConstants.synthesisLogPreviewLength) ?? "")
            messageHandlingLogger.info("🔍 WEB_SEARCH synthesis done, content='\(synthesisPreview, privacy: .public)'")
            DebugLogStore.shared.log("WEB_SEARCH synthesis done: '\(synthesisPreview)'", category: "Search")
            if let i = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[i].isWebSearchResult = true
            }
        } catch is CancellationError {
            // User cancelled — leave partial content visible
        } catch {
            messageHandlingLogger.error("🔍 WEB_SEARCH failed: \(error.localizedDescription, privacy: .public)")
            DebugLogStore.shared.log("WEB_SEARCH failed: \(error.localizedDescription)", category: "Search", level: .error)
            if let i = messages.firstIndex(where: { $0.id == assistantID }) {
                messages[i].content = "Search failed: \(error.localizedDescription)"
            }
        }
    }
}
