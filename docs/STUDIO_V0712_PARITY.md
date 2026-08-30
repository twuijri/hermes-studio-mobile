# Hermes Studio v0.7.12 Mobile Parity

This document is the acceptance checklist for matching Hermes Studio v0.7.12 on Android and iOS. Statuses were independently re-audited against the implementation at `2d3396f`, not inferred from commit messages.

Status legend: `Complete`, `Partial`, `Broken`, `Missing`, `Desktop-only/remote surface`.

## P0 — Core runtime and conversation correctness

| Area | Acceptance requirement | Android | iOS | Upstream source / endpoint |
|---|---|---:|---:|---|
| Agent families | Create and identify sessions for Hermes, Ekko, Claude Code, Codex, and Pi; preserve family/source in every session and message surface | Partial | Partial | `packages/server/src/modules/studio/contracts/agents/family.ts`; `packages/client/src/api/coding-agents.ts`; `ChatPanel.vue` |
| Coding-agent launch | Select scoped/global mode, provider protocol (`chat_completions`, `codex_responses`, `anthropic_messages`), provider, model, profile, workspace, and category | Partial | Partial | `/api/coding-agents/:id/runs`; `ChatPanel.vue` |
| Socket run payload | Send `source`, `agent`, `coding_agent_id`, `coding_agent_mode`, API mode, workspace, category, push state, and queue ID | Partial | Partial | `packages/server/src/modules/studio/sockets/chat-run.ts` |
| Run stream | Render message/reasoning/tool deltas, failures, usage, terminal state, and workspace change cards for all runtimes | Partial | Partial | `/chat-run`; `MessageItem.vue`; `ToolRunCard.vue`; `ToolChangeCard.vue` |
| Resume | Use `app.resume` with cached message ID; restore messages, run state, tools, background tasks, queue, pending interactions, workspace changes, and push state | Partial | Partial | `chat-run.ts`; `resume-payload.ts` |
| Approvals | Render approval prompt and supplied choices inline and emit `approval.respond`; restore it after reconnect | Partial | Partial | `approval.requested`, `approval.respond`, `approval.resolved`; `PendingInteractionCountdown.vue` |
| Clarifications | Render question/options or text input inline and emit `clarify.respond`; restore it after reconnect | Partial | Broken | `clarify.requested`, `clarify.respond`, `clarify.resolved` |
| Queue | Show queued messages, queue length, insertion state; support insert-next and cancel | Missing | Missing | `run.queued`, `insert_queued_run`, `cancel_queued_run`; `MessageQueueFloatPanel.vue` |
| Subagents | Show background/delegated agents, runtime/status/output, and resumed state | Missing | Missing | `subagent.*`; `SubagentStreamPanel.vue`; `ConversationMonitorPane.vue` |
| Canonical APIs | Prefer v0.7.12 `/api/studio/**`; use legacy `/api/hermes/**` aliases only as compatibility fallback | Partial | Partial | `packages/server/src/modules/studio/middleware/legacy-app-api.ts` |

## P1 — Primary Studio organization

| Area | Acceptance requirement | Android | iOS | Upstream source / endpoint |
|---|---|---:|---:|---|
| Agent Manager | Status cards for Hermes, Ekko, Claude Code, Codex, Pi; install/update/remove; errors and versions | Partial | Partial | `AgentManagerView.vue`; `/api/agents/status`; `/api/coding-agents/**` |
| Hermes runtime manager | Inspect/download/select/delete Hermes runtime and Web UI versions; restart Web UI | Partial | Partial | `/api/hermes/runtime-versions/**`; `VersionManagementModal.vue` |
| Native coding launch | Expose prepare/native-launch status remotely; do not attempt to run desktop CLI on phone | Desktop-only/remote surface | Desktop-only/remote surface | `/api/coding-agents/:id/launch/{prepare,native}` |
| Session categories | List/create/rename/delete categories; assign/remove category; grouped and collapsed lists | Partial | Partial | `/api/studio/session-categories/**`; `session-category-groups.ts` |
| Search/history | Full-text search, archive/unarchive, archived history, pagination, batch delete | Partial | Partial | `/api/studio/{search/sessions,sessions/search,sessions/**}`; `HistoryView.vue` |
| Session metadata | Set workspace, model, reasoning effort, push notifications, category; copy ID/link | Partial | Partial | `/api/studio/sessions/:id/{workspace,model,reasoning-effort,push-enabled,category}` |
| Import/export | Export a Studio session; browse/import Hermes CLI sessions and groups | Missing | Missing | `/api/studio/sessions/:id/export`; `/sessions/hermes/**` |
| Workspace selection | Folder picker, create/rename/delete folder, pinned defaults and recent workspaces | Missing | Missing | `/api/studio/workspace/folders/**`; `FolderPicker.vue` |
| Workspace changes | List run changes and view individual file diffs | Missing | Missing | `/api/studio/sessions/:id/workspace-run-changes/**` |
| Workflow definitions | List/create/edit/delete/batch-delete, graph nodes/edges, import preview/confirm/cancel, export | Partial | Partial | `WorkflowView.vue`; `/api/studio/workflows/**` |
| Workflow execution | Start/stop/delete run, list/detail, node approval, rerun from node, live status | Partial | Partial | `/api/studio/workflows/:id/runs/**`; socket `/workflow` |
| Workflow schedules | Create/edit/delete schedules and show next execution | Missing | Missing | `/api/studio/workflows/:id/schedules/**` |
| Group rooms | Create/delete and chat with agents | Partial | Partial | `/api/studio/group-chat/rooms/**`; socket `/group-chat` |
| Group administration | Clone; add/update/remove agents; remove members; config; clear context; invite code; summary | Missing | Missing | `packages/server/src/modules/studio/routes/group-chat.ts` |
| Group handoffs | Show/continue handoffs, depth and agent-run state; mention routing | Missing | Missing | `/rooms/:roomId/handoffs/**`; `GroupAgentRunCard.vue` |
| Group files | Attachments/chunked upload/read plus room workspace list/read/write/diff/rename/copy/delete/mkdir | Missing | Missing | `/rooms/:roomId/{attachments,attachment-uploads,workspace-file*}` |
| Group agent links | Pair local/remote agents, approve requests, aliases, policies, disconnect/leave/revoke | Missing | Missing | `/api/studio/group-chat-link/v1/**`; agent-link endpoints |
| Shared groups | Resolve/join invites and support standalone shared group chat | Missing | Missing | `/share/group-chat`; `/rooms/join/:code`; invite APIs |

## P2 — Configuration and power features

| Area | Acceptance requirement | Android | iOS | Upstream source / endpoint |
|---|---|---:|---:|---|
| Providers | Provider-pool CRUD; editor; connection test; model refresh/restore; API mode/context mapping | Partial | Partial | `components/hermes/models/Provider*.vue`; `/api/hermes/config/providers/**` |
| Model catalog | Refresh cache; aliases; visibility; custom models; per-model context lengths | Partial | Partial | `/api/hermes/{provider-models,config/models,model-alias,model-visibility,custom-model,model-context}` |
| Model orchestration | Auxiliary models, delegation model, fallback provider chain, MoA/combination models | Missing | Missing | `/api/hermes/config/{auxiliary-models,delegation-model,fallback-providers,moa}` |
| Provider authentication | Anthropic, Codex, Copilot, MiniMax, Nous, and xAI login/device-code status flows | Missing | Missing | `/api/hermes/auth/**`; `components/hermes/models/*LoginModal.vue` |
| Profiles | Create/rename/delete/select and gateway restart | Partial | Partial | `/api/hermes/profiles/**` |
| Profile lifecycle | Runtime statuses, profile-runtime restart, avatar, active switch, export/import | Partial | Partial | `/api/hermes/profiles/{runtime-statuses,*}` |
| Hermes skills | List/detail/edit/delete/import/toggle/pin | Complete | Complete | `/api/hermes/skills/**` |
| Skill files/sources | Browse skill files, external directories, source legend | Partial | Partial | `/api/hermes/skills/{external-dirs,*/*/files}` |
| Skill bundles | Create/list/delete slash-command bundles | Missing | Missing | `/api/hermes/bundles/**`; `BundleCreateModal.vue` |
| Write gate | Generic subsystem inbox, diff viewer, approve/reject; not skills-only | Partial | Partial | `/api/hermes/write-gate/pending/**`; `PendingWriteApprovals.vue` |
| Plugins | List and enable/disable installed Hermes plugins | Complete | Complete | `/api/hermes/plugins/**` |
| Hermes memory | View and update actual memory, not only configuration toggles | Partial | Partial | `/api/hermes/memory`; `views/hermes/MemoryView.vue` |
| Hermes MCP | CRUD/test/reload servers and inspect tool inventory | Partial | Partial | `/api/hermes/mcp/{servers,tools,reload}` |
| Ekko config | Configure built-in Ekko runtime/provider behavior | Partial | Partial | `/api/ekko/config`; `views/ekko/SettingsView.vue` |
| Ekko memory | List/edit/delete Ekko memory records | Partial | Partial | `/api/ekko/memory/**` |
| Ekko skills | CRUD/files/import/external directories/toggle | Partial | Partial | `/api/ekko/skills/**` |
| Ekko MCP | CRUD/test Ekko MCP servers | Partial | Partial | `/api/ekko/mcp/servers/**` |
| Global Agent | Sessions, live socket state, voice/runtime state, and remote controls | Partial | Partial | `GlobalAgentView.vue`; `packages/server/src/modules/studio/sockets/global-agent.ts` |
| Kanban basics | Boards, columns/tasks, create/move/assign/comment | Partial | Partial | `KanbanView.vue`; `/api/hermes/kanban/**` |
| Kanban full lifecycle | Board CRUD, stats/diagnostics, dispatch, artifact, links, attachments, log, complete/block/unblock/reclaim/reassign/specify | Partial | Partial | `packages/server/src/modules/hermes/routes/kanban.ts` |
| Kanban realtime | Apply board/task updates from the Kanban socket | Missing | Missing | `packages/server/src/modules/hermes/sockets/kanban-events.ts` |
| Journey | Touch-friendly zoom/pan graph and accessible structured fallback | Partial | Partial | `JourneyView.vue`; `/api/hermes/journey` |
| App connections | LAN/cloud QR authorization, list/status/delete and revocation handling | Partial | Partial | `docs/app-relay.md`; `/api/app-connections/**` |
| App relay | Connect/disconnect, route selection, pairing-code refresh, presence | Missing | Missing | `/api/app-relay/**` |
| Studio devices | Pairing/requests/approval/blocking and peer connection management | Partial | Partial | `packages/server/src/modules/studio/routes/devices.ts` |
| Remote terminal/files | Open/read/input/resize/close terminal; exec/download/upload through connected desktop | Desktop-only/remote surface | Desktop-only/remote surface | `/api/devices/peer-connections/**` |
| MCU devices | List/create/edit/delete and remote connect/disconnect | Missing | Missing | `/api/mcu-devices/**` |

## P3 — Completeness and secondary surfaces

| Area | Acceptance requirement | Android | iOS | Upstream source / endpoint |
|---|---|---:|---:|---|
| Jobs | List/create/edit/delete, pause/resume/run, delivery targets, run history/detail | Complete | Partial | `/api/hermes/jobs/**`; `/api/cron-history/**`; `components/hermes/jobs/*` |
| Channels | Full native platform configuration and credential lifecycle | Partial | Partial | `ChannelsView.vue`; Hermes config/Weixin APIs |
| Social messaging | Platforms, active/locale, credentials, recipient lists, send; Telegram/Weixin/Feishu onboarding | Missing | Missing | `/api/social-messages/**`; `SocialMessagesView.vue` |
| Usage | Totals, cost, daily trend, model breakdown, agent/family breakdown, session usage | Partial | Partial | `UsageView.vue`; `components/hermes/usage/*`; session usage APIs |
| Skill usage | Skill invocation statistics and breakdown | Partial | Partial | `/api/hermes/skills/usage/stats`; `SkillsUsageView.vue` |
| Performance | Full runtime/process metrics | Partial | Partial | `/api/studio/performance/runtime`; `PerformanceView.vue` |
| Logs | List/read Studio logs | Complete | Complete | `/api/studio/logs/**`; `LogsView.vue` |
| Files | Standalone browse/stat/read/edit/upload/rename/mkdir/copy/delete/download | Partial | Partial | `/api/studio/files/**`; `FilesView.vue` |
| Rich previews | Image/text/HTML/PDF/DOCX/PPTX/XLSX preview and workspace/git diff | Missing | Missing | `components/hermes/files/*Preview.vue`; `Workspace*Diff.vue` |
| Browser tool | Show and remotely control server/desktop browser sessions where available | Desktop-only/remote surface | Desktop-only/remote surface | `DesktopBrowserPanel.vue`; `DesktopBrowserView.vue` |
| Voice input | One-shot record/transcribe into editable draft | Complete | Complete | `/api/studio/stt/transcribe`; `docs/voice-dialogue.md` |
| Voice output | TTS reply with content-type/format handling and playback cancellation | Complete | Complete | `/api/studio/tts/synthesize` |
| Voice provider settings | Provider catalog, active provider, per-provider settings/secrets, probe, native-vs-Studio status | Partial | Partial | `/api/studio/{stt,tts}/settings/**`; `/api/voice/providers/probe` |
| Local STT | Model status/download and streaming capture lifecycle | Missing | Missing | `/api/studio/stt/{local-model,local-stream/**}` |
| Theme | Palette, component theme, background upload/cache/remove | Partial | Partial | `/api/theme/**`; `ThemeView.vue` |
| Studio settings | Agent, memory, compression, session reset, approvals, skills, privacy, proxy, gateway, display | Partial | Partial | `components/hermes/settings/*` |
| Webhooks | CRUD/test endpoints and local test target/events | Partial | Complete | `/api/studio/webhooks/**`; `WebhookSettings.vue` |
| Account | Login/me, username/password/avatar | Complete | Complete | `/api/auth/**` |
| User administration | Setup/remove password, managed-user CRUD and locked-IP management | Partial | Partial | `/api/auth/{setup,password,users,locked-ips}` |
| Studio update | Trigger server update and manage preview tags/install/start/stop | Missing | Missing | `/api/studio/update/**`; `VersionPreviewView.vue` |
| Mobile update | Discover and install the mobile application update | Complete | Platform-managed | Mobile repository updater |
| API docs | Expose/view current OpenAPI document for diagnostics | Missing | Missing | `/api/openapi.json` |

## Desktop-only boundaries

The phone should not install or directly execute Hermes, Claude Code, Codex, or Pi; host desktop terminals; run an Electron browser; manage local OS process trees; or render the desktop pet. It should expose authenticated remote status and controls for those capabilities whenever v0.7.12 provides an API/socket contract. Workflow canvas and rich office previews should receive phone-friendly list/detail fallbacks, while tablets may use the full visual editor.

## Independent audit findings at 2d3396f

### P0 defects

1. **iOS clarification responses are rejected silently.** `SocketIO.swift` emits `clarification_id` and `answer`, while v0.7.12 requires `clarify_id` and `response`. Android uses the correct keys.
2. **Resume is not App Relay resume.** Both clients emit `resume`; neither emits `app.resume` with the last cached message ID. They therefore do not receive the App-specific incremental page contract and can miss or duplicate messages after suspension.
3. **Resume state is discarded.** Neither socket restores pending approvals/clarifications, queue messages/insertion, subagent/background tasks, workspace changes, push state, API mode, or session category from the resumed payload.
4. **No queue protocol.** Neither client listens to `run.queued` or emits `insert_queued_run` / `cancel_queued_run`.
5. **No subagent protocol.** Neither client listens to `subagent.*` events or renders background/delegated work.
6. **Run launch is incomplete.** Runtime selectors identify the five agents, but mobile does not expose and persist the complete scoped/global choice, protocol/API mode, base URL/key, workspace, category, or push fields. Android marks every non-Hermes socket run as `mode=global`; iOS marks every ordinary coding run as `mode=scoped`. This is behavior, not merely missing UI.
7. **Global Agent is a shortcut, not parity.** Both Global Agent screens open a normal chat path; neither implements the dedicated `/global-agent` socket lifecycle, MCU/global status, controls, session list behavior, or voice state.
8. **Approvals/clarifications are only turn-local.** Basic inline prompts exist, but resolved events, timeout/countdown, initial responses/modes, global pending actions, and reconnect restoration are absent.

### P1 defects

1. **Workflow editor parity is largely absent.** Mobile can list workflows and inspect/start/stop/delete runs and approve a node. It cannot create/edit/delete definitions, edit nodes/edges, validate graphs, import/export, batch-delete, rerun from node, manage schedules, or subscribe to `/workflow`; refresh is manual polling.
2. **Session management remains partial.** Android cannot rename/delete categories; neither app provides paginated archived history, batch delete, session export, Hermes CLI history import/groups, session workspace picker, workspace defaults/recents, per-session push/reasoning controls, or workspace-run diffs.
3. **Search is not full parity.** The UI mixes local filtering and limited endpoint search and does not expose the upstream history grouping/pagination behavior.
4. **Groups received no v0.7.12 expansion.** Room CRUD/chat/add-agent remain, while cloning, member/agent administration, configuration, summaries, invites, attachments/chunking, workspace files, handoffs, mentions, guest policies, presets, and local/remote agent linking are absent.
5. **Agent Manager is a reduced card list.** It covers coding-agent status/install/update/remove, but not config-file read/write, launch prepare/native status, scoped configuration details, complete Hermes source/runtime diagnostics, or AI-help behavior.

### P2/P3 defects

1. **Providers/models are still shallow.** The new screens do not implement the complete provider editor/test/contexts, refresh/restore, model alias/visibility/custom/context CRUD, auxiliary/delegation/fallback/MoA panels, or full start/poll/submit OAuth/device flows.
2. **Profiles are partial.** Export/import/avatar/active switching were added, but runtime status presentation/restart semantics and archive error/progress handling do not match Studio.
3. **Hermes capabilities are incomplete.** Skill file browsing/external directories/source metadata and bundles are absent; write-gate remains skills-only without diff; MCP tool inventory is absent; memory is a reduced text/control surface.
4. **Ekko is a reduced implementation.** Basic config/memory/skills/MCP endpoints exist, but several create/edit/toggle/file/external-directory/test flows are absent or exposed only as raw/simple forms rather than the complete Studio contracts.
5. **Kanban remains partial.** Stats, diagnostics, logs and several actions were added, but board CRUD, capabilities, artifact, session links/search, attachment retrieval UI, reclaim and specify are incomplete; no Kanban socket updates exist.
6. **Journey is capped/static.** Android is a structured list. iOS draws only the first 36 nodes in a fixed radial canvas with no zoom or pan. Both are valid fallbacks, not full graph parity.
7. **Connections are partial.** QR authorization/list/revoke and some relay/device data exist, but QR rendering/expiry-refresh lifecycle, formal claim/revocation state, app presence, all device request/peer actions, remote terminal/file transfer, and MCU management are incomplete.
8. **Files are basic.** Browse/read/write/upload/rename/copy/delete exist; stat, authenticated canonical download consistency, rich PDF/DOCX/PPTX/XLSX/HTML previews, workspace/git diffs, and large-file behavior are missing.
9. **Voice management remains partial.** One-shot STT/TTS works, but the v0.7.12 provider catalog/editor/secrets/probe/native-vs-Studio status, local model download, streaming STT, and voice-dialogue stage are not implemented.
10. **Secondary gaps remain:** social messaging, App Relay completeness, MCU devices, local STT, rich previews, Studio update preview, API-doc viewer, complete usage/agent breakdown, complete performance metrics, and skill bundles.
11. **Pets code is still present on both platforms.** Navigation is hidden, but screens, API calls, models and Android state-loading remain, contrary to the accepted mobile scope.

### Route and payload risks

- Canonical session/files/usage routes were introduced, but many calls still directly rely on legacy `/api/hermes/**` aliases without capability negotiation. This is acceptable only for genuinely Hermes-owned modules; sessions, group chat, STT/TTS, performance and downloads should use their canonical Studio routes with an explicit old-server fallback.
- Android and iOS use the compatibility session endpoint differently and construct different runtime payloads, increasing cross-platform session identity drift.
- The mobile workflow node approval UI may send only the first pending node on Android; neither platform exposes the exact run detail and rerun contract needed to disambiguate repeated node executions robustly.
- Auth tokens are appended to some preview/download URLs. Prefer authenticated request headers or a controlled one-time download mechanism where the receiving viewer supports it, to reduce token leakage through URL logs/history.

### Compile, navigation, localization, and test risks

- **Android is currently unbuildable.** CI run `33340396613` failed at Kotlin compilation with invalid `weight` imports, a syntax error in `HermesApi.kt`, missing `action_send`, unresolved Material icons, and parse/unresolved-symbol errors in `StudioWorkspaceScreens.kt`. No later Android run had validated `2d3396f` at audit time.
- **iOS is currently unbuildable.** The combined run `33340396612` failed in `APIClient.swift` and `Models.swift`. After the attempted fixes, replacement run `33340468556` still failed at `Models.swift:460`: `json.int("useCount", "use_count")` calls an overload requiring `default:` and passes a string where an integer is expected.
- Large single-line SwiftUI and Compose screens contain many nested generic/view-builder expressions. They are compile-time/type-check risk hotspots and are difficult to test independently.
- Most new screens are reachable through Agent/More Settings, but several implemented API helpers have no complete navigation surface; hidden Pets routes remain compiled.
- English and Arabic resource key inventories are broadly present, but many Android and iOS values are assembled from raw server identifiers or hard-coded English strings. Locale presence alone does not prove Arabic translation or RTL correctness.
- Existing tests do not provide endpoint-contract fixtures for the newly added workflows, runtime versions, files, webhooks, theme, Journey, Ekko, devices, or App Relay surfaces. There are no protocol tests proving resume, approval, clarification, queue, subagent, or cross-platform runtime payload parity.

## Obsolete mobile code

- Remove inactive Pets/Petdex screens, models, state, and API calls from mobile. Hermes Studio retains a desktop pet, but it is outside this product's requested mobile information architecture.
- Replace direct reliance on legacy App aliases such as `/api/hermes/sessions`, `/api/hermes/group-chat`, `/api/hermes/stt`, `/api/hermes/tts`, and `/api/chat-run/runs` with canonical `/api/studio/**` calls. A negotiated fallback may remain for older Studio installations.
- Replace the current “approve in Studio” and “clarify in Studio” text-only behavior with the real socket interaction contract.

## Independent review gates

- [ ] Every `P0` row is `Complete` on Android and iOS.
- [ ] Every non-desktop `P1` row is `Complete` on Android and iOS.
- [ ] Every `P2`/`P3` row is either `Complete` or has a documented, approved mobile adaptation.
- [ ] Android and iOS expose the same feature set, terminology, state transitions, and error behavior.
- [ ] Both clients work with v0.7.12 canonical endpoints and retain explicitly tested fallback compatibility where required.
- [ ] Socket reconnection restores an active run, pending approval/clarification, queued messages, subagents, and messages received while backgrounded.
- [ ] Agent-family sessions remain correctly identified after relaunch and never silently fall back to Hermes.
- [ ] Destructive actions have confirmation and permission-aware error handling.
- [ ] Arabic and English strings exist for every new user-facing label; RTL layouts are verified.
- [ ] Android and iOS builds/tests pass, and an independent reviewer checks this document against v0.7.12 source and both apps.
