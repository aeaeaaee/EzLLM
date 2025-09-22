# EzLLM — Apple Foundation Models Integration Spec (Draft v0.1)

Date: 2025-09-22
Owner: Michael Yeung
Apple Docs Link: https://developer.apple.com/documentation/FoundationModels
Status: Draft for alignment — no implementation yet

## 1) Summary and Goals
- Integrate Apple’s on-device Foundation Models to power chat features.
- Provide low-latency, private, on-device generation with optional streaming UI.
- Maintain clear abstractions so we can swap or augment providers in the future.

## 2) Non-Goals (for this initial phase)
- No cloud/off-device model usage by default (Private Cloud Compute or remote fallback is out of scope for v1; can revisit as opt-in later).
- No tool/function-calling in v1. We may design for future extensibility but won’t implement it now.
- No long-term “memory” or RAG in v1. Keep sessions stateless beyond the visible chat history.

## 3) Platform Assumptions & Constraints
- OS: iOS 26 only
- Hardware: iPhone (A17 Pro or later) or iPad (M1 or later).
- SDK: Xcode 16
- Privacy: On-device only; no network calls during inference or UI flows.

## 4) User Stories
- As a user, I can enter a prompt and receive a natural-language reply locally.
- As a user, I can see tokens stream in real time and cancel generation.
- As a user, I can retry/regenerate the last response.
- As a user, I can choose creativity settings (e.g., Balanced/Creative/Precise).
- As a user, I can create multiple chats, each with a separate history.
- As a user, I can rename a chat and see that name displayed in ChatUI.
- New chats are auto-named Chat1, Chat2, … and can be renamed.

## 5) Scope by Phase
- Phase 1 (MVP):
  - Text-only chat on-device
  - Streaming responses + cancel
  - Basic settings: style
  - Guardrails on by default with user-toggle (if API exposes it)
  - Clipboard and selection improvements

## 6) UX Specification (high level)
- Chat states: Idle → Generating (streaming) → Completed/Error
- Message bubbles for user and assistant
- Message composer: text field, send button, stop button (visible when generating; stop discards partial output)
- Settings sheet:
  - Style: Creative / Balanced / Precise (maps to temperature presets)
  - Guardrails toggle (per chat, if available)
- Empty state: instructive placeholder (e.g., “Ask anything…”) when no messages
- Multiple chats: new-chat action at top-right (+) to start a fresh conversation with separate history.
- Chat title: display the user-set chat name in ChatUI (do not show model variant in the header). A pencil icon allows quick rename.
- Style can be changed mid-thread; changes apply to subsequent responses.
- Access: gear button in the ChatUI header opens a per‑chat settings sheet.

## 7) Architecture Overview
- UI (SwiftUI): `ChatUI`, `SettingsUI`
- Domain Models: `ChatMessage`, `GenerationOptions`, `GenerationResult`
- Provider Abstraction: `ChatLLMProvider` protocol + `FoundationModelsProvider` implementation
- Session object encapsulates streaming and cancellation
- Feature gate: Primarily via App Store device filters; `FoundationModelsCapability.isAvailable` used for test builds and defensive checks.

```mermaid
flowchart TB
  UI[ChatUI + SettingsUI (SwiftUI)] --> Provider[ChatLLMProvider]
  Provider --> FM[FoundationModelsProvider (on-device)]
  FM -->|stream| UI
```

## 8) Data Models (App-level)
- ChatThread
  - id: UUID
  - title: String (user-set; displayed in ChatUI)
  - createdAt: Date
  - updatedAt: Date
  - stylePreset: enum { creative, balanced, precise } (per chat)
  - guardrailsEnabled: Bool (per chat)
  - messages: [ChatMessage]
- ChatMessage
  - id: UUID
  - role: enum { system, user, assistant }
  - text: String
  - timestamp: Date
  - metadata: [String: Any] (reserved)

- GenerationOptions
  - systemPrompt: String
  - temperature: Double (0.0–2.0; defaults based on style preset)
  - topP: Double (0.0–1.0)
  - modelVariant: enum { auto, small, medium } (exact options depend on Apple APIs)
  - safety: SafetyPolicy (if surfaced)

- GenerationResult
  - text: String
  - usage: TokenUsage? { promptTokens, outputTokens }
  - finishReason: enum { stop, length, safety, cancel, error }
  - latencyMs: Int?
  - safetyFindings: [SafetyFinding]? (if surfaced)

## 8A) Persistence
- Storage: Core Data (local only) for `ChatThread` and `ChatMessage`.
- Retention: unlimited; user can “Clear all” chat history from Settings.
- Clear All behavior: clears messages across all chats but preserves chat threads and their names (titles are not reset; counter not reset).
- No server sync; data remains on-device.

## 9) Provider Abstraction (Functions the Chat needs)
We will define a provider protocol the chat layer calls. The names can be adjusted to match Apple’s final API surface after we explore the SDK, but these capture the integration points we need.
In v1, this is a thin wrapper over Apple Foundation Models to encapsulate streaming and cancellation; no external providers.

- ChatLLMProvider
  - func isSupported() -> Bool
  - func makeSession(config: ProviderConfig) -> ChatSession

- ProviderConfig
  - defaultOptions: GenerationOptions
  - loggingEnabled: Bool

- ChatSession
  - func generate(messages: [ChatMessage],
                 options: GenerationOptions?,
                 onToken: (String) -> Void,
                 onCompletion: (Result<GenerationResult, Error>) -> Void)
  - func cancel()

## 10) Mapping to Apple Foundation Models (tentative)
Subject to API confirmation; keep flexible wrappers:
- Model creation: construct a text-capable model instance (variant selectable) on-device.
- Generation call: pass in concatenated prompt built from `system + history + user` with options (temperature, topP).
- Streaming: if supported, iterate tokens and forward to `onToken`.
- Cancellation: keep a handle/task and cancel.
- Safety: if API exposes safety filtering, capture findings and map to `finishReason = .safety` or include in `safetyFindings`.

## 11) Prompt Assembly
- System prompt: empty in v1 (no UI).
- No hidden system prompt is injected in v1.
- Conversation history: include the full thread in v1; do not manually trim by tokens—rely on the model/SDK to limit context.
- User message: appended last.
- Simple formatting (e.g., role-prefixed transcript) unless Apple SDK provides structured chat API.

## 12) Error Handling
- Unsupported device/OS → primarily gated via App Store device filters; in test builds, show “feature unavailable” state.
- Input too long → user-facing error with guidance.
- Safety blocked → explain at high level without leaking policy internals.
- Cancelled → discard partial output.
- Generic generation failure → retry affordance.

## 13) Settings → Options Mapping
- Style presets (temperature-only; topP is model default = nil for all presets):
  - Creative: temperature = 0.9
  - Balanced (default): temperature = nil (use model default)
  - Precise: temperature = 0.25
- Model variant: default Auto (no variant UI in v1).
- UI surfaces style presets only; raw temperature/topP are not directly exposed.
- Default preset: Balanced. Style is saved per chat and can be adjusted mid-thread (affects subsequent generations).
- Guardrails: default ON for every new chat; per-chat toggle in the Settings sheet.

## 14) Privacy & Telemetry
- All inference on-device. No raw prompts/outputs sent to servers in v1.
- Local analytics only (e.g., counts, average latency) unless explicitly opted-in by user for diagnostics.
- No PII logging.
- No 3rd‑party SDKs; rely on App Store Connect analytics and Apple crash reports.

## 15) Performance Targets (initial)
- Time-to-first-token (TTFT): < 500ms on supported devices (stretch goal; TBD after measurement).
- End-to-end latency for 100 tokens: < 2s typical.
- Smooth streaming at ≥20 tokens/sec typical.

## 15A) Accessibility & Internationalization
- Language: English only in v1.
- Accessibility: Support Dynamic Type and basic VoiceOver labels.

## 16) Feature Flags
- `enableFoundationModels` (global)

## 17) Milestones & Acceptance Criteria
- M0 — Alignment (this doc):
  - Spec agreed; open questions resolved.
- M1 — Text MVP:
  - Supported device check and gating.
  - Text chat with streaming & cancel.
  - Settings: style.
  - Persistence: Core Data storage for chats; “Clear all” action.
  - Basic error handling and safety mapping.
  - Acceptance test: 5 prompts with smooth streaming; cancel works; no crashes on unsupported devices.
- M2 — Polishing:
  - UI/UX refinements, multi-chat support, persistence of settings, light theming.

## 18) Open Questions for Alignment
1) Telemetry: what metrics are allowed and desired locally? Any opt-in for diagnostics?
- We have not set up a server for that. SO just use App Store would be enough
2) Internationalization: initial languages to support?
- English, then we can add other languages later
3) Persistence: how to store chat transcripts locally and what retention policy?
- Set up in local data inside phone/pad
4) Model variant surfacing: expose selectable variants or keep Auto only?
 - User can customize the model variant before creating a chat.
5) Default system prompt text and whether users can customize it per chat.
- None (according to user input). We can update it later to let the user save new prompts for that.

## 19) Appendix — Pseudocode Interfaces (illustrative only)
```swift
// Provider protocol the UI/View layer will call
protocol ChatLLMProvider {
    func isSupported() -> Bool
    func makeSession(config: ProviderConfig) -> ChatSession
}

struct ProviderConfig {
    var defaultOptions: GenerationOptions
    var loggingEnabled: Bool
}

protocol ChatSession {
    func generate(
        messages: [ChatMessage],
        options: GenerationOptions?,
        onToken: @escaping (String) -> Void,
        onCompletion: @escaping (Result<GenerationResult, Error>) -> Void
    )
    func cancel()
}

// App-level models
struct ChatThread {
    let id: UUID
    var title: String // user-set; displayed in ChatUI
    var createdAt: Date
    var updatedAt: Date
    var messages: [ChatMessage]
}

struct ChatMessage {
    enum Role { case system, user, assistant }
    let id: UUID
    let role: Role
    let text: String
    let timestamp: Date
}

struct GenerationOptions {
    var systemPrompt: String
    var temperature: Double
    var topP: Double
    var modelVariant: ModelVariant
}

enum ModelVariant { case auto, small, medium }

struct GenerationResult {
    let text: String
    let finishReason: FinishReason
}

enum FinishReason { case stop, length, safety, cancel, error }
```

---
End of spec draft. Please review the open questions and scope/milestones so we can lock v1.
