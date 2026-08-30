# Hermes Studio v0.7.12 Mobile Parity

This document is the acceptance checklist for matching Hermes Studio v0.7.12 on Android and iOS. Statuses describe the mobile code before the v0.7.12 parity work began.

Status legend: `Complete`, `Partial`, `Missing`, `Desktop-only/remote surface`.

## P0 — Core runtime and conversation correctness

| Area | Acceptance requirement | Android | iOS | Upstream source / endpoint |
|---|---|---:|---:|---|
| Agent families | Create and identify sessions for Hermes, Ekko, Claude Code, Codex, and Pi; preserve family/source in every session and message surface | Missing | Missing | `packages/server/src/modules/studio/contracts/agents/family.ts`; `packages/client/src/api/coding-agents.ts`; `ChatPanel.vue` |
| Coding-agent launch | Select scoped/global mode, provider protocol (`chat_completions`, `codex_responses`, `anthropic_messages`), provider, model, profile, workspace, and category | Missing | Missing | `/api/coding-agents/:id/runs`; `ChatPanel.vue` |
| Socket run payload | Send `source`, `agent`, `coding_agent_id`, `coding_agent_mode`, API mode, workspace, category, push state, and queue ID | Missing | Missing | `packages/server/src/modules/studio/sockets/chat-run.ts` |
| Run stream | Render message/reasoning/tool deltas, failures, usage, terminal state, and workspace change cards for all runtimes | Partial | Partial | `/chat-run`; `MessageItem.vue`; `ToolRunCard.vue`; `ToolChangeCard.vue` |
| Resume | Use `app.resume` with cached message ID; restore messages, run state, tools, background tasks, queue, pending interactions, workspace changes, and push state | Partial | Partial | `chat-run.ts`; `resume-payload.ts` |
| Approvals | Render approval prompt and supplied choices inline and emit `approval.respond`; restore it after reconnect | Missing | Missing | `approval.requested`, `approval.respond`, `approval.resolved`; `PendingInteractionCountdown.vue` |
| Clarifications | Render question/options or text input inline and emit `clarify.respond`; restore it after reconnect | Missing | Missing | `clarify.requested`, `clarify.respond`, `clarify.resolved` |
| Queue | Show queued messages, queue length, insertion state; support insert-next and cancel | Missing | Missing | `run.queued`, `insert_queued_run`, `cancel_queued_run`; `MessageQueueFloatPanel.vue` |
| Subagents | Show background/delegated agents, runtime/status/output, and resumed state | Missing | Missing | `subagent.*`; `SubagentStreamPanel.vue`; `ConversationMonitorPane.vue` |
| Canonical APIs | Prefer v0.7.12 `/api/studio/**`; use legacy `/api/hermes/**` aliases only as compatibility fallback | Missing | Missing | `packages/server/src/modules/studio/middleware/legacy-app-api.ts` |

## P1 — Primary Studio organization

| Area | Acceptance requirement | Android | iOS | Upstream source / endpoint |
|---|---|---:|---:|---|
| Agent Manager | Status cards for Hermes, Ekko, Claude Code, Codex, Pi; install/update/remove; errors and versions | Missing | Missing | `AgentManagerView.vue`; `/api/agents/status`; `/api/coding-agents/**` |
| Hermes runtime manager | Inspect/download/select/delete Hermes runtime and Web UI versions; restart Web UI | Missing | Missing | `/api/hermes/runtime-versions/**`; `VersionManagementModal.vue` |
| Native coding launch | Expose prepare/native-launch status remotely; do not attempt to run desktop CLI on phone | Desktop-only/remote surface | Desktop-only/remote surface | `/api/coding-agents/:id/launch/{prepare,native}` |
| Session categories | List/create/rename/delete categories; assign/remove category; grouped and collapsed lists | Missing | Missing | `/api/studio/session-categories/**`; `session-category-groups.ts` |
| Search/history | Full-text search, archive/unarchive, archived history, pagination, batch delete | Missing | Missing | `/api/studio/{search/sessions,sessions/search,sessions/**}`; `HistoryView.vue` |
| Session metadata | Set workspace, model, reasoning effort, push notifications, category; copy ID/link | Partial | Partial | `/api/studio/sessions/:id/{workspace,model,reasoning-effort,push-enabled,category}` |
| Import/export | Export a Studio session; browse/import Hermes CLI sessions and groups | Missing | Missing | `/api/studio/sessions/:id/export`; `/sessions/hermes/**` |
| Workspace selection | Folder picker, create/rename/delete folder, pinned defaults and recent workspaces | Missing | Missing | `/api/studio/workspace/folders/**`; `FolderPicker.vue` |
| Workspace changes | List run changes and view individual file diffs | Missing | Missing | `/api/studio/sessions/:id/workspace-run-changes/**` |
| Workflow definitions | List/create/edit/delete/batch-delete, graph nodes/edges, import preview/confirm/cancel, export | Missing | Missing | `WorkflowView.vue`; `/api/studio/workflows/**` |
| Workflow execution | Start/stop/delete run, list/detail, node approval, rerun from node, live status | Missing | Missing | `/api/studio/workflows/:id/runs/**`; socket `/workflow` |
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
| Profile lifecycle | Runtime statuses, profile-runtime restart, avatar, active switch, export/import | Missing | Missing | `/api/hermes/profiles/{runtime-statuses,*}` |
| Hermes skills | List/detail/edit/delete/import/toggle/pin | Complete | Complete | `/api/hermes/skills/**` |
| Skill files/sources | Browse skill files, external directories, source legend | Missing | Missing | `/api/hermes/skills/{external-dirs,*/*/files}` |
| Skill bundles | Create/list/delete slash-command bundles | Missing | Missing | `/api/hermes/bundles/**`; `BundleCreateModal.vue` |
| Write gate | Generic subsystem inbox, diff viewer, approve/reject; not skills-only | Partial | Partial | `/api/hermes/write-gate/pending/**`; `PendingWriteApprovals.vue` |
| Plugins | List and enable/disable installed Hermes plugins | Complete | Complete | `/api/hermes/plugins/**` |
| Hermes memory | View and update actual memory, not only configuration toggles | Missing | Missing | `/api/hermes/memory`; `views/hermes/MemoryView.vue` |
| Hermes MCP | CRUD/test/reload servers and inspect tool inventory | Partial | Partial | `/api/hermes/mcp/{servers,tools,reload}` |
| Ekko config | Configure built-in Ekko runtime/provider behavior | Missing | Missing | `/api/ekko/config`; `views/ekko/SettingsView.vue` |
| Ekko memory | List/edit/delete Ekko memory records | Missing | Missing | `/api/ekko/memory/**` |
| Ekko skills | CRUD/files/import/external directories/toggle | Missing | Missing | `/api/ekko/skills/**` |
| Ekko MCP | CRUD/test Ekko MCP servers | Missing | Missing | `/api/ekko/mcp/servers/**` |
| Global Agent | Sessions, live socket state, voice/runtime state, and remote controls | Missing | Missing | `GlobalAgentView.vue`; `packages/server/src/modules/studio/sockets/global-agent.ts` |
| Kanban basics | Boards, columns/tasks, create/move/assign/comment | Partial | Partial | `KanbanView.vue`; `/api/hermes/kanban/**` |
| Kanban full lifecycle | Board CRUD, stats/diagnostics, dispatch, artifact, links, attachments, log, complete/block/unblock/reclaim/reassign/specify | Missing | Missing | `packages/server/src/modules/hermes/routes/kanban.ts` |
| Kanban realtime | Apply board/task updates from the Kanban socket | Missing | Missing | `packages/server/src/modules/hermes/sockets/kanban-events.ts` |
| Journey | Touch-friendly zoom/pan graph and accessible structured fallback | Missing | Missing | `JourneyView.vue`; `/api/hermes/journey` |
| App connections | LAN/cloud QR authorization, list/status/delete and revocation handling | Missing | Missing | `docs/app-relay.md`; `/api/app-connections/**` |
| App relay | Connect/disconnect, route selection, pairing-code refresh, presence | Missing | Missing | `/api/app-relay/**` |
| Studio devices | Pairing/requests/approval/blocking and peer connection management | Missing | Missing | `packages/server/src/modules/studio/routes/devices.ts` |
| Remote terminal/files | Open/read/input/resize/close terminal; exec/download/upload through connected desktop | Desktop-only/remote surface | Desktop-only/remote surface | `/api/devices/peer-connections/**` |
| MCU devices | List/create/edit/delete and remote connect/disconnect | Missing | Missing | `/api/mcu-devices/**` |

## P3 — Completeness and secondary surfaces

| Area | Acceptance requirement | Android | iOS | Upstream source / endpoint |
|---|---|---:|---:|---|
| Jobs | List/create/edit/delete, pause/resume/run, delivery targets, run history/detail | Complete | Partial | `/api/hermes/jobs/**`; `/api/cron-history/**`; `components/hermes/jobs/*` |
| Channels | Full native platform configuration and credential lifecycle | Partial | Partial | `ChannelsView.vue`; Hermes config/Weixin APIs |
| Social messaging | Platforms, active/locale, credentials, recipient lists, send; Telegram/Weixin/Feishu onboarding | Missing | Missing | `/api/social-messages/**`; `SocialMessagesView.vue` |
| Usage | Totals, cost, daily trend, model breakdown, agent/family breakdown, session usage | Partial | Partial | `UsageView.vue`; `components/hermes/usage/*`; session usage APIs |
| Skill usage | Skill invocation statistics and breakdown | Missing | Missing | `/api/hermes/skills/usage/stats`; `SkillsUsageView.vue` |
| Performance | Full runtime/process metrics | Partial | Partial | `/api/studio/performance/runtime`; `PerformanceView.vue` |
| Logs | List/read Studio logs | Missing | Missing | `/api/studio/logs/**`; `LogsView.vue` |
| Files | Standalone browse/stat/read/edit/upload/rename/mkdir/copy/delete/download | Missing | Missing | `/api/studio/files/**`; `FilesView.vue` |
| Rich previews | Image/text/HTML/PDF/DOCX/PPTX/XLSX preview and workspace/git diff | Missing | Missing | `components/hermes/files/*Preview.vue`; `Workspace*Diff.vue` |
| Browser tool | Show and remotely control server/desktop browser sessions where available | Desktop-only/remote surface | Desktop-only/remote surface | `DesktopBrowserPanel.vue`; `DesktopBrowserView.vue` |
| Voice input | One-shot record/transcribe into editable draft | Complete | Complete | `/api/studio/stt/transcribe`; `docs/voice-dialogue.md` |
| Voice output | TTS reply with content-type/format handling and playback cancellation | Complete | Complete | `/api/studio/tts/synthesize` |
| Voice provider settings | Provider catalog, active provider, per-provider settings/secrets, probe, native-vs-Studio status | Partial | Partial | `/api/studio/{stt,tts}/settings/**`; `/api/voice/providers/probe` |
| Local STT | Model status/download and streaming capture lifecycle | Missing | Missing | `/api/studio/stt/{local-model,local-stream/**}` |
| Theme | Palette, component theme, background upload/cache/remove | Missing | Missing | `/api/theme/**`; `ThemeView.vue` |
| Studio settings | Agent, memory, compression, session reset, approvals, skills, privacy, proxy, gateway, display | Partial | Partial | `components/hermes/settings/*` |
| Webhooks | CRUD/test endpoints and local test target/events | Missing | Missing | `/api/studio/webhooks/**`; `WebhookSettings.vue` |
| Account | Login/me, username/password/avatar | Complete | Complete | `/api/auth/**` |
| User administration | Setup/remove password, managed-user CRUD and locked-IP management | Partial | Missing | `/api/auth/{setup,password,users,locked-ips}` |
| Studio update | Trigger server update and manage preview tags/install/start/stop | Missing | Missing | `/api/studio/update/**`; `VersionPreviewView.vue` |
| Mobile update | Discover and install the mobile application update | Complete | Platform-managed | Mobile repository updater |
| API docs | Expose/view current OpenAPI document for diagnostics | Missing | Missing | `/api/openapi.json` |

## Desktop-only boundaries

The phone should not install or directly execute Hermes, Claude Code, Codex, or Pi; host desktop terminals; run an Electron browser; manage local OS process trees; or render the desktop pet. It should expose authenticated remote status and controls for those capabilities whenever v0.7.12 provides an API/socket contract. Workflow canvas and rich office previews should receive phone-friendly list/detail fallbacks, while tablets may use the full visual editor.

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
