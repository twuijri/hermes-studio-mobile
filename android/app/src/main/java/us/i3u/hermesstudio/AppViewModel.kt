package us.i3u.hermesstudio

import android.app.Application
import android.app.DownloadManager
import android.net.Uri
import android.media.MediaPlayer
import android.os.Environment
import android.webkit.MimeTypeMap
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

enum class Screen {
    Loading, Onboarding, Login, Chats, Groups, AgentHub, Conversation, Room, Profiles,
    Settings, MoreSettings, SettingsGroup, Channels, Channel, CronJobs, CronJob, CronHistory,
    Kanban, KanbanTask, Skills, Skill, Plugins, Mcp, Pets, Insights, AgentRuntimes, Workflows, GlobalAgent, EkkoHub, Files, Logs, Connections, Journey, Webhooks, RuntimeVersions, Appearance,
}

/** Settings is a short list of these; each opens its own screen. */
enum class SettingsGroup {
    Account, Server, Users, Profile, Models, Agent, Memory, Compression, Sessions,
    Privacy, Proxy, Display, Device, About,
}

/** The app's three root destinations. Agent tools live outside Settings. */
enum class Tab { Chats, Groups, Agent }

private data class SessionBootstrap(
    val user: CurrentUser,
    val profiles: List<Profile>,
    val sessions: List<SessionSummary>,
)

private data class AccountSettingsData(
    val user: CurrentUser,
    val locks: List<LockedIp>,
    val avatar: AvatarSpec,
)

data class ChatLine(
    val text: String,
    val fromUser: Boolean,
    val isError: Boolean = false,
    val timestamp: String? = null,
    val sender: String? = null,
    /** What the model thought on the way to this answer, when it reports it. */
    val reasoning: String? = null,
    /** True while the words are still arriving. */
    val streaming: Boolean = false,
    /** Tool calls reported by Studio while this reply is being produced. */
    val tools: List<ChatToolStep> = emptyList(),
    /** Local timing keeps the live Thinking counter moving between events. */
    val startedAtMillis: Long? = null,
    val finishedAtMillis: Long? = null,
    val messageId: String? = null,
)

data class ChatToolStep(
    val id: String,
    val name: String,
    val detail: String?,
    val status: ToolRunStatus,
    val startedAtMillis: Long,
    val durationSeconds: Double? = null,
)

data class PendingRunAction(
    val kind: RequiredAction,
    val id: String,
    val prompt: String,
    val options: List<String>,
    val sessionId: String,
)

data class UiState(
    val screen: Screen = Screen.Login,
    val tab: Tab = Tab.Chats,
    val baseUrl: String = "",
    val busy: Boolean = false,
    val error: String? = null,
    val account: String? = null,
    val currentUser: CurrentUser? = null,
    val profiles: List<Profile> = emptyList(),
    /** Blank means "All profiles", the same default Studio shows. */
    val profileFilter: String = "",
    val activeProfile: String = "",
    val sessions: List<SessionSummary> = emptyList(),
    /** Drives both the toolbar refresh and the pull-to-refresh indicator. */
    val refreshingSessions: Boolean = false,
    val rooms: List<Room> = emptyList(),
    val openSession: SessionSummary? = null,
    val openRoom: RoomDetail? = null,
    val lines: List<ChatLine> = emptyList(),
    val loadingHistory: Boolean = false,
    val sending: Boolean = false,
    val attachments: List<Upload> = emptyList(),
    val attaching: Boolean = false,
    val recording: Boolean = false,
    val transcribing: Boolean = false,
    /** Text produced by the last recording, consumed by the composer. */
    val transcript: String? = null,
    /** The next submitted draft came from STT and should receive a spoken reply. */
    val voiceReplyPending: Boolean = false,
    val speaking: Boolean = false,
    val models: List<ModelOption> = emptyList(),
    /** Profile whose entries are currently in [models]. */
    val modelsProfile: String? = null,
    val loadingModels: Boolean = false,
    /** Blank means the profile default, matching Studio's "Default" chip. */
    val reasoningEffort: String = "",
    /** BCP-47 tag chosen in Settings; blank follows the system. */
    val language: String = "",
    /** system, light, or dark. */
    val appearance: String = "system",
    val sessionModel: String? = null,
    val sessionProvider: String? = null,
    val contextTokens: Long = 0,
    val contextWindow: Long = 0,
    val loadingContext: Boolean = false,
    val defaultModel: String? = null,
    val savingSetting: Boolean = false,
    /** The tool the agent is running right now, when it says so. */
    val activity: String? = null,
    /** True once the room socket is carrying messages. */
    val roomLive: Boolean = false,
    val serverConfig: ServerConfig? = null,
    /** The channel whose settings are open, if any. */
    val openChannel: String? = null,
    val weixinQr: WeixinQrUi = WeixinQrUi(),
    val openGroup: SettingsGroup? = null,
    /** Parent hub for a settings group, channel list, or scheduled-jobs list. */
    val toolReturnScreen: Screen = Screen.Settings,
    /** Exact screen that opened Profiles; it is shared by several root surfaces. */
    val profilesReturnScreen: Screen = Screen.Chats,
    val agentSettings: AgentSettings? = null,
    val autoStart: AutoStartPolicy? = null,
    val loadingAgentSettings: Boolean = false,
    val studioSettings: StudioSettings? = null,
    val loadingStudioSettings: Boolean = false,
    val lockedIps: List<LockedIp> = emptyList(),
    val accountAvatar: AvatarSpec? = null,
    val loadingAccountSettings: Boolean = false,
    val managedUsers: List<ManagedUser> = emptyList(),
    val managedProfiles: List<String> = emptyList(),
    val loadingManagedUsers: Boolean = false,
    val modelProviders: List<ModelProvider> = emptyList(),
    val loadingModelProviders: Boolean = false,
    val cronJobs: List<CronJob> = emptyList(),
    val cronLoading: Boolean = false,
    /** The job currently running a pause/resume/run/delete request. */
    val cronActionId: String? = null,
    val editingCronJob: CronJob? = null,
    val cronEditorJobId: String? = null,
    val cronEditorLoading: Boolean = false,
    val cronSkills: List<String> = emptyList(),
    val cronDeliveryTargets: List<CronDeliveryTarget> = emptyList(),
    val cronHistoryJob: CronJob? = null,
    val cronRuns: List<CronRun> = emptyList(),
    val cronHistoryLoading: Boolean = false,
    val cronRunLoading: Boolean = false,
    val openCronRun: CronRunDetail? = null,
    val kanban: KanbanUiState = KanbanUiState(),
    val skillsUi: SkillsUiState = SkillsUiState(),
    val pluginsUi: PluginsUiState = PluginsUiState(),
    val mcpUi: McpUiState = McpUiState(),
    val petsUi: PetsUiState = PetsUiState(),
    val usageStats: UsageStats? = null,
    val usageDays: Int = 30,
    val runtimePerformance: RuntimePerformance? = null,
    val loadingInsights: Boolean = false,
    val notice: String? = null,
    val agentRuntimes: List<AgentRuntimeStatus> = emptyList(),
    val loadingAgentRuntimes: Boolean = false,
    val selectedRuntime: AgentRuntimeSelection = AgentRuntimeSelection(),
    val pendingRunAction: PendingRunAction? = null,
    val queuedRuns: List<QueuedRun> = emptyList(),
    val queueInsertionActive: Boolean = false,
    val backgroundAgentRuns: List<BackgroundAgentRun> = emptyList(),
    val sessionCategories: List<SessionCategory> = emptyList(),
    val sessionSearchResults: List<SessionSummary>? = null,
    val workflows: List<StudioWorkflow> = emptyList(),
    val workflowRuns: Map<String, List<StudioWorkflowRun>> = emptyMap(),
    val loadingWorkflows: Boolean = false,
    val ekkoMemories: List<EkkoMemory> = emptyList(),
    val ekkoSkills: List<SkillCategory> = emptyList(),
    val ekkoMcpServers: List<EkkoMcpServer> = emptyList(),
    val loadingEkko: Boolean = false,
    val profileRuntimeStatuses: Map<String, String> = emptyMap(),
    val filesPath: String = "",
    val studioFiles: List<StudioFile> = emptyList(),
    val openFile: StudioFile? = null,
    val openFileContent: String = "",
    val studioLogs: List<StudioLogFile> = emptyList(),
    val openLog: StudioLogFile? = null,
    val logEntries: List<StudioLogEntry> = emptyList(),
    val appRelay: AppRelayStatus? = null,
    val studioDevices: List<StudioDevice> = emptyList(),
    val appConnections: List<AppConnection> = emptyList(),
    val appAuthorization: AppAuthorization? = null,
    val ekkoExternalDirectories: List<String> = emptyList(),
    val ekkoOpenSkill: SkillInfo? = null,
    val ekkoSkillContent: String = "",
    val ekkoSkillFiles: List<String> = emptyList(),
    val ekkoSkillFilePreviewPath: String? = null,
    val ekkoSkillFilePreviewContent: String = "",
    val pairingLink: String = "",
    val peerConnections: List<PeerConnection> = emptyList(),
    val journey: JourneyGraph? = null,
    val skillUsage: SkillUsage? = null,
    val webhooks: List<WebhookEndpoint> = emptyList(),
    val webhookEvents: List<String> = emptyList(),
    val runtimeVersions: RuntimeVersions? = null,
    val themeSettings: ThemeSettings? = null,
    val kanbanDiagnostics: List<String> = emptyList(),
    val kanbanStats: String = "",
    val kanbanLog: String = "",
    val kanbanAttachments: List<String> = emptyList(),
)

data class WeixinQrUi(
    val status: String = "idle",
    val id: String = "",
    val url: String = "",
)

class AppViewModel(app: Application) : AndroidViewModel(app) {

    private val store = Store(app)

    /** Resolves strings in the language chosen in Settings, not the phone's. */
    private val localized = AppLocale.wrap(app)
    private val api = HermesApi(store.baseUrl, store.token)
    private val chat = ChatSocket(store.baseUrl, store.token)
    private val group = GroupSocket(store.baseUrl, store.token)
    private val recorder = Recorder(app)
    private var speechPlayer: MediaPlayer? = null
    private var runJob: kotlinx.coroutines.Job? = null
    private var historyJob: kotlinx.coroutines.Job? = null
    private var roomJob: kotlinx.coroutines.Job? = null
    private var roomLoadJob: kotlinx.coroutines.Job? = null
    private var weixinQrJob: Job? = null
    private var openingRoomId: String? = null
    private var activeRunSessionId: String? = null
    private val queuedDownloadNames = mutableSetOf<String>()

    private val _state = MutableStateFlow(
        UiState(
            // A configured install must never flash the credentials form: it reads
            // as "sign in again" even though the token is still good.
            screen = when {
                store.isConfigured -> Screen.Loading
                store.onboarded -> Screen.Login
                else -> Screen.Onboarding
            },
            baseUrl = store.baseUrl,
            reasoningEffort = store.reasoningEffort,
            language = store.language,
            appearance = store.appearance,
        ),
    )
    val state: StateFlow<UiState> = _state.asStateFlow()

    init {
        // The cached mark is on disk, so the launch screen can show it at once.
        viewModelScope.launch { AppLogo.load(app) }
        if (store.isConfigured) restoreSession()
    }

    fun finishOnboarding() {
        store.onboarded = true
        _state.update { it.copy(screen = Screen.Login) }
    }

    private fun restoreSession() = launchWork(
        work = {
            api.update(store.baseUrl, store.token)
            chat.update(store.baseUrl, store.token)
            group.update(store.baseUrl, store.token)
            val user = api.currentUser()
            SessionBootstrap(user, api.profiles(), api.sessions(null))
        },
        onSuccess = { (user, profiles, sessions) ->
            _state.update {
                it.copy(
                    screen = Screen.Chats,
                    account = user.username,
                    currentUser = user,
                    profiles = profiles,
                    activeProfile = pickProfile(profiles),
                    sessions = sessions,
                    error = null,
                )
            }
            syncBranding()
        },
        onFailure = { failure ->
            if (failure.invalidatesSavedSession()) {
                store.clearCredentials()
                _state.update {
                    it.copy(
                        screen = Screen.Login,
                        error = str(R.string.error_session_expired, failure.readableMessage(localized)),
                    )
                }
            } else {
                // A timeout or an offline server does not invalidate a token.
                // Keep the launch screen and let the user retry in place.
                _state.update {
                    it.copy(
                        screen = Screen.Loading,
                        error = str(R.string.error_session_restore, failure.readableMessage(localized)),
                    )
                }
            }
        },
    )

    fun retrySession() {
        if (!store.isConfigured || _state.value.busy) return
        _state.update { it.copy(screen = Screen.Loading, error = null) }
        restoreSession()
    }

    fun login(baseUrl: String, username: String, password: String) {
        val normalized = normalizeUrl(baseUrl)
        if (normalized == null) {
            _state.update { it.copy(error = str(R.string.error_server_address)) }
            return
        }
        if (username.isBlank() || password.isBlank()) {
            _state.update { it.copy(error = str(R.string.error_credentials_required)) }
            return
        }

        launchWork(
            work = {
                api.update(normalized, "")
                val token = api.login(username.trim(), password)
                store.baseUrl = normalized
                store.token = token
                api.update(normalized, token)
                chat.update(normalized, token)
                group.update(normalized, token)
                val user = api.currentUser()
                SessionBootstrap(user, api.profiles(), api.sessions(null))
            },
            onSuccess = { (user, profiles, sessions) ->
                _state.update {
                    it.copy(
                        screen = Screen.Chats,
                        baseUrl = normalized,
                        account = user.username,
                        currentUser = user,
                        profiles = profiles,
                        activeProfile = pickProfile(profiles),
                        sessions = sessions,
                        error = null,
                    )
                }
                syncBranding()
            },
        )
    }

    /** Pulls the Studio logo from the connected server for the launch screen. */
    private fun syncBranding(force: Boolean = false) {
        viewModelScope.launch {
            runCatching { AppLogo.syncFromServer(getApplication<Application>(), api, force) }
        }
    }

    // ── lists ─────────────────────────────────────────────────────────────

    fun showTab(tab: Tab) {
        if (_state.value.screen == Screen.Conversation) cancelActiveRun(abort = false)
        _state.update { it.copy(tab = tab, error = null) }
        when (tab) {
            Tab.Chats -> {
                _state.update { it.copy(screen = Screen.Chats) }
                if (_state.value.sessions.isEmpty()) refreshSessions()
            }
            Tab.Groups -> {
                _state.update { it.copy(screen = Screen.Groups) }
                if (_state.value.rooms.isEmpty()) refreshRooms()
            }
            Tab.Agent -> {
                _state.update { it.copy(screen = Screen.AgentHub) }
                refreshServerConfig()
                if (_state.value.cronJobs.isEmpty()) refreshCronJobs()
            }
        }
    }

    fun refreshSessions() {
        if (_state.value.refreshingSessions) return
        val profile = _state.value.profileFilter.ifBlank { null }
        _state.update { it.copy(refreshingSessions = true, error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.sessions(profile) } }
                .onSuccess { sessions ->
                    _state.update { it.copy(sessions = sessions, refreshingSessions = false) }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(
                            refreshingSessions = false,
                            error = failure.readableMessage(localized),
                        )
                    }
                }
        }
    }

    fun searchSessions(query: String) {
        if (query.isBlank()) { _state.update { it.copy(sessionSearchResults = null) }; return }
        val profile = _state.value.profileFilter.ifBlank { null }
        viewModelScope.launch {
            delay(250)
            runCatching { withContext(Dispatchers.IO) { api.searchSessions(query.trim(), profile) } }
                .onSuccess { results -> _state.update { it.copy(sessionSearchResults = results) } }
        }
    }

    fun loadSessionCategories() {
        viewModelScope.launch { runCatching { withContext(Dispatchers.IO) { api.sessionCategories() } }.onSuccess { categories -> _state.update { it.copy(sessionCategories = categories) } } }
    }

    fun createSessionCategory(name: String) = launchWork(
        work = { api.createSessionCategory(name) },
        onSuccess = { category -> _state.update { it.copy(sessionCategories = it.sessionCategories + category) } },
    )

    fun setSessionCategory(session: SessionSummary, categoryId: Int?) = launchWork(
        work = { api.setSessionCategory(session.id, categoryId) },
        onSuccess = { refreshSessions(); _state.update { it.copy(sessionSearchResults = null) } },
    )

    fun archiveSession(session: SessionSummary) = launchWork(
        work = { api.archiveSession(session.id, !session.archived) },
        onSuccess = { refreshSessions(); _state.update { it.copy(sessionSearchResults = null, notice = str(if (session.archived) R.string.session_unarchived else R.string.session_archived)) } },
    )

    fun openWorkflows() {
        _state.update { it.copy(screen = Screen.Workflows, loadingWorkflows = true, error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.workflows(_state.value.profileFilter.ifBlank { null }) } }
                .onSuccess { workflows ->
                    val runs = withContext(Dispatchers.IO) { workflows.associate { it.id to runCatching { api.workflowRuns(it.id) }.getOrDefault(emptyList()) } }
                    _state.update { it.copy(workflows = workflows, workflowRuns = runs, loadingWorkflows = false) }
                }.onFailure { failure -> _state.update { it.copy(loadingWorkflows = false, error = failure.readableMessage(localized)) } }
        }
    }

    fun runWorkflow(workflow: StudioWorkflow, input: String?) = launchWork(
        work = { api.runWorkflow(workflow.id, input) },
        onSuccess = { openWorkflows() },
    )

    fun stopWorkflowRun(run: StudioWorkflowRun) = launchWork(
        work = { api.stopWorkflowRun(run.workflowId, run.id) },
        onSuccess = { openWorkflows() },
    )

    fun approveWorkflowNode(run: StudioWorkflowRun, approved: Boolean) {
        val node = run.pendingNodeId ?: return
        launchWork(work = { api.approveWorkflowNode(run.workflowId, run.id, node, approved) }, onSuccess = { openWorkflows() })
    }

    fun openGlobalAgent() = _state.update { it.copy(screen = Screen.GlobalAgent, error = null) }

    fun openEkkoHub() {
        _state.update { it.copy(screen = Screen.EkkoHub, loadingEkko = true, error = null) }
        val profile = currentProfile()
        viewModelScope.launch {
            val memory = runCatching { withContext(Dispatchers.IO) { api.ekkoMemories(profile) } }
            val skills = runCatching { withContext(Dispatchers.IO) { api.ekkoSkills(profile) } }
            val mcp = runCatching { withContext(Dispatchers.IO) { api.ekkoMcpServers(profile) } }
            val directories = runCatching { withContext(Dispatchers.IO) { api.ekkoExternalDirectories(profile) } }
            val error = memory.exceptionOrNull() ?: skills.exceptionOrNull() ?: mcp.exceptionOrNull() ?: directories.exceptionOrNull()
            _state.update { it.copy(ekkoMemories = memory.getOrDefault(emptyList()), ekkoSkills = skills.getOrDefault(emptyList()), ekkoMcpServers = mcp.getOrDefault(emptyList()), ekkoExternalDirectories = directories.getOrDefault(emptyList()), loadingEkko = false, error = error?.readableMessage(localized)) }
        }
    }

    fun saveEkkoMemory(memory: EkkoMemory, title: String, content: String) = launchWork(work = { api.updateEkkoMemory(currentProfile(), memory, title, content) }, onSuccess = { openEkkoHub() })
    fun deleteEkkoMemory(memory: EkkoMemory) = launchWork(work = { api.deleteEkkoMemory(currentProfile(), memory) }, onSuccess = { openEkkoHub() })
    fun toggleEkkoSkill(skill: SkillInfo) = launchWork(work = { api.setEkkoSkillEnabled(currentProfile(), skill.name, !skill.enabled) }, onSuccess = { openEkkoHub() })
    fun saveEkkoMcp(original: String?, name: String, config: String) = launchWork(work = { api.saveEkkoMcpServer(currentProfile(), original, name, config) }, onSuccess = { openEkkoHub() })
    fun toggleEkkoMcp(server: EkkoMcpServer) = launchWork(work = { api.toggleEkkoMcpServer(currentProfile(), server) }, onSuccess = { openEkkoHub() })
    fun testEkkoMcp(server: EkkoMcpServer) = launchWork(work = { api.testEkkoMcpServer(currentProfile(), server.name) }, onSuccess = { _state.update { it.copy(notice = str(R.string.ekko_mcp_test_ok)) } })
    fun deleteEkkoMcp(server: EkkoMcpServer) = launchWork(work = { api.deleteEkkoMcpServer(currentProfile(), server.name) }, onSuccess = { openEkkoHub() })

    fun restartProfile(profile: String) = launchWork(work = { api.restartProfileRuntime(profile) }, onSuccess = { refreshProfiles(); _state.update { it.copy(notice = str(R.string.profile_restarted)) } })
    fun refreshProviderModels(provider: String) = launchWork(work = { api.refreshProviderModels(currentProfile(), provider) }, onSuccess = { loadModelProviders(); _state.update { it.copy(notice = str(R.string.models_refreshed)) } })
    fun testProvider(provider: String) = launchWork(work = { api.testProvider(currentProfile(), provider) }, onSuccess = { result -> _state.update { it.copy(notice = result) } })

    fun openFiles(path: String = "") = launchWork(work = { api.studioFiles(currentProfile(), path) }, onSuccess = { files -> _state.update { it.copy(screen = Screen.Files, filesPath = path, studioFiles = files, openFile = null, error = null) } })
    fun openStudioFile(file: StudioFile) = launchWork(work = { api.readStudioFile(currentProfile(), file.path) }, onSuccess = { content -> _state.update { it.copy(openFile = file, openFileContent = content) } })
    fun closeStudioFile() = _state.update { it.copy(openFile = null, openFileContent = "") }
    fun saveStudioFile(content: String) { val file = _state.value.openFile ?: return; launchWork(work = { api.writeStudioFile(currentProfile(), file.path, content) }, onSuccess = { _state.update { it.copy(openFileContent = content, notice = str(R.string.files_saved)) } }) }
    fun createStudioFolder(name: String) { val path = listOf(_state.value.filesPath, name).filter(String::isNotBlank).joinToString("/"); launchWork(work = { api.mkdirStudioFile(currentProfile(), path) }, onSuccess = { openFiles(_state.value.filesPath) }) }
    fun renameStudioFile(file: StudioFile, name: String) { val target = file.path.substringBeforeLast('/', "").let { if (it.isBlank()) name else "$it/$name" }; launchWork(work = { api.renameStudioFile(currentProfile(), file.path, target) }, onSuccess = { openFiles(_state.value.filesPath) }) }
    fun copyStudioFile(file: StudioFile, destination: String) = launchWork(work = { api.copyStudioFile(currentProfile(), file.path, destination) }, onSuccess = { openFiles(_state.value.filesPath) })
    fun deleteStudioFile(file: StudioFile) = launchWork(work = { api.deleteStudioFile(currentProfile(), file) }, onSuccess = { openFiles(_state.value.filesPath) })
    fun studioFileUrl(file: StudioFile): String = api.studioFilePreviewUrl(currentProfile(), file.path)
    fun uploadStudioFile(bytes: ByteArray, name: String, mime: String) = launchWork(work = { api.uploadStudioFile(currentProfile(), _state.value.filesPath, bytes, name, mime) }, onSuccess = { openFiles(_state.value.filesPath) })

    fun openLogs() = launchWork(work = { api.studioLogs() }, onSuccess = { logs -> _state.update { it.copy(screen = Screen.Logs, studioLogs = logs, openLog = null, error = null) } })
    fun openLog(log: StudioLogFile) = launchWork(work = { api.studioLog(log.name, currentProfile()) }, onSuccess = { entries -> _state.update { it.copy(openLog = log, logEntries = entries) } })
    fun closeLog() = _state.update { it.copy(openLog = null, logEntries = emptyList()) }

    fun openConnections() = launchWork(work = { (Triple(api.appRelayStatus(), api.studioDevices(), api.appConnections())) to (runCatching { api.devicePairingLink() }.getOrDefault("") to runCatching { api.peerConnections() }.getOrDefault(emptyList())) }, onSuccess = { data -> val (primary, extra) = data; val (relay, devices, connections) = primary; _state.update { it.copy(screen = Screen.Connections, appRelay = relay, studioDevices = devices, appConnections = connections, pairingLink = extra.first, peerConnections = extra.second, error = null) } })
    fun connectRelay() = launchWork(work = { api.connectAppRelay() }, onSuccess = { relay -> _state.update { it.copy(appRelay = relay) } })
    fun refreshRelayCode() = launchWork(work = { api.refreshAppRelayCode() }, onSuccess = { relay -> _state.update { it.copy(appRelay = relay) } })
    fun disconnectRelay() = launchWork(work = { api.disconnectAppRelay() }, onSuccess = { relay -> _state.update { it.copy(appRelay = relay) } })
    fun deviceAction(device: StudioDevice, action: String) = launchWork(work = { api.deviceAction(device.id, action) }, onSuccess = { openConnections() })
    fun createAppAuthorization(cloud: Boolean) = launchWork(work = { api.createAppAuthorization(cloud) }, onSuccess = { auth -> _state.update { it.copy(appAuthorization = auth) } })
    fun revokeAppConnection(connection: AppConnection) = launchWork(work = { api.revokeAppConnection(connection.id) }, onSuccess = { openConnections() })
    fun manualDeviceRequest(url: String) = launchWork(work = { api.manualDeviceRequest(url) }, onSuccess = { openConnections() })
    fun disconnectPeer(connection: PeerConnection) = launchWork(work = { api.disconnectPeer(connection.id) }, onSuccess = { openConnections() })

    fun switchActiveProfile(name: String) = launchWork(work = { api.switchActiveProfile(name) }, onSuccess = { selectProfile(name); refreshProfiles() })
    fun importProfile(bytes: ByteArray, name: String) = launchWork(work = { api.importProfile(bytes, name) }, onSuccess = { refreshProfiles() })
    fun profileExportUrl(name: String): String = api.profileExportUrl(name)
    fun updateProfileAvatar(name: String, dataUrl: String) = launchWork(work = { api.updateProfileAvatar(name, dataUrl) }, onSuccess = { refreshProfiles() })
    fun clearProfileAvatar(name: String) = launchWork(work = { api.clearProfileAvatar(name) }, onSuccess = { refreshProfiles() })

    fun saveEkkoSkill(name: String, content: String, creating: Boolean) = launchWork(work = { if (creating) api.createEkkoSkill(currentProfile(), name, content) else api.saveEkkoSkill(currentProfile(), name, content) }, onSuccess = { openEkkoHub() })
    fun deleteEkkoSkill(skill: SkillInfo) = launchWork(work = { api.deleteEkkoSkill(currentProfile(), skill.name) }, onSuccess = { openEkkoHub() })
    fun importEkkoSkill(bytes: ByteArray, name: String) = launchWork(work = { api.importEkkoSkill(currentProfile(), bytes, name) }, onSuccess = { openEkkoHub() })
    fun openEkkoSkill(skill: SkillInfo) = launchWork(work = { Triple(api.ekkoSkillDetail(currentProfile(), skill.name), api.ekkoSkillFiles(currentProfile(), skill.name), skill) }, onSuccess = { (content, files, selected) -> _state.update { it.copy(ekkoOpenSkill = selected, ekkoSkillContent = content, ekkoSkillFiles = files) } })
    fun closeEkkoSkill() = _state.update { it.copy(ekkoOpenSkill = null, ekkoSkillContent = "", ekkoSkillFiles = emptyList(), ekkoSkillFilePreviewPath = null, ekkoSkillFilePreviewContent = "") }
    fun openEkkoSkillFile(path: String) { val skill = _state.value.ekkoOpenSkill ?: return; launchWork(work = { api.ekkoSkillFile(currentProfile(), skill.name, path) }, onSuccess = { content -> _state.update { it.copy(ekkoSkillFilePreviewPath = path, ekkoSkillFilePreviewContent = content) } }) }
    fun saveExternalDirectories(lines: String) = launchWork(work = { api.saveEkkoExternalDirectories(currentProfile(), lines.lines().map(String::trim).filter(String::isNotBlank)) }, onSuccess = { openEkkoHub() })

    fun downloadProfile(name: String) {
        val request = DownloadManager.Request(Uri.parse(api.profileExportUrl(name))).setTitle("hermes-profile-$name.tar.gz").setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED).setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, "hermes-profile-$name.tar.gz")
        store.token.takeIf(String::isNotBlank)?.let { request.addRequestHeader("Authorization", "Bearer $it") }
        getApplication<Application>().getSystemService(DownloadManager::class.java)?.enqueue(request)
        _state.update { it.copy(notice = str(R.string.profile_export_started)) }
    }

    fun openJourney() = launchWork(work = { api.journey() to api.skillUsage() }, onSuccess = { (journey, usage) -> _state.update { it.copy(screen = Screen.Journey, journey = journey, skillUsage = usage) } })
    fun openWebhooks() = launchWork(work = { api.webhooks() to api.webhookEvents() }, onSuccess = { (hooks, events) -> _state.update { it.copy(screen = Screen.Webhooks, webhooks = hooks, webhookEvents = events) } })
    fun createWebhook(name: String, url: String) = launchWork(work = { api.createWebhook(name, url) }, onSuccess = { openWebhooks() })
    fun toggleWebhook(item: WebhookEndpoint) = launchWork(work = { api.toggleWebhook(item) }, onSuccess = { openWebhooks() })
    fun updateWebhook(item: WebhookEndpoint, name: String, url: String) = launchWork(work = { api.updateWebhook(item.id, name, url) }, onSuccess = { openWebhooks() })
    fun deleteWebhook(item: WebhookEndpoint) = launchWork(work = { api.deleteWebhook(item.id) }, onSuccess = { openWebhooks() })
    fun testWebhook(item: WebhookEndpoint) = launchWork(work = { api.testWebhook(item.id) }, onSuccess = { result -> _state.update { it.copy(notice = result) } })
    fun clearWebhookEvents() = launchWork(work = { api.clearWebhookEvents() }, onSuccess = { openWebhooks() })
    fun openRuntimeVersions() = launchWork(work = { api.runtimeVersions() }, onSuccess = { versions -> _state.update { it.copy(screen = Screen.RuntimeVersions, runtimeVersions = versions) } })
    fun activateVersion(version: RuntimeVersion) = launchWork(work = { api.activateVersion(version.version, version.kind == "webui") }, onSuccess = { openRuntimeVersions() })
    fun downloadVersion(version: String, webUi: Boolean) = launchWork(work = { api.downloadVersion(version, webUi) }, onSuccess = { openRuntimeVersions() })
    fun restartWebUi() = launchWork(work = { api.restartWebUi() }, onSuccess = { openRuntimeVersions() })
    fun openAppearance() = launchWork(work = { api.themeSettings() }, onSuccess = { theme -> _state.update { it.copy(screen = Screen.Appearance, themeSettings = theme) } })
    fun saveTheme(fontSize: Int, text: String, accent: String) = launchWork(work = { api.updateTheme(fontSize, text, accent) }, onSuccess = { openAppearance() })
    fun removeThemeBackground() = launchWork(work = { api.removeThemeBackground() }, onSuccess = { openAppearance() })
    fun uploadThemeBackground(bytes: ByteArray, name: String, mime: String) = launchWork(work = { api.uploadThemeBackground(bytes, name, mime) }, onSuccess = { openAppearance() })
    fun loadKanbanOperations(taskId: String? = null) { val board = _state.value.kanban.board; if (board.isBlank()) return; launchWork(work = { val diagnostics = api.kanbanDiagnostics(board, taskId); val stats = api.kanbanStats(board); val extras = taskId?.let { api.kanbanLog(board, it) to api.kanbanAttachments(board, it) } ?: ("" to emptyList()); Triple(stats, diagnostics, extras) }, onSuccess = { (stats, diagnostics, extras) -> _state.update { it.copy(kanbanStats = stats, kanbanDiagnostics = diagnostics, kanbanLog = extras.first, kanbanAttachments = extras.second) } }) }
    fun kanbanCommand(task: KanbanTask, action: String, value: String = "") { val board = _state.value.kanban.board; launchWork(work = { api.kanbanCommand(board, task.id, action, value) }, onSuccess = { loadKanbanTask(task.id); loadKanbanOperations(task.id) }) }

    fun startGlobalAgentConversation() {
        startNewConversation(AgentRuntimeSelection("ekko-agent", "ekko", "Global Agent", globalAgent = true))
    }

    fun refreshRooms() = launchWork(
        work = { api.rooms() },
        onSuccess = { rooms -> _state.update { it.copy(rooms = rooms) } },
    )

    fun setProfileFilter(profile: String) {
        _state.update { it.copy(profileFilter = profile) }
        refreshSessions()
    }

    fun refreshProfiles() = launchWork(
        work = { api.profiles() to runCatching { api.profileRuntimeStatuses() }.getOrDefault(emptyMap()) },
        onSuccess = { (profiles, statuses) ->
            _state.update { it.copy(profiles = profiles, activeProfile = pickProfile(profiles), profileRuntimeStatuses = statuses) }
        },
    )

    fun selectProfile(name: String) {
        cancelActiveRun(abort = false)
        historyJob?.cancel()
        historyJob = null
        store.profile = name
        _state.update {
            it.copy(
                activeProfile = name,
                screen = Screen.Chats,
                tab = Tab.Chats,
                openSession = null,
                lines = emptyList(),
                attachments = emptyList(),
                sessionModel = null,
                sessionProvider = null,
                models = emptyList(),
                modelsProfile = null,
                defaultModel = null,
                serverConfig = null,
                agentSettings = null,
                autoStart = null,
            )
        }
    }

    // ── conversation ──────────────────────────────────────────────────────

    /** Open an existing Studio conversation and load its history. */
    fun openSession(session: SessionSummary) {
        cancelActiveRun(abort = false)
        historyJob?.cancel()
        val profile = session.profile?.ifBlank { null }
            ?: _state.value.activeProfile.ifBlank { "default" }
        store.setSessionFor(profile, session.id)
        _state.update {
            val runtime = runtimeForSession(session)
            it.copy(
                screen = Screen.Conversation,
                openSession = session,
                sessionModel = session.model,
                sessionProvider = session.provider,
                contextTokens = 0,
                contextWindow = 0,
                loadingContext = true,
                lines = emptyList(),
                attachments = emptyList(),
                models = if (it.modelsProfile == profile) it.models else emptyList(),
                modelsProfile = it.modelsProfile.takeIf { loaded -> loaded == profile },
                loadingHistory = true,
                error = null,
                notice = null,
                selectedRuntime = runtime,
                pendingRunAction = null,
            )
        }

        historyJob = viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    val history = api.conversationHistory(session.id)
                    val window = runCatching { api.contextLength(profile, session.provider, session.model) }.getOrDefault(0)
                    history to window
                }
            }
                .onSuccess { (history, window) ->
                    _state.update { state ->
                        if (state.screen != Screen.Conversation || state.openSession?.id != session.id) {
                            return@update state
                        }
                        state.copy(
                            loadingHistory = false,
                            loadingContext = false,
                            contextTokens = history.contextTokens ?: 0,
                            contextWindow = window,
                            lines = history.messages.map { message ->
                                ChatLine(
                                    text = message.content,
                                    fromUser = message.fromUser,
                                    timestamp = message.timestamp,
                                    messageId = message.id,
                                )
                            },
                        )
                    }
                }
                .onFailure { failure ->
                    if (failure is kotlinx.coroutines.CancellationException) return@onFailure
                    _state.update {
                        if (it.screen == Screen.Conversation && it.openSession?.id == session.id) {
                            it.copy(loadingHistory = false, loadingContext = false, error = failure.readableMessage(localized))
                        } else {
                            it
                        }
                    }
                }
        }
    }

    /** Reloads the open conversation without dropping the composer or flashing an empty screen. */
    fun refreshConversation() {
        val session = _state.value.openSession ?: return
        historyJob?.cancel()
        _state.update { it.copy(loadingHistory = true, loadingContext = true, error = null) }
        historyJob = viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    val profile = session.profile?.ifBlank { null } ?: currentProfile()
                    val history = api.conversationHistory(session.id)
                    val window = runCatching { api.contextLength(profile, session.provider, session.model) }.getOrDefault(0)
                    history to window
                }
            }
                .onSuccess { (history, window) ->
                    _state.update { state ->
                        if (state.screen != Screen.Conversation || state.openSession?.id != session.id) {
                            return@update state
                        }
                        state.copy(
                            loadingHistory = false,
                            loadingContext = false,
                            contextTokens = history.contextTokens ?: state.contextTokens,
                            contextWindow = window.takeIf { it > 0 } ?: state.contextWindow,
                            lines = history.messages.map { message ->
                                ChatLine(
                                    text = message.content,
                                    fromUser = message.fromUser,
                                    timestamp = message.timestamp,
                                    messageId = message.id,
                                )
                            },
                        )
                    }
                }
                .onFailure { failure ->
                    if (failure is kotlinx.coroutines.CancellationException) return@onFailure
                    _state.update {
                        if (it.screen == Screen.Conversation && it.openSession?.id == session.id) {
                            it.copy(loadingHistory = false, loadingContext = false, error = failure.readableMessage(localized))
                        } else {
                            it
                        }
                    }
                }
        }
    }

    fun startNewConversation(runtime: AgentRuntimeSelection = AgentRuntimeSelection()) {
        cancelActiveRun(abort = false)
        historyJob?.cancel()
        historyJob = null
        val profile = _state.value.activeProfile.ifBlank { "default" }
        store.setSessionFor(profile, "")
        _state.update {
            it.copy(
                screen = Screen.Conversation,
                openSession = null,
                lines = emptyList(),
                attachments = emptyList(),
                sessionModel = null,
                sessionProvider = null,
                contextTokens = 0,
                contextWindow = 0,
                loadingContext = false,
                models = if (it.modelsProfile == profile) it.models else emptyList(),
                modelsProfile = it.modelsProfile.takeIf { loaded -> loaded == profile },
                error = null,
                notice = null,
                selectedRuntime = runtime,
                pendingRunAction = null,
            )
        }
    }

    fun openAgentRuntimes() {
        _state.update { it.copy(screen = Screen.AgentRuntimes, loadingAgentRuntimes = true, error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.agentRuntimes() } }
                .onSuccess { runtimes -> _state.update { it.copy(agentRuntimes = runtimes, loadingAgentRuntimes = false) } }
                .onFailure { failure ->
                    _state.update { it.copy(loadingAgentRuntimes = false, error = failure.readableMessage(localized)) }
                }
        }
    }

    fun startRuntimeConversation(runtime: AgentRuntimeStatus) {
        if (!runtime.installed) return
        startNewConversation(AgentRuntimeSelection(runtime.id, runtime.family, runtime.name))
    }

    /** Sends a generated Studio file to Android's public Downloads folder. */
    fun downloadChatFile(file: ChatFileLink, profile: String) {
        val application = getApplication<Application>()
        val destinationName = uniqueQueuedDownloadName(file.fileName)
        runCatching {
            val url = api.downloadUrl(file.path, file.fileName, profile.ifBlank { null })
            val extension = file.fileName.substringAfterLast('.', "").lowercase()
            val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
                ?: "application/octet-stream"
            val request = DownloadManager.Request(Uri.parse(url))
                .setTitle(file.fileName)
                .setDescription(str(R.string.download_description, profile.ifBlank { "default" }))
                .setMimeType(mime)
                .setAllowedOverMetered(true)
                .setAllowedOverRoaming(true)
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, destinationName)
            store.token.takeIf { it.isNotBlank() }
                ?.let { request.addRequestHeader("Authorization", "Bearer $it") }
            profile.takeIf { it.isNotBlank() }
                ?.let { request.addRequestHeader("X-Hermes-Profile", it) }
            val manager = application.getSystemService(DownloadManager::class.java)
                ?: error("DownloadManager unavailable")
            manager.enqueue(request)
        }.onSuccess {
            _state.update {
                it.copy(notice = str(R.string.download_started, destinationName), error = null)
            }
        }.onFailure { failure ->
            queuedDownloadNames.remove(destinationName)
            _state.update {
                it.copy(
                    error = str(R.string.download_failed, failure.readableMessage(localized)),
                    notice = null,
                )
            }
        }
    }

    fun send(message: String) {
        val text = message.trim()
        val files = _state.value.attachments
        if ((text.isEmpty() && files.isEmpty()) || _state.value.sending) return
        val session = _state.value.openSession
        val profile = session?.profile?.ifBlank { null }
            ?: _state.value.activeProfile.ifBlank { "default" }
        val selectedModel = _state.value.sessionModel
        val selectedProvider = _state.value.sessionProvider
        val reasoningEffort = _state.value.reasoningEffort
        val wantsVoiceReply = _state.value.voiceReplyPending

        // Studio's own client names a conversation before it exists, which is
        // what lets the very first message belong to a session.
        val sessionId = store.sessionFor(profile).ifBlank { session?.id }
            ?: java.util.UUID.randomUUID().toString().also { store.setSessionFor(profile, it) }

        val echo = if (files.isEmpty()) text else {
            listOf(text.ifBlank { null }, files.joinToString(", ") { "📎 " + it.name })
                .filterNotNull()
                .joinToString("\n")
        }
        _state.update {
            it.copy(
                lines = it.lines + ChatLine(echo, fromUser = true),
                sending = true,
                attachments = emptyList(),
                error = null,
                activity = null,
                voiceReplyPending = false,
            )
        }

        activeRunSessionId = sessionId
        runJob = viewModelScope.launch {
            var answer = StringBuilder()
            var thinking = StringBuilder()
            var streamed = false
            var finalReply = ""
            val runStartedAt = System.currentTimeMillis()

            fun ensureStreamingReply(startedAtMillis: Long = runStartedAt) {
                if (streamed) return
                streamed = true
                _state.update {
                    it.copy(
                        lines = it.lines + ChatLine(
                            text = "",
                            fromUser = false,
                            streaming = true,
                            startedAtMillis = startedAtMillis,
                        ),
                        activity = null,
                    )
                }
            }

            runCatching {
                chat.run(
                    profile = profile,
                    sessionId = sessionId,
                    input = text,
                    attachments = files,
                    reasoningEffort = reasoningEffort,
                    model = selectedModel,
                    provider = selectedProvider,
                    runtime = _state.value.selectedRuntime,
                    cachedMessageId = _state.value.lines.lastOrNull { !it.messageId.isNullOrBlank() }?.messageId,
                )
                    .collect { event ->
                        when (event) {
                            is RunEvent.Started -> ensureStreamingReply(event.occurredAtMillis)
                            is RunEvent.Text -> {
                                answer.append(event.delta)
                                ensureStreamingReply()
                                updateLastReply(answer.toString(), thinking.toString(), streaming = true)
                            }
                            is RunEvent.Reasoning -> {
                                thinking.append(event.delta)
                                ensureStreamingReply()
                                updateLastReply(answer.toString(), thinking.toString(), streaming = true)
                            }
                            is RunEvent.Tool -> {
                                ensureStreamingReply()
                                updateLastTool(event)
                            }
                            is RunEvent.Usage -> _state.update {
                                it.copy(
                                    contextTokens = event.contextTokens,
                                    contextWindow = event.contextWindow ?: it.contextWindow,
                                )
                            }
                            is RunEvent.Done -> {
                                val output = event.output.ifBlank { answer.toString() }
                                finalReply = output
                                val reasoning = event.reasoning.ifBlank { thinking.toString() }
                                if (streamed) {
                                    updateLastReply(output, reasoning, streaming = false)
                                } else {
                                    _state.update {
                                        it.copy(
                                            lines = it.lines + ChatLine(
                                                text = output,
                                                fromUser = false,
                                                reasoning = reasoning.ifBlank { null },
                                            ),
                                        )
                                    }
                                }
                                streamed = true
                            }
                            is RunEvent.RequiresAction -> {
                                if (streamed) {
                                    updateLastReply(answer.toString(), thinking.toString(), streaming = false)
                                }
                                _state.update {
                                    it.copy(
                                        pendingRunAction = PendingRunAction(event.kind, event.id, event.prompt, event.options, sessionId),
                                        activity = null,
                                    )
                                }
                                streamed = true
                            }
                            is RunEvent.ActionResolved -> _state.update { state ->
                                if (state.pendingRunAction?.id != event.id) state
                                else if (event.resolved) state.copy(pendingRunAction = null, activity = null)
                                else state.copy(activity = null)
                            }
                            is RunEvent.QueueChanged -> _state.update {
                                it.copy(
                                    queuedRuns = event.messages ?: it.queuedRuns,
                                    queueInsertionActive = event.insertionActive ?: it.queueInsertionActive,
                                )
                            }
                            is RunEvent.BackgroundAgent -> _state.update { state ->
                                val tasks = state.backgroundAgentRuns.toMutableList()
                                val index = tasks.indexOfFirst { it.id == event.task.id }
                                if (index >= 0) tasks[index] = event.task else tasks += event.task
                                state.copy(backgroundAgentRuns = tasks)
                            }
                            is RunEvent.Failed -> {
                                // A socket that never got going is not a failed
                                // run: fall back to the REST wrapper instead of
                                // telling the user the answer is lost.
                                if (event.retryableTransport && !streamed) throw SocketUnavailable(event.error)
                                updateLastReply(
                                    answer.toString(),
                                    thinking.toString(),
                                    streaming = false,
                                    terminalToolStatus = ToolRunStatus.Error,
                                )
                                _state.update {
                                    it.copy(lines = it.lines + ChatLine(event.error, fromUser = false, isError = true))
                                }
                            }
                        }
                    }
            }.onFailure { failure ->
                if (failure is kotlinx.coroutines.CancellationException) return@onFailure
                if (failure is SocketUnavailable) {
                    sendOverRest(
                        profile = profile,
                        sessionId = sessionId,
                        text = text,
                        files = files,
                        reasoningEffort = reasoningEffort,
                        model = selectedModel,
                        provider = selectedProvider,
                        runtime = _state.value.selectedRuntime,
                        speakReply = wantsVoiceReply,
                    )
                    finishRun(sessionId)
                    return@launch
                }
                _state.update {
                    it.copy(
                        lines = it.lines + ChatLine(failure.readableMessage(localized), fromUser = false, isError = true),
                    )
                }
            }
            if (wantsVoiceReply && finalReply.isNotBlank()) speak(finalReply, profile)
            finishRun(sessionId)
        }
    }

    fun resolveRunAction(response: String) {
        val action = _state.value.pendingRunAction ?: return
        if (response.isBlank()) return
        when (action.kind) {
            RequiredAction.Approval -> chat.respondToApproval(action.sessionId, action.id, response)
            RequiredAction.Clarification -> chat.respondToClarification(action.sessionId, action.id, response)
        }
        _state.update { it.copy(activity = str(R.string.run_action_resuming)) }
    }

    fun insertQueuedRun(queueId: String) {
        val sessionId = activeRunSessionId ?: _state.value.openSession?.id ?: return
        chat.insertQueuedRun(sessionId, queueId)
    }

    fun cancelQueuedRun(queueId: String) {
        val sessionId = activeRunSessionId ?: _state.value.openSession?.id ?: return
        chat.cancelQueuedRun(sessionId, queueId)
    }

    /** Older servers, or a blocked WebSocket, still answer over plain HTTP. */
    private suspend fun sendOverRest(
        profile: String,
        sessionId: String,
        text: String,
        files: List<Upload>,
        reasoningEffort: String?,
        model: String?,
        provider: String?,
        runtime: AgentRuntimeSelection,
        speakReply: Boolean = false,
    ) {
        runCatching {
            withContext(Dispatchers.IO) {
                api.sendMessage(
                    profile = profile,
                    input = text,
                    sessionId = sessionId,
                    attachments = files,
                    reasoningEffort = reasoningEffort,
                    model = model,
                    provider = provider,
                    runtime = runtime,
                )
            }
        }.onSuccess { reply ->
            if (activeRunSessionId != sessionId) return@onSuccess
            reply.sessionId?.let { store.setSessionFor(profile, it) }
            val line = if (reply.error != null && reply.output.isBlank()) {
                ChatLine(reply.error, fromUser = false, isError = true)
            } else {
                ChatLine(reply.output, fromUser = false, reasoning = reply.reasoning)
            }
            _state.update { it.copy(lines = it.lines + line, sending = false, activity = null) }
            if (speakReply && !line.isError && line.text.isNotBlank()) speak(line.text, profile)
        }.onFailure { failure ->
            if (failure is kotlinx.coroutines.CancellationException || activeRunSessionId != sessionId) {
                return@onFailure
            }
            _state.update {
                it.copy(
                    lines = it.lines + ChatLine(failure.readableMessage(localized), fromUser = false, isError = true),
                    sending = false,
                    activity = null,
                )
            }
        }
    }

    private fun runtimeForSession(session: SessionSummary): AgentRuntimeSelection {
        val id = when (session.agentId?.lowercase()) {
            "ekko", "ekko-agent" -> "ekko-agent"
            "claude", "claude-code" -> "claude-code"
            "codex" -> "codex"
            "pi" -> "pi"
            else -> "hermes"
        }
        val family = when (id) { "hermes" -> "hermes"; "ekko-agent" -> "ekko"; else -> "coding" }
        val global = session.source == "global_agent"
        val name = if (global) "Global Agent" else when (id) { "hermes" -> "Hermes"; "ekko-agent" -> "Ekko"; "claude-code" -> "Claude Code"; "codex" -> "Codex"; else -> "Pi" }
        return AgentRuntimeSelection(id, family, name, global)
    }

    private fun updateLastReply(
        text: String,
        reasoning: String,
        streaming: Boolean,
        terminalToolStatus: ToolRunStatus = ToolRunStatus.Done,
    ) {
        _state.update { state ->
            val lines = state.lines.toMutableList()
            val index = lines.indexOfLast { !it.fromUser && !it.isError }
            if (index < 0) return@update state
            val now = System.currentTimeMillis()
            val current = lines[index]
            if (!streaming && text.isBlank() && reasoning.isBlank() && current.tools.isEmpty()) {
                lines.removeAt(index)
                return@update state.copy(lines = lines)
            }
            lines[index] = lines[index].copy(
                text = text,
                reasoning = reasoning.ifBlank { null },
                streaming = streaming,
                finishedAtMillis = if (streaming) null else now,
                tools = if (streaming) {
                    current.tools
                } else {
                    current.tools.map { tool ->
                        if (tool.status != ToolRunStatus.Running) tool else tool.copy(
                            status = terminalToolStatus,
                            durationSeconds = tool.durationSeconds
                                ?: ((now - tool.startedAtMillis).coerceAtLeast(0) / 1000.0),
                        )
                    }
                },
            )
            state.copy(lines = lines)
        }
    }

    private fun updateLastTool(event: RunEvent.Tool) {
        _state.update { state ->
            val lines = state.lines.toMutableList()
            val lineIndex = lines.indexOfLast { !it.fromUser && !it.isError }
            if (lineIndex < 0) return@update state
            val line = lines[lineIndex]
            val tools = line.tools.toMutableList()
            val matchingIndex = when {
                event.id.isNotBlank() -> tools.indexOfLast { it.id == event.id }
                event.status != ToolRunStatus.Running -> tools.indexOfLast {
                    it.status == ToolRunStatus.Running && it.name == event.name
                }
                else -> -1
            }

            if (matchingIndex >= 0) {
                val current = tools[matchingIndex]
                tools[matchingIndex] = current.copy(
                    name = event.name.ifBlank { current.name },
                    detail = current.detail ?: event.detail,
                    status = event.status,
                    durationSeconds = event.durationSeconds ?: if (event.status == ToolRunStatus.Running) {
                        current.durationSeconds
                    } else {
                        (event.occurredAtMillis - current.startedAtMillis).coerceAtLeast(0) / 1000.0
                    },
                )
            } else {
                val fallbackDuration = event.durationSeconds
                val startedAt = if (fallbackDuration != null) {
                    event.occurredAtMillis - (fallbackDuration * 1000).toLong()
                } else {
                    event.occurredAtMillis
                }
                tools += ChatToolStep(
                    id = event.id.ifBlank { "${event.name}-${event.occurredAtMillis}" },
                    name = event.name,
                    detail = event.detail,
                    status = event.status,
                    startedAtMillis = startedAt,
                    durationSeconds = fallbackDuration,
                )
            }

            lines[lineIndex] = line.copy(tools = tools)
            val active = tools.lastOrNull { it.status == ToolRunStatus.Running }?.name
            state.copy(lines = lines, activity = active)
        }
    }

    /** Asks the server to stop the run that is streaming right now. */
    fun stopRun() {
        cancelActiveRun(abort = true)
    }

    private fun cancelActiveRun(abort: Boolean) {
        val sessionId = activeRunSessionId
        if (abort && !sessionId.isNullOrBlank()) chat.abort(sessionId)
        runJob?.cancel()
        runJob = null
        activeRunSessionId = null
        _state.update { state ->
            val lines = state.lines.toMutableList()
            val index = lines.indexOfLast { it.streaming }
            if (index >= 0) {
                val now = System.currentTimeMillis()
                lines[index] = lines[index].copy(
                    streaming = false,
                    finishedAtMillis = now,
                    tools = lines[index].tools.map { tool ->
                        if (tool.status != ToolRunStatus.Running) tool else tool.copy(
                            status = ToolRunStatus.Error,
                            durationSeconds = (now - tool.startedAtMillis).coerceAtLeast(0) / 1000.0,
                        )
                    },
                )
            }
            state.copy(lines = lines, sending = false, activity = null)
        }
    }

    private fun finishRun(sessionId: String) {
        if (activeRunSessionId != sessionId) return
        activeRunSessionId = null
        runJob = null
        _state.update { it.copy(sending = false, activity = null) }
    }

    private class SocketUnavailable(message: String) : Exception(message)

    // ── attachments ───────────────────────────────────────────────────────

    /** Uploads the picked file to the server so the agent can read it by path. */
    fun attach(bytes: ByteArray, filename: String, mime: String) {
        val profile = currentProfile()
        _state.update { it.copy(attaching = true, error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.upload(profile, bytes, filename, mime) } }
                .onSuccess { upload ->
                    _state.update { it.copy(attaching = false, attachments = it.attachments + upload) }
                }
                .onFailure { failure ->
                    _state.update { it.copy(attaching = false, error = failure.readableMessage(localized)) }
                }
        }
    }

    fun removeAttachment(upload: Upload) {
        _state.update { it.copy(attachments = it.attachments - upload) }
    }

    // ── voice ─────────────────────────────────────────────────────────────

    fun startRecording() {
        if (_state.value.recording) return
        if (recorder.start()) {
            _state.update { it.copy(recording = true, error = null) }
        } else {
            _state.update { it.copy(error = str(R.string.error_microphone)) }
        }
    }

    fun cancelRecording() {
        recorder.cancel()
        _state.update { it.copy(recording = false) }
    }

    /** Stops the take and turns it into text with the profile's STT provider. */
    fun stopRecordingAndTranscribe() {
        if (!_state.value.recording) return
        val bytes = recorder.stop()
        _state.update { it.copy(recording = false) }
        if (bytes == null) {
            _state.update { it.copy(error = str(R.string.error_recording_short)) }
            return
        }

        val profile = currentProfile()
        _state.update { it.copy(transcribing = true, error = null) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    api.transcribe(profile, bytes, "voice.m4a", "audio/mp4")
                }
            }.onSuccess { text ->
                _state.update { it.copy(transcribing = false, transcript = text, voiceReplyPending = true) }
            }.onFailure { failure ->
                _state.update { it.copy(transcribing = false, error = failure.readableMessage(localized)) }
            }
        }
    }

    fun consumeTranscript() = _state.update { it.copy(transcript = null) }

    fun stopSpeaking() {
        runCatching { speechPlayer?.stop() }
        runCatching { speechPlayer?.release() }
        speechPlayer = null
        _state.update { it.copy(speaking = false) }
    }

    private fun speak(text: String, profile: String) {
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    val audio = api.synthesize(profile, text)
                    val file = java.io.File.createTempFile("hermes-reply-", audio.extension, getApplication<Application>().cacheDir)
                    file.writeBytes(audio.bytes)
                    file
                }
            }.onSuccess { file ->
                runCatching {
                    stopSpeaking()
                    MediaPlayer().also { player ->
                        speechPlayer = player
                        player.setDataSource(file.absolutePath)
                        player.setOnPreparedListener { ready ->
                            runCatching { ready.start() }
                                .onSuccess { _state.update { it.copy(speaking = true) } }
                                .onFailure { stopSpeaking(); file.delete(); _state.update { it.copy(error = it.error ?: str(R.string.voice_playback_failed)) } }
                        }
                        player.setOnCompletionListener { finished ->
                            runCatching { finished.release() }
                            if (speechPlayer === finished) speechPlayer = null
                            file.delete()
                            _state.update { it.copy(speaking = false) }
                        }
                        player.setOnErrorListener { failed, _, _ ->
                            runCatching { failed.release() }
                            if (speechPlayer === failed) speechPlayer = null
                            file.delete()
                            _state.update { it.copy(speaking = false, error = str(R.string.voice_playback_failed)) }
                            true
                        }
                        player.prepareAsync()
                    }
                }.onFailure {
                    stopSpeaking()
                    file.delete()
                    _state.update { state -> state.copy(error = str(R.string.voice_playback_failed)) }
                }
            }.onFailure { failure -> _state.update { it.copy(speaking = false, error = failure.readableMessage(localized)) } }
        }
    }

    override fun onCleared() {
        stopSpeaking()
        super.onCleared()
    }

    // ── model and reasoning ───────────────────────────────────────────────

    fun loadModels() {
        val profile = currentProfile()
        val current = _state.value
        if (current.modelsProfile == profile && (current.models.isNotEmpty() || current.loadingModels)) return
        _state.update {
            it.copy(
                models = if (it.modelsProfile == profile) it.models else emptyList(),
                modelsProfile = profile,
                loadingModels = true,
            )
        }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.availableModels(profile) } }
                .onSuccess { models ->
                    _state.update {
                        if (it.modelsProfile == profile) it.copy(models = models, loadingModels = false) else it
                    }
                }
                .onFailure { failure ->
                    _state.update {
                        if (it.modelsProfile == profile) {
                            it.copy(loadingModels = false, error = failure.readableMessage(localized))
                        } else {
                            it
                        }
                    }
                }
        }
    }

    /** Applies a model to the open session, or remembers it for the next one. */
    fun selectModel(option: ModelOption) {
        val sessionId = _state.value.openSession?.id
            ?: store.sessionFor(currentProfile()).ifBlank { null }
        _state.update {
            it.copy(
                sessionModel = option.id,
                sessionProvider = option.provider,
                loadingContext = true,
            )
        }
        viewModelScope.launch {
            val profile = currentProfile()
            val length = runCatching {
                withContext(Dispatchers.IO) { api.contextLength(profile, option.provider, option.id) }
            }.getOrDefault(0)
            _state.update {
                if (it.sessionModel == option.id && it.sessionProvider == option.provider) {
                    it.copy(
                        contextWindow = length.takeIf { value -> value > 0 } ?: it.contextWindow,
                        loadingContext = false,
                    )
                } else it
            }
        }
        if (sessionId == null) return

        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) { api.setSessionModel(sessionId, option.id, option.provider) }
            }.onFailure { failure ->
                _state.update { it.copy(error = failure.readableMessage(localized)) }
            }
        }
    }

    fun setReasoningEffort(effort: String) {
        store.reasoningEffort = effort
        _state.update { it.copy(reasoningEffort = effort) }
    }

    // ── group room ────────────────────────────────────────────────────────

    fun openRoom(room: Room) {
        leaveRoom()
        openingRoomId = room.id
        _state.update {
            it.copy(screen = Screen.Room, openRoom = null, loadingHistory = true, error = null, roomLive = false)
        }
        roomLoadJob = viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.room(room.id) } }
                .onSuccess { detail ->
                    if (_state.value.screen != Screen.Room || openingRoomId != room.id) return@onSuccess
                    _state.update { it.copy(openRoom = detail, loadingHistory = false) }
                    listenToRoom(room.id)
                }
                .onFailure { failure ->
                    if (failure is kotlinx.coroutines.CancellationException) return@onFailure
                    _state.update {
                        if (it.screen == Screen.Room && openingRoomId == room.id) {
                            it.copy(loadingHistory = false, error = failure.readableMessage(localized))
                        } else {
                            it
                        }
                    }
                }
        }
    }

    /** Keeps the open room current, and is what makes posting possible. */
    private fun listenToRoom(roomId: String) {
        roomJob?.cancel()
        roomJob = viewModelScope.launch {
            runCatching {
                group.join(roomId, _state.value.account ?: "phone").collect { event ->
                    when (event) {
                        is RoomEvent.Connected -> _state.update { it.copy(roomLive = true) }
                        is RoomEvent.Dropped -> _state.update { it.copy(roomLive = false) }
                        is RoomEvent.Failed -> {
                            _state.update {
                                it.copy(roomLive = false, error = event.error)
                            }
                        }
                        is RoomEvent.Posted -> _state.update { state ->
                            val room = state.openRoom ?: return@update state
                            if (room.id != roomId) return@update state
                            if (room.messages.any { it.id == event.message.id }) return@update state
                            state.copy(openRoom = room.copy(messages = room.messages + event.message))
                        }
                    }
                }
            }
        }
    }

    fun leaveRoom() {
        openingRoomId = null
        roomLoadJob?.cancel()
        roomLoadJob = null
        roomJob?.cancel()
        roomJob = null
        _state.update { it.copy(roomLive = false) }
    }

    // ── conversations ─────────────────────────────────────────────────────

    fun renameSession(session: SessionSummary, title: String) {
        val clean = title.trim()
        if (clean.isBlank()) return
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.renameSession(session.id, clean) } }
                .onSuccess {
                    _state.update { state ->
                        state.copy(
                            sessions = state.sessions.map {
                                if (it.id == session.id) it.copy(title = clean) else it
                            },
                            openSession = state.openSession?.takeIf { it.id == session.id }?.copy(title = clean)
                                ?: state.openSession,
                        )
                    }
                }
                .onFailure { failure -> _state.update { it.copy(error = failure.readableMessage(localized)) } }
        }
    }

    fun deleteSession(session: SessionSummary) {
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.deleteSession(session.id) } }
                .onSuccess {
                    // Forget the pointer too, or the next message would try to
                    // continue a conversation the server no longer has.
                    session.profile?.let { profile ->
                        if (store.sessionFor(profile) == session.id) store.setSessionFor(profile, "")
                    }
                    _state.update { state ->
                        state.copy(sessions = state.sessions.filterNot { it.id == session.id })
                    }
                }
                .onFailure { failure -> _state.update { it.copy(error = failure.readableMessage(localized)) } }
        }
    }

    // ── profiles ──────────────────────────────────────────────────────────

    fun createProfile(name: String) = profileWork(name) { api.createProfile(it) }

    fun renameProfile(from: String, to: String) = profileWork(to) { api.renameProfile(from, it) }

    fun deleteProfile(name: String) {
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.deleteProfile(name) } }
                .onSuccess {
                    if (store.profile == name) store.profile = ""
                    refreshProfiles()
                    _state.update { it.copy(notice = str(R.string.notice_profile_deleted, name)) }
                }
                .onFailure { failure -> _state.update { it.copy(error = failure.readableMessage(localized)) } }
        }
    }

    private fun profileWork(name: String, block: suspend (String) -> Unit) {
        val clean = name.trim()
        if (clean.isBlank()) return
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { block(clean) } }
                .onSuccess { refreshProfiles() }
                .onFailure { failure -> _state.update { it.copy(error = failure.readableMessage(localized)) } }
        }
    }

    // ── rooms ─────────────────────────────────────────────────────────────

    fun createRoom(name: String, agents: List<String>) {
        val clean = name.trim()
        if (clean.isBlank()) return
        // Studio requires an invite code; one the user never has to think about
        // is better than a field they have to fill in.
        val code = (1..6).map { INVITE_ALPHABET.random() }.joinToString("")
        _state.update { it.copy(busy = true, error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.createRoom(clean, code, agents) } }
                .onSuccess {
                    _state.update { it.copy(busy = false, notice = str(R.string.notice_room_created, clean)) }
                    refreshRooms()
                }
                .onFailure { failure ->
                    _state.update { it.copy(busy = false, error = failure.readableMessage(localized)) }
                }
        }
    }

    fun deleteRoom(room: Room) {
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.deleteRoom(room.id) } }
                .onSuccess {
                    _state.update { state -> state.copy(rooms = state.rooms.filterNot { it.id == room.id }) }
                }
                .onFailure { failure -> _state.update { it.copy(error = failure.readableMessage(localized)) } }
        }
    }

    fun addRoomAgent(roomId: String, profile: String) {
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.addRoomAgent(roomId, profile) } }
                .onSuccess { reopenRoom(roomId) }
                .onFailure { failure -> _state.update { it.copy(error = failure.readableMessage(localized)) } }
        }
    }

    private fun reopenRoom(roomId: String) {
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.room(roomId) } }
                .onSuccess { detail -> _state.update { it.copy(openRoom = detail) } }
        }
    }

    /** Sends into the open room over the socket the room screen holds. */
    fun postToRoom(text: String): Boolean {
        val room = _state.value.openRoom ?: return false
        val clean = text.trim()
        if (clean.isBlank()) return false
        val sent = group.post(room.id, clean, _state.value.account ?: "phone") { error ->
            if (error != null) _state.update { it.copy(error = error) }
        }
        if (!sent) {
            _state.update { it.copy(error = str(R.string.error_room_offline)) }
        }
        return sent
    }

    // ── native agent tools ───────────────────────────────────────────────

    fun openKanban() {
        _state.update { it.copy(screen = Screen.Kanban, error = null, notice = null) }
        loadKanban()
    }

    fun selectKanbanBoard(slug: String) {
        _state.update { it.copy(kanban = it.kanban.copy(board = slug, openTask = null)) }
        loadKanban(refreshBoards = false)
    }

    fun refreshKanban() = loadKanban()

    private fun loadKanban(refreshBoards: Boolean = true) {
        val old = _state.value.kanban
        _state.update { it.copy(kanban = it.kanban.copy(loading = true)) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    val boards = if (refreshBoards || old.boards.isEmpty()) api.kanbanBoards() else old.boards
                    val selected = old.board.takeIf { slug -> boards.any { it.slug == slug } }
                        ?: boards.firstOrNull { it.isCurrent }?.slug
                        ?: boards.firstOrNull()?.slug.orEmpty()
                    Triple(boards, api.kanbanTasks(selected), api.kanbanAssignees(selected))
                }
            }.onSuccess { (boards, tasks, assignees) ->
                val selected = _state.value.kanban.board.takeIf { slug -> boards.any { it.slug == slug } }
                    ?: boards.firstOrNull { it.isCurrent }?.slug
                    ?: boards.firstOrNull()?.slug.orEmpty()
                _state.update {
                    it.copy(kanban = it.kanban.copy(
                        loading = false,
                        boards = boards,
                        board = selected,
                        tasks = tasks,
                        assignees = assignees,
                    ))
                }
            }.onFailure { failure ->
                _state.update {
                    it.copy(kanban = it.kanban.copy(loading = false), error = failure.readableMessage(localized))
                }
            }
        }
    }

    fun createKanbanTask(
        title: String,
        body: String,
        assignee: String,
        priority: Int,
        skills: List<String>,
        triage: Boolean,
    ) {
        val clean = title.trim()
        if (clean.isBlank()) return
        val board = _state.value.kanban.board
        _state.update { it.copy(kanban = it.kanban.copy(actionId = "new"), error = null) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    api.createKanbanTask(board, clean, body.trim(), assignee, priority, skills, triage)
                }
            }.onSuccess { task ->
                _state.update {
                    it.copy(
                        kanban = it.kanban.copy(actionId = null, tasks = it.kanban.tasks + task),
                        notice = str(R.string.kanban_created),
                    )
                }
            }.onFailure { failure ->
                _state.update {
                    it.copy(kanban = it.kanban.copy(actionId = null), error = failure.readableMessage(localized))
                }
            }
        }
    }

    fun moveKanbanTask(task: KanbanTask, status: String) {
        if (task.status == status) return
        val board = _state.value.kanban.board
        _state.update {
            it.copy(
                kanban = it.kanban.copy(
                    actionId = task.id,
                    tasks = it.kanban.tasks.map { current ->
                        if (current.id == task.id) current.copy(status = status) else current
                    },
                ),
                error = null,
            )
        }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.moveKanbanTask(board, task.id, status) } }
                .onSuccess {
                    _state.update { state -> state.copy(kanban = state.kanban.copy(actionId = null)) }
                    if (_state.value.screen == Screen.KanbanTask) loadKanbanTask(task.id)
                }
                .onFailure { failure ->
                    _state.update { state ->
                        state.copy(
                            kanban = state.kanban.copy(
                                actionId = null,
                                tasks = state.kanban.tasks.map { current ->
                                    if (current.id == task.id) task else current
                                },
                            ),
                            error = failure.readableMessage(localized),
                        )
                    }
                }
        }
    }

    fun openKanbanTask(task: KanbanTask) {
        _state.update {
            it.copy(
                screen = Screen.KanbanTask,
                kanban = it.kanban.copy(openTask = KanbanTaskDetail(task, null, emptyList(), emptyList())),
                error = null,
            )
        }
        loadKanbanTask(task.id)
        loadKanbanOperations(task.id)
    }

    private fun loadKanbanTask(id: String) {
        val board = _state.value.kanban.board
        _state.update { it.copy(kanban = it.kanban.copy(loading = true)) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.kanbanTask(board, id) } }
                .onSuccess { detail ->
                    _state.update {
                        it.copy(
                            kanban = it.kanban.copy(
                                loading = false,
                                openTask = detail,
                                tasks = it.kanban.tasks.map { task ->
                                    if (task.id == detail.task.id) detail.task else task
                                },
                            ),
                        )
                    }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(kanban = it.kanban.copy(loading = false), error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun addKanbanComment(taskId: String, body: String) {
        val clean = body.trim()
        if (clean.isBlank()) return
        val board = _state.value.kanban.board
        _state.update { it.copy(kanban = it.kanban.copy(actionId = taskId), error = null) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) { api.addKanbanComment(board, taskId, clean, _state.value.account) }
            }.onSuccess { loadKanbanTask(taskId) }
                .onFailure { failure ->
                    _state.update {
                        it.copy(kanban = it.kanban.copy(actionId = null), error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun assignKanbanTask(taskId: String, assignee: String) {
        val board = _state.value.kanban.board
        _state.update { it.copy(kanban = it.kanban.copy(actionId = taskId), error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.assignKanbanTask(board, taskId, assignee) } }
                .onSuccess { loadKanbanTask(taskId) }
                .onFailure { failure ->
                    _state.update {
                        it.copy(kanban = it.kanban.copy(actionId = null), error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun openSkills() {
        _state.update { it.copy(screen = Screen.Skills, error = null, notice = null) }
        loadSkills()
    }

    fun selectSkillsTarget(target: String) {
        _state.update { it.copy(skillsUi = it.skillsUi.copy(target = target, openSkill = null)) }
        loadSkills()
    }

    fun refreshSkills() = loadSkills()

    private fun loadSkills() {
        val profile = currentProfile()
        val target = _state.value.skillsUi.target
        _state.update { it.copy(skillsUi = it.skillsUi.copy(loading = true)) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.skills(profile, target) to api.pendingSkillWrites(profile) } }
                .onSuccess { (categories, pendingWrites) ->
                    _state.update { it.copy(skillsUi = it.skillsUi.copy(loading = false, resolvingWriteId = null, categories = categories, pendingWrites = pendingWrites)) }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(skillsUi = it.skillsUi.copy(loading = false, resolvingWriteId = null), error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun resolvePendingSkillWrite(id: String, approve: Boolean) {
        val profile = currentProfile()
        _state.update { it.copy(skillsUi = it.skillsUi.copy(resolvingWriteId = id), error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.resolvePendingSkillWrite(profile, id, approve) } }
                .onSuccess { loadSkills() }
                .onFailure { failure ->
                    _state.update { it.copy(skillsUi = it.skillsUi.copy(resolvingWriteId = null), error = failure.readableMessage(localized)) }
                }
        }
    }

    fun openSkill(category: String, skill: SkillInfo) {
        _state.update { it.copy(screen = Screen.Skill, skillsUi = it.skillsUi.copy(loading = true), error = null) }
        val profile = currentProfile()
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.skillContent(profile, category, skill.name) } }
                .onSuccess { content ->
                    _state.update {
                        it.copy(skillsUi = it.skillsUi.copy(loading = false, openSkill = OpenSkill(category, skill, content)))
                    }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(skillsUi = it.skillsUi.copy(loading = false), error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun saveSkill(content: String) = mutateOpenSkill { profile, open ->
        api.saveSkill(profile, open.category, open.skill.name, content)
    }

    fun toggleSkill(skill: SkillInfo, enabled: Boolean) {
        val profile = currentProfile()
        _state.update { it.copy(skillsUi = it.skillsUi.copy(actionName = skill.name), error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.setSkillEnabled(profile, skill.name, enabled) } }
                .onSuccess {
                    updateSkill(skill.name) { it.copy(enabled = enabled) }
                    _state.update { it.copy(skillsUi = it.skillsUi.copy(actionName = null)) }
                }
                .onFailure { failure -> toolSkillFailure(failure) }
        }
    }

    fun pinSkill(skill: SkillInfo, pinned: Boolean) {
        val profile = currentProfile()
        _state.update { it.copy(skillsUi = it.skillsUi.copy(actionName = skill.name), error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.setSkillPinned(profile, skill.name, pinned) } }
                .onSuccess {
                    updateSkill(skill.name) { it.copy(pinned = pinned) }
                    _state.update { it.copy(skillsUi = it.skillsUi.copy(actionName = null)) }
                }
                .onFailure { failure -> toolSkillFailure(failure) }
        }
    }

    fun deleteOpenSkill() {
        val open = _state.value.skillsUi.openSkill ?: return
        val profile = currentProfile()
        _state.update { it.copy(skillsUi = it.skillsUi.copy(actionName = open.skill.name), error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.deleteSkill(profile, open.category, open.skill.name) } }
                .onSuccess {
                    _state.update { it.copy(screen = Screen.Skills, skillsUi = it.skillsUi.copy(openSkill = null, actionName = null)) }
                    loadSkills()
                }
                .onFailure { failure -> toolSkillFailure(failure) }
        }
    }

    fun importSkill(bytes: ByteArray, filename: String, category: String = "Imported") {
        val profile = currentProfile()
        _state.update { it.copy(skillsUi = it.skillsUi.copy(actionName = "import"), error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.importSkill(profile, category, bytes, filename) } }
                .onSuccess { name ->
                    _state.update {
                        it.copy(skillsUi = it.skillsUi.copy(actionName = null), notice = str(R.string.skills_imported, name))
                    }
                    loadSkills()
                }
                .onFailure { failure -> toolSkillFailure(failure) }
        }
    }

    private fun mutateOpenSkill(block: (String, OpenSkill) -> Unit) {
        val open = _state.value.skillsUi.openSkill ?: return
        val profile = currentProfile()
        _state.update { it.copy(skillsUi = it.skillsUi.copy(actionName = open.skill.name), error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { block(profile, open) } }
                .onSuccess {
                    _state.update {
                        it.copy(
                            skillsUi = it.skillsUi.copy(actionName = null, openSkill = open),
                            notice = str(R.string.skills_saved),
                        )
                    }
                }
                .onFailure { failure -> toolSkillFailure(failure) }
        }
    }

    private fun updateSkill(name: String, transform: (SkillInfo) -> SkillInfo) {
        _state.update { state ->
            val categories = state.skillsUi.categories.map { category ->
                category.copy(skills = category.skills.map { if (it.name == name) transform(it) else it })
            }
            val open = state.skillsUi.openSkill?.let {
                if (it.skill.name == name) it.copy(skill = transform(it.skill)) else it
            }
            state.copy(skillsUi = state.skillsUi.copy(categories = categories, openSkill = open))
        }
    }

    private fun toolSkillFailure(failure: Throwable) {
        _state.update {
            it.copy(skillsUi = it.skillsUi.copy(actionName = null), error = failure.readableMessage(localized))
        }
    }

    fun openPlugins() {
        _state.update { it.copy(screen = Screen.Plugins, error = null, notice = null) }
        loadPlugins()
    }

    fun refreshPlugins() = loadPlugins()

    private fun loadPlugins() {
        _state.update { it.copy(pluginsUi = it.pluginsUi.copy(loading = true)) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.plugins() } }
                .onSuccess { (plugins, warnings) ->
                    _state.update {
                        it.copy(pluginsUi = it.pluginsUi.copy(loading = false, plugins = plugins, warnings = warnings))
                    }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(pluginsUi = it.pluginsUi.copy(loading = false), error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun togglePlugin(plugin: HermesPlugin, enabled: Boolean) {
        _state.update { it.copy(pluginsUi = it.pluginsUi.copy(actionKey = plugin.key), error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.setPluginEnabled(plugin.key, enabled) } }
                .onSuccess { loadPlugins() }
                .onFailure { failure ->
                    _state.update {
                        it.copy(pluginsUi = it.pluginsUi.copy(actionKey = null), error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun openMcp() {
        _state.update { it.copy(screen = Screen.Mcp, error = null, notice = null) }
        loadMcp()
    }

    fun refreshMcp() = loadMcp()

    private fun loadMcp() {
        _state.update { it.copy(mcpUi = it.mcpUi.copy(loading = true)) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.mcpServers() } }
                .onSuccess { servers ->
                    _state.update { it.copy(mcpUi = it.mcpUi.copy(loading = false, actionName = null, servers = servers)) }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(mcpUi = it.mcpUi.copy(loading = false, actionName = null), error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun saveMcpServer(originalName: String?, name: String, config: String) {
        if (name.isBlank()) return
        _state.update { it.copy(mcpUi = it.mcpUi.copy(actionName = originalName ?: "new"), error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.saveMcpServer(originalName, name.trim(), config) } }
                .onSuccess { loadMcp() }
                .onFailure { failure ->
                    _state.update {
                        it.copy(mcpUi = it.mcpUi.copy(actionName = null), error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun deleteMcpServer(name: String) = mutateMcp(name) { api.deleteMcpServer(name) }

    fun testMcpServer(name: String) = mutateMcp(name) { api.testMcpServer(name) }

    fun reloadMcpServer(name: String? = null) = mutateMcp(name ?: "all") { api.reloadMcpServer(name) }

    private fun mutateMcp(name: String, block: () -> Unit) {
        _state.update { it.copy(mcpUi = it.mcpUi.copy(actionName = name), error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { block() } }
                .onSuccess { loadMcp() }
                .onFailure { failure ->
                    _state.update {
                        it.copy(mcpUi = it.mcpUi.copy(actionName = null), error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun openPets() {
        _state.update { it.copy(screen = Screen.Pets, error = null, notice = null) }
        loadPets()
    }

    fun openInsights(days: Int = _state.value.usageDays) {
        _state.update { it.copy(screen = Screen.Insights, usageDays = days, loadingInsights = true, error = null) }
        refreshInsights(days)
    }

    fun refreshInsights(days: Int = _state.value.usageDays) {
        _state.update { it.copy(usageDays = days, loadingInsights = true, error = null) }
        viewModelScope.launch {
            val result = runCatching {
                withContext(Dispatchers.IO) { api.usageStats(days) to api.runtimePerformance() }
            }
            result.onSuccess { (usage, performance) ->
                _state.update { it.copy(usageStats = usage, runtimePerformance = performance, loadingInsights = false) }
            }.onFailure { failure ->
                _state.update { it.copy(loadingInsights = false, error = failure.readableMessage(localized)) }
            }
        }
    }

    fun refreshPets() = loadPets()

    private fun loadPets() {
        _state.update { it.copy(petsUi = it.petsUi.copy(loading = true)) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.petdex() to api.activePet() } }
                .onSuccess { (pets, active) ->
                    _state.update { it.copy(petsUi = it.petsUi.copy(loading = false, actionSlug = null, pets = pets, active = active)) }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(petsUi = it.petsUi.copy(loading = false, actionSlug = null), error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun adoptPet(slug: String) {
        _state.update { it.copy(petsUi = it.petsUi.copy(actionSlug = slug), error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.adoptPet(slug) } }
                .onSuccess { active ->
                    _state.update {
                        it.copy(petsUi = it.petsUi.copy(actionSlug = null, active = active), notice = str(R.string.pets_adopted))
                    }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(petsUi = it.petsUi.copy(actionSlug = null), error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun setActivePet(enabled: Boolean? = null, scale: Double? = null) {
        val slug = _state.value.petsUi.active?.slug ?: return
        _state.update { it.copy(petsUi = it.petsUi.copy(actionSlug = slug), error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.updateActivePet(enabled, scale) } }
                .onSuccess { active ->
                    _state.update { it.copy(petsUi = it.petsUi.copy(actionSlug = null, active = active)) }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(petsUi = it.petsUi.copy(actionSlug = null), error = failure.readableMessage(localized))
                    }
                }
        }
    }

    // ── settings ──────────────────────────────────────────────────────────

    // ── settings groups ───────────────────────────────────────────────────

    fun openSettingsGroup(group: SettingsGroup) {
        _state.update {
            it.copy(
                screen = Screen.SettingsGroup,
                openGroup = group,
                toolReturnScreen = when (it.screen) {
                    Screen.AgentHub -> Screen.AgentHub
                    Screen.MoreSettings -> Screen.MoreSettings
                    else -> Screen.Settings
                },
                error = null,
                notice = null,
                loadingAgentSettings = group == SettingsGroup.Agent,
                loadingStudioSettings = group in STUDIO_CONFIG_GROUPS,
                loadingAccountSettings = group == SettingsGroup.Account,
                loadingManagedUsers = group == SettingsGroup.Users,
                loadingModelProviders = group == SettingsGroup.Models,
            )
        }
        if (group == SettingsGroup.Agent) loadAgentSettings()
        if (group == SettingsGroup.Profile) loadModels()
        if (group in STUDIO_CONFIG_GROUPS) loadStudioSettings()
        if (group == SettingsGroup.Account) loadAccountSettings()
        if (group == SettingsGroup.Users) loadManagedUsers()
        if (group == SettingsGroup.Models) loadModelProviders()
    }

    private fun loadStudioSettings(showLoading: Boolean = true) {
        val profile = currentProfile()
        if (showLoading) _state.update { it.copy(loadingStudioSettings = true) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.studioSettings(profile) } }
                .onSuccess { settings ->
                    _state.update { it.copy(studioSettings = settings, loadingStudioSettings = false) }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(loadingStudioSettings = false, error = failure.readableMessage(localized))
                    }
                }
        }
    }

    /** Saves a partial Studio config section so untouched keys remain unchanged. */
    fun setStudioValue(section: String, key: String, value: Any) {
        saveStudioSection(section, org.json.JSONObject().put(key, value))
    }

    fun saveProxy(https: String, http: String, all: String, noProxy: String) {
        saveStudioSection(
            "proxy",
            org.json.JSONObject()
                .put("HTTPS_PROXY", https.trim())
                .put("HTTP_PROXY", http.trim())
                .put("ALL_PROXY", all.trim())
                .put("NO_PROXY", noProxy.trim()),
        )
    }

    private fun saveStudioSection(section: String, values: org.json.JSONObject) {
        val profile = currentProfile()
        _state.update { it.copy(savingSetting = true, error = null, notice = null) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    // Studio restarts the gateway for proxy and protected-action
                    // approval changes so those values take effect immediately.
                    api.updateConfigSection(
                        profile,
                        section,
                        values,
                        restart = section == "proxy" || section == "approvals",
                    )
                }
            }.onSuccess {
                _state.update { it.copy(savingSetting = false, notice = str(R.string.notice_saved)) }
                loadStudioSettings(showLoading = false)
            }.onFailure { failure ->
                _state.update { it.copy(savingSetting = false, error = failure.readableMessage(localized)) }
            }
        }
    }

    private fun loadAccountSettings() {
        _state.update { it.copy(loadingAccountSettings = true) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    val user = api.currentUser()
                    AccountSettingsData(user, api.lockedIps(), api.myAvatar(user.username))
                }
            }.onSuccess { (user, locks, avatar) ->
                _state.update {
                    it.copy(
                        account = user.username,
                        currentUser = user,
                        lockedIps = locks,
                        accountAvatar = avatar,
                        loadingAccountSettings = false,
                    )
                }
            }.onFailure { failure ->
                _state.update {
                    it.copy(loadingAccountSettings = false, error = failure.readableMessage(localized))
                }
            }
        }
    }

    fun changeAccountPassword(currentPassword: String, newPassword: String) {
        accountWork { api.changePassword(currentPassword, newPassword) }
    }

    fun changeAccountUsername(currentPassword: String, newUsername: String) {
        accountWork {
            api.changeUsername(currentPassword, newUsername)
            loadAccountSettings()
        }
    }

    fun setAccountAvatar(bytes: ByteArray, mime: String) {
        if (mime !in setOf("image/png", "image/jpeg", "image/webp")) {
            _state.update { it.copy(error = str(R.string.account_avatar_invalid_type)) }
            return
        }
        if (bytes.size > 1024 * 1024) {
            _state.update { it.copy(error = str(R.string.account_avatar_too_large)) }
            return
        }
        accountWork {
            val encoded = android.util.Base64.encodeToString(bytes, android.util.Base64.NO_WRAP)
            api.updateMyAvatar("data:$mime;base64,$encoded")
            loadAccountSettings()
        }
    }

    fun randomizeAccountAvatar() = accountWork {
        val seed = "${_state.value.account.orEmpty()}-${System.currentTimeMillis()}-${java.util.UUID.randomUUID()}"
        val svg = MultiAvatar.svg(getApplication(), seed)
        val encoded = android.util.Base64.encodeToString(svg.toByteArray(), android.util.Base64.NO_WRAP)
        api.updateMyAvatar("data:image/svg+xml;base64,$encoded", seed)
        loadAccountSettings()
    }

    fun resetAccountAvatar() = accountWork {
        api.resetMyAvatar()
        loadAccountSettings()
    }

    fun unlockIp(ip: String) = accountWork {
        api.unlockIp(ip)
        loadAccountSettings()
    }

    fun unlockAllIps() = accountWork {
        api.unlockAllIps()
        loadAccountSettings()
    }

    private fun accountWork(block: suspend () -> Unit) {
        _state.update { it.copy(savingSetting = true, error = null, notice = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { block() } }
                .onSuccess { _state.update { it.copy(savingSetting = false, notice = str(R.string.notice_saved)) } }
                .onFailure { failure ->
                    _state.update { it.copy(savingSetting = false, error = failure.readableMessage(localized)) }
                }
        }
    }

    private fun loadManagedUsers() {
        _state.update { it.copy(loadingManagedUsers = true) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.managedUsers() } }
                .onSuccess { result ->
                    _state.update {
                        it.copy(
                            managedUsers = result.users,
                            managedProfiles = result.profiles,
                            loadingManagedUsers = false,
                        )
                    }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(loadingManagedUsers = false, error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun saveManagedUser(existingId: Int?, draft: ManagedUserDraft) {
        _state.update { it.copy(savingSetting = true, error = null, notice = null) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    if (existingId == null) api.createManagedUser(draft)
                    else api.updateManagedUser(existingId, draft)
                }
            }.onSuccess {
                _state.update { it.copy(savingSetting = false, notice = str(R.string.notice_saved)) }
                loadManagedUsers()
            }.onFailure { failure ->
                _state.update { it.copy(savingSetting = false, error = failure.readableMessage(localized)) }
            }
        }
    }

    fun deleteManagedUser(user: ManagedUser) {
        _state.update { it.copy(savingSetting = true, error = null, notice = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.deleteManagedUser(user.id) } }
                .onSuccess {
                    _state.update { it.copy(savingSetting = false, notice = str(R.string.notice_saved)) }
                    loadManagedUsers()
                }
                .onFailure { failure ->
                    _state.update { it.copy(savingSetting = false, error = failure.readableMessage(localized)) }
                }
        }
    }

    private fun loadModelProviders() {
        val profile = currentProfile()
        _state.update { it.copy(loadingModelProviders = true) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.modelProviders(profile) } }
                .onSuccess { providers ->
                    _state.update { it.copy(modelProviders = providers, loadingModelProviders = false) }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(loadingModelProviders = false, error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun saveProviderKey(provider: String, key: String) {
        val profile = currentProfile()
        _state.update { it.copy(savingSetting = true, error = null, notice = null) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) { api.updateProviderApiKey(profile, provider, key.trim()) }
            }.onSuccess {
                _state.update { it.copy(savingSetting = false, notice = str(R.string.notice_saved)) }
                loadModelProviders()
            }.onFailure { failure ->
                _state.update { it.copy(savingSetting = false, error = failure.readableMessage(localized)) }
            }
        }
    }

    private fun loadAgentSettings() {
        val profile = _state.value.activeProfile.ifBlank { "default" }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) { api.agentSettings(profile) to api.autoStartPolicy() }
            }.onSuccess { (agent, policy) ->
                _state.update {
                    it.copy(agentSettings = agent, autoStart = policy, loadingAgentSettings = false)
                }
            }.onFailure { failure ->
                _state.update {
                    it.copy(loadingAgentSettings = false, error = failure.readableMessage(localized))
                }
            }
        }
    }

    /** Writes one agent knob; the server keeps the rest of the section as it is. */
    fun setAgentValue(key: String, value: Any) {
        val profile = _state.value.activeProfile.ifBlank { "default" }
        _state.update { it.copy(savingSetting = true, error = null, notice = null) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    api.updateConfigSection(profile, "agent", org.json.JSONObject().put(key, value))
                }
            }.onSuccess {
                _state.update { it.copy(savingSetting = false, notice = str(R.string.notice_saved)) }
                loadAgentSettings()
            }.onFailure { failure ->
                _state.update { it.copy(savingSetting = false, error = failure.readableMessage(localized)) }
            }
        }
    }

    fun setAutoStart(policy: AutoStartPolicy) {
        val previous = _state.value.autoStart
        _state.update { it.copy(autoStart = policy, savingSetting = true, error = null, notice = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.setAutoStartPolicy(policy) } }
                .onSuccess {
                    _state.update { it.copy(savingSetting = false, notice = str(R.string.notice_saved)) }
                    loadAgentSettings()
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(savingSetting = false, autoStart = previous, error = failure.readableMessage(localized))
                    }
                }
        }
    }

    // ── scheduled jobs ──────────────────────────────────────────────────

    fun openCronJobs() {
        _state.update {
            it.copy(
                screen = Screen.CronJobs,
                toolReturnScreen = when (it.screen) {
                    Screen.AgentHub -> Screen.AgentHub
                    Screen.MoreSettings -> Screen.MoreSettings
                    else -> Screen.Settings
                },
                error = null,
                notice = null,
                editingCronJob = null,
                cronEditorJobId = null,
                openCronRun = null,
            )
        }
        refreshCronJobs()
    }

    fun refreshCronJobs() {
        if (_state.value.cronLoading) return
        val profile = _state.value.activeProfile.ifBlank { "default" }
        _state.update { it.copy(cronLoading = true, error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.cronJobs(profile) } }
                .onSuccess { jobs ->
                    _state.update {
                        it.copy(cronJobs = jobs.sortedBy { job -> job.name.lowercase() }, cronLoading = false)
                    }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(cronLoading = false, error = failure.readableMessage(localized))
                    }
                }
        }
    }

    /** Opens a blank editor, or reloads one raw job before editing it. */
    fun openCronJob(jobId: String? = null) {
        val profile = _state.value.activeProfile.ifBlank { "default" }
        _state.update {
            it.copy(
                screen = Screen.CronJob,
                editingCronJob = null,
                cronEditorJobId = jobId,
                cronEditorLoading = true,
                error = null,
                notice = null,
            )
        }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    CronEditorData(
                        job = jobId?.let { api.cronJob(profile, it) },
                        // These enrich the form, but a missing optional endpoint
                        // must not make the core job impossible to edit.
                        models = runCatching { api.availableModels(profile) }.getOrDefault(emptyList()),
                        skills = runCatching { api.cronSkills(profile) }.getOrDefault(emptyList()),
                        targets = runCatching { api.cronDeliveryTargets(profile) }.getOrDefault(emptyList()),
                    )
                }
            }.onSuccess { data ->
                _state.update {
                    it.copy(
                        editingCronJob = data.job,
                        models = data.models,
                        modelsProfile = profile,
                        cronSkills = data.skills,
                        cronDeliveryTargets = data.targets,
                        cronEditorLoading = false,
                    )
                }
            }.onFailure { failure ->
                _state.update {
                    it.copy(cronEditorLoading = false, error = failure.readableMessage(localized))
                }
            }
        }
    }

    fun saveCronJob(draft: CronJobDraft) {
        if (_state.value.savingSetting) return
        if (draft.name.isBlank()) {
            _state.update { it.copy(error = str(R.string.cron_name_required)) }
            return
        }
        if (draft.schedule.isBlank()) {
            _state.update { it.copy(error = str(R.string.cron_schedule_required)) }
            return
        }
        if (draft.prompt.isBlank()) {
            _state.update { it.copy(error = str(R.string.cron_prompt_required)) }
            return
        }
        if (draft.repeatTimes != null && draft.repeatTimes < 1) {
            _state.update { it.copy(error = str(R.string.cron_repeat_invalid)) }
            return
        }

        val profile = _state.value.activeProfile.ifBlank { "default" }
        val original = _state.value.editingCronJob
        _state.update { it.copy(savingSetting = true, error = null, notice = null) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    if (original == null) api.createCronJob(profile, draft)
                    else api.updateCronJob(profile, original, draft)
                }
            }.onSuccess { saved ->
                _state.update {
                    it.copy(
                        screen = Screen.CronJobs,
                        savingSetting = false,
                        editingCronJob = null,
                        cronEditorJobId = null,
                        cronJobs = it.cronJobs.upsert(saved),
                        notice = str(
                            if (original == null) R.string.cron_notice_created else R.string.cron_notice_updated,
                        ),
                    )
                }
            }.onFailure { failure ->
                _state.update {
                    it.copy(savingSetting = false, error = failure.readableMessage(localized))
                }
            }
        }
    }

    fun toggleCronJob(job: CronJob) {
        if (_state.value.cronActionId != null) return
        val profile = _state.value.activeProfile.ifBlank { "default" }
        val resume = job.state == "paused" || !job.enabled
        _state.update { it.copy(cronActionId = job.id, error = null, notice = null) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    if (resume) api.resumeCronJob(profile, job.id) else api.pauseCronJob(profile, job.id)
                }
            }.onSuccess { updated ->
                _state.update {
                    it.copy(
                        cronActionId = null,
                        cronJobs = it.cronJobs.upsert(updated),
                        notice = str(if (resume) R.string.cron_notice_resumed else R.string.cron_notice_paused),
                    )
                }
            }.onFailure { failure ->
                _state.update {
                    it.copy(cronActionId = null, error = failure.readableMessage(localized))
                }
            }
        }
    }

    fun runCronJob(job: CronJob) {
        if (_state.value.cronActionId != null) return
        val profile = _state.value.activeProfile.ifBlank { "default" }
        _state.update { it.copy(cronActionId = job.id, error = null, notice = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.runCronJob(profile, job.id) } }
                .onSuccess { updated ->
                    _state.update {
                        it.copy(
                            cronActionId = null,
                            cronJobs = it.cronJobs.upsert(updated),
                            notice = str(R.string.cron_notice_triggered),
                        )
                    }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(cronActionId = null, error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun deleteCronJob(job: CronJob) {
        if (_state.value.cronActionId != null) return
        val profile = _state.value.activeProfile.ifBlank { "default" }
        _state.update { it.copy(cronActionId = job.id, error = null, notice = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.deleteCronJob(profile, job.id) } }
                .onSuccess {
                    _state.update {
                        it.copy(
                            cronActionId = null,
                            cronJobs = it.cronJobs.filterNot { candidate -> candidate.id == job.id },
                            notice = str(R.string.cron_notice_deleted),
                        )
                    }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(cronActionId = null, error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun openCronHistory(job: CronJob) {
        _state.update {
            it.copy(
                screen = Screen.CronHistory,
                cronHistoryJob = job,
                cronRuns = emptyList(),
                openCronRun = null,
                error = null,
                notice = null,
            )
        }
        refreshCronHistory()
    }

    fun refreshCronHistory() {
        val job = _state.value.cronHistoryJob ?: return
        if (_state.value.cronHistoryLoading) return
        val profile = _state.value.activeProfile.ifBlank { "default" }
        _state.update { it.copy(cronHistoryLoading = true, error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.cronRuns(profile, job.id) } }
                .onSuccess { runs ->
                    _state.update { it.copy(cronRuns = runs, cronHistoryLoading = false) }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(cronHistoryLoading = false, error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun openCronRun(run: CronRun) {
        if (_state.value.cronRunLoading) return
        val profile = _state.value.activeProfile.ifBlank { "default" }
        _state.update { it.copy(cronRunLoading = true, openCronRun = null, error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.cronRun(profile, run) } }
                .onSuccess { detail ->
                    _state.update { it.copy(cronRunLoading = false, openCronRun = detail) }
                }
                .onFailure { failure ->
                    _state.update {
                        it.copy(cronRunLoading = false, error = failure.readableMessage(localized))
                    }
                }
        }
    }

    fun dismissCronRun() = _state.update { it.copy(openCronRun = null) }

    // ── channels ──────────────────────────────────────────────────────────

    fun openChannels() {
        _state.update {
            it.copy(
                screen = Screen.Channels,
                toolReturnScreen = when (it.screen) {
                    Screen.AgentHub -> Screen.AgentHub
                    Screen.MoreSettings -> Screen.MoreSettings
                    else -> Screen.Settings
                },
                error = null,
                notice = null,
            )
        }
        refreshServerConfig()
    }

    /** Settings itself only needs the channel counts and the default model. */
    fun openSettings() {
        _state.update { it.copy(screen = Screen.Settings, error = null, notice = null, openGroup = null) }
        refreshServerConfig()
    }

    fun openProfiles() {
        _state.update { state ->
            val parent = when (state.screen) {
                Screen.Chats, Screen.Groups, Screen.AgentHub,
                Screen.Settings, Screen.SettingsGroup, Screen.MoreSettings,
                -> state.screen
                else -> when (state.tab) {
                    Tab.Groups -> Screen.Groups
                    Tab.Agent -> Screen.AgentHub
                    Tab.Chats -> Screen.Chats
                }
            }
            state.copy(
                screen = Screen.Profiles,
                profilesReturnScreen = parent,
                error = null,
                notice = null,
            )
        }
    }

    fun openMoreSettings() {
        _state.update { it.copy(screen = Screen.MoreSettings, error = null, notice = null, openGroup = null) }
    }

    fun openChannel(platform: String) {
        _state.update {
            it.copy(
                screen = Screen.Channel,
                openChannel = platform,
                weixinQr = if (platform == "weixin") it.weixinQr else WeixinQrUi(),
                error = null,
                notice = null,
            )
        }
    }

    /** Completes Weixin's Studio QR flow without leaving the native editor. */
    fun startWeixinQr() {
        val profile = _state.value.activeProfile.ifBlank { "default" }
        weixinQrJob?.cancel()
        _state.update { it.copy(weixinQr = WeixinQrUi(status = "loading"), error = null, notice = null) }
        weixinQrJob = viewModelScope.launch {
            val code = runCatching { withContext(Dispatchers.IO) { api.weixinQrCode(profile) } }
                .getOrElse { failure ->
                    _state.update {
                        it.copy(weixinQr = WeixinQrUi(status = "error"), error = failure.readableMessage(localized))
                    }
                    return@launch
                }
            _state.update {
                it.copy(weixinQr = WeixinQrUi(status = "waiting", id = code.id, url = code.url))
            }

            repeat(100) {
                delay(3_000)
                val poll = runCatching {
                    withContext(Dispatchers.IO) { api.weixinQrStatus(profile, code.id) }
                }.getOrNull() ?: return@repeat
                when (poll.status) {
                    "confirmed" -> {
                        runCatching {
                            withContext(Dispatchers.IO) { api.saveWeixinCredentials(profile, poll) }
                        }.onSuccess {
                            _state.update {
                                it.copy(
                                    weixinQr = WeixinQrUi(status = "confirmed", id = code.id),
                                    notice = str(R.string.notice_weixin_linked),
                                )
                            }
                            refreshServerConfig()
                        }.onFailure { failure ->
                            _state.update {
                                it.copy(
                                    weixinQr = WeixinQrUi(status = "error", id = code.id),
                                    error = failure.readableMessage(localized),
                                )
                            }
                        }
                        return@launch
                    }
                    "expired" -> {
                        _state.update { it.copy(weixinQr = WeixinQrUi(status = "expired", id = code.id)) }
                        return@launch
                    }
                    "scaned", "scaned_but_redirect" -> _state.update {
                        it.copy(weixinQr = it.weixinQr.copy(status = "scanned"))
                    }
                    else -> Unit
                }
            }
            _state.update { it.copy(weixinQr = WeixinQrUi(status = "expired", id = code.id)) }
        }
    }

    private fun refreshServerConfig() {
        val profile = _state.value.activeProfile.ifBlank { "default" }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.serverConfig(profile) } }
                .onSuccess { config ->
                    _state.update { it.copy(serverConfig = config, defaultModel = config.defaultModel) }
                }
                .onFailure { failure -> _state.update { it.copy(error = failure.readableMessage(localized)) } }
        }
    }

    /**
     * Writes a channel's credentials. The server restarts the gateway itself
     * once they land, which is what actually puts the channel online.
     */
    fun saveChannel(platform: String, values: Map<String, String>, enabled: Boolean) {
        val profile = _state.value.activeProfile.ifBlank { "default" }
        val spec = channelSpec(platform)
        val label = spec.label
        _state.update { it.copy(savingSetting = true, error = null, notice = null) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    val credentials = linkedMapOf<String, Any?>()
                    val configuration = org.json.JSONObject()

                    fun putNested(target: org.json.JSONObject, path: String, value: Any?) {
                        val parts = path.split('.')
                        var current = target
                        parts.dropLast(1).forEach { part ->
                            current = current.optJSONObject(part)
                                ?: org.json.JSONObject().also { current.put(part, it) }
                        }
                        current.put(parts.last(), value ?: org.json.JSONObject.NULL)
                    }

                    spec.fields.forEach { field ->
                        val raw = values[field.path].orEmpty()
                        val value: Any = when (field.kind) {
                            ChannelFieldKind.Toggle -> raw.toBooleanStrictOrNull() ?: field.defaultEnabled
                            ChannelFieldKind.CommaList -> org.json.JSONArray().apply {
                                raw.split(',').map(String::trim).filter(String::isNotEmpty).forEach(::put)
                            }
                            ChannelFieldKind.Text, ChannelFieldKind.Secret -> raw.trim()
                        }
                        if (field.target == ChannelFieldTarget.Credentials) credentials[field.path] = value
                        else putNested(configuration, field.path, value)
                    }

                    // WhatsApp owns its enablement through WHATSAPP_ENABLED.
                    // Other adapters retain the convenient app-level switch.
                    if (spec.fields.none {
                            it.target == ChannelFieldTarget.Credentials && it.path == "enabled"
                        }
                    ) {
                        configuration.put("enabled", enabled)
                    }

                    if (configuration.length() > 0) {
                        api.updateConfigSection(
                            profile,
                            platform,
                            configuration,
                            restart = credentials.isEmpty(),
                        )
                    }
                    if (credentials.isNotEmpty()) {
                        // Empty strings are intentional: Studio uses them to clear
                        // one incorrect value without deleting every credential.
                        api.updateChannelCredentials(profile, platform, credentials)
                    }
                }
            }.onSuccess {
                _state.update {
                    it.copy(savingSetting = false, notice = str(R.string.notice_channel_saved, label))
                }
                refreshServerConfig()
            }.onFailure { failure ->
                _state.update { it.copy(savingSetting = false, error = failure.readableMessage(localized)) }
            }
        }
    }

    fun clearChannel(platform: String) {
        val profile = _state.value.activeProfile.ifBlank { "default" }
        val label = channelSpec(platform).label
        _state.update { it.copy(savingSetting = true, error = null, notice = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.clearChannelCredentials(profile, platform) } }
                .onSuccess {
                    _state.update {
                        it.copy(savingSetting = false, notice = str(R.string.notice_channel_cleared, label))
                    }
                    refreshServerConfig()
                }
                .onFailure { failure ->
                    _state.update { it.copy(savingSetting = false, error = failure.readableMessage(localized)) }
                }
        }
    }

    /** Whether the gateway comes up with the server, written server-side. */
    fun setGatewayAutoStart(enabled: Boolean) {
        val profile = _state.value.activeProfile.ifBlank { "default" }
        val previous = _state.value.serverConfig
        _state.update { it.copy(serverConfig = previous?.copy(gatewayAutoStart = enabled), savingSetting = true) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) {
                    api.updateConfigSection(
                        profile,
                        "gatewayAutoStart",
                        org.json.JSONObject().put("enabled", enabled),
                    )
                }
            }.onSuccess {
                _state.update { it.copy(savingSetting = false, notice = str(R.string.notice_saved)) }
            }.onFailure { failure ->
                _state.update {
                    it.copy(savingSetting = false, serverConfig = previous, error = failure.readableMessage(localized))
                }
            }
        }
    }

    /** Writes the profile default, which is what new conversations start from. */
    fun setDefaultModel(option: ModelOption) {
        val profile = _state.value.activeProfile.ifBlank { "default" }
        _state.update { it.copy(savingSetting = true, error = null, notice = null) }
        viewModelScope.launch {
            runCatching {
                withContext(Dispatchers.IO) { api.setDefaultModel(profile, option.id, option.provider) }
            }.onSuccess {
                _state.update {
                    it.copy(
                        savingSetting = false,
                        defaultModel = option.id,
                        notice = str(R.string.notice_default_model, profile, option.id),
                    )
                }
            }.onFailure { failure ->
                _state.update { it.copy(savingSetting = false, error = failure.readableMessage(localized)) }
            }
        }
    }

    fun restartGateway() {
        val profile = _state.value.activeProfile.ifBlank { "default" }
        _state.update { it.copy(savingSetting = true, error = null, notice = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { api.restartGateway(profile) } }
                .onSuccess {
                    _state.update {
                        it.copy(savingSetting = false, notice = str(R.string.notice_gateway_restarting, profile))
                    }
                }
                .onFailure { failure ->
                    _state.update { it.copy(savingSetting = false, error = failure.readableMessage(localized)) }
                }
        }
    }

    /** Replaces the app mark with a picture from the device. */
    fun setAppLogo(bytes: ByteArray) {
        viewModelScope.launch {
            val applied = AppLogo.setCustom(getApplication<Application>(), bytes)
            _state.update {
                if (applied) it.copy(notice = str(R.string.notice_logo_updated), error = null)
                else it.copy(error = str(R.string.error_image_unreadable))
            }
        }
    }

    /** Goes back to whatever logo the connected Studio serves. */
    fun resetAppLogo() {
        viewModelScope.launch {
            AppLogo.clearCustom(getApplication<Application>())
            runCatching { AppLogo.syncFromServer(getApplication<Application>(), api, force = true) }
            _state.update {
                if (AppLogo.image != null) {
                    it.copy(notice = str(R.string.notice_logo_from_server), error = null)
                } else {
                    it.copy(error = str(R.string.error_no_server_logo))
                }
            }
        }
    }

    fun dismissNotice() = _state.update { it.copy(notice = null) }

    // ── misc ──────────────────────────────────────────────────────────────

    fun back() {
        when (_state.value.screen) {
            // Leaving a conversation only detaches this phone. The explicit
            // stop button is the action that aborts an agent run on Studio.
            Screen.Conversation -> cancelActiveRun(abort = false)
            Screen.Room -> leaveRoom()
            else -> Unit
        }
        _state.update { state ->
            val target = when (state.screen) {
                Screen.Channel -> Screen.Channels
                Screen.CronJob, Screen.CronHistory -> Screen.CronJobs
                Screen.KanbanTask -> Screen.Kanban
                Screen.Skill -> Screen.Skills
                Screen.Kanban, Screen.Skills, Screen.Plugins, Screen.Mcp, Screen.Pets, Screen.Insights, Screen.AgentRuntimes, Screen.Workflows, Screen.GlobalAgent, Screen.EkkoHub, Screen.Files, Screen.Logs, Screen.Connections, Screen.Journey, Screen.Webhooks, Screen.RuntimeVersions, Screen.Appearance -> Screen.AgentHub
                Screen.Channels, Screen.SettingsGroup, Screen.CronJobs -> state.toolReturnScreen
                Screen.Profiles -> state.profilesReturnScreen
                Screen.MoreSettings -> Screen.Settings
                else -> when (state.tab) {
                    Tab.Groups -> Screen.Groups
                    Tab.Agent -> Screen.AgentHub
                    Tab.Chats -> Screen.Chats
                }
            }
            state.copy(
                screen = target,
                error = null,
                openSession = state.openSession.takeUnless { state.screen == Screen.Conversation },
                openRoom = state.openRoom.takeUnless { state.screen == Screen.Room },
                attachments = if (state.screen == Screen.Conversation) emptyList() else state.attachments,
                sessionModel = state.sessionModel.takeUnless { state.screen == Screen.Conversation },
                sessionProvider = state.sessionProvider.takeUnless { state.screen == Screen.Conversation },
                editingCronJob = state.editingCronJob.takeUnless { state.screen == Screen.CronJob },
                cronEditorJobId = state.cronEditorJobId.takeUnless { state.screen == Screen.CronJob },
                openCronRun = null,
                kanban = state.kanban.copy(
                    openTask = state.kanban.openTask.takeUnless { state.screen == Screen.KanbanTask },
                ),
                skillsUi = state.skillsUi.copy(
                    openSkill = state.skillsUi.openSkill.takeUnless { state.screen == Screen.Skill },
                ),
            )
        }
    }

    fun show(screen: Screen) = _state.update { it.copy(screen = screen, error = null) }

    fun dismissError() = _state.update { it.copy(error = null) }

    /** Lets device pickers surface a readable error without leaking UI concerns into them. */
    fun showToolError(failure: Throwable) = _state.update {
        it.copy(error = failure.readableMessage(localized))
    }

    fun signOut() {
        cancelActiveRun(abort = true)
        leaveRoom()
        store.clearCredentials()
        _state.update {
            UiState(
                screen = Screen.Login,
                baseUrl = store.baseUrl,
                reasoningEffort = store.reasoningEffort,
                language = store.language,
                appearance = store.appearance,
            )
        }
    }

    /** Chooses the language for every screen; the activity restarts to apply it. */
    fun setLanguage(tag: String) {
        store.language = tag
        _state.update { it.copy(language = tag) }
    }

    fun setAppearance(value: String) {
        store.appearance = value
        _state.update { it.copy(appearance = value) }
    }

    private fun str(id: Int, vararg args: Any): String = localized.getString(id, *args)

    private fun currentProfile(): String =
        _state.value.openSession?.profile?.ifBlank { null }
            ?: _state.value.activeProfile.ifBlank { "default" }

    private fun uniqueQueuedDownloadName(requested: String): String {
        val clean = inferDownloadFileName(requested, requested)
        if (queuedDownloadNames.add(clean)) return clean
        val dot = clean.lastIndexOf('.').takeIf { it > 0 }
        val stem = dot?.let(clean::substring) ?: clean
        val extension = dot?.let { clean.substring(it) }.orEmpty()
        var suffix = System.currentTimeMillis()
        while (true) {
            val candidate = "$stem-$suffix$extension"
            if (queuedDownloadNames.add(candidate)) return candidate
            suffix += 1
        }
    }

    private fun pickProfile(profiles: List<Profile>): String {
        val stored = store.profile
        if (stored.isNotBlank() && profiles.any { it.name == stored }) return stored
        val chosen = profiles.firstOrNull { it.active }?.name
            ?: profiles.firstOrNull()?.name
            ?: "default"
        store.profile = chosen
        return chosen
    }

    private fun <T> launchWork(
        work: suspend () -> T,
        onSuccess: (T) -> Unit,
        onFailure: ((Throwable) -> Unit)? = null,
    ) {
        _state.update { it.copy(busy = true, error = null) }
        viewModelScope.launch {
            runCatching { withContext(Dispatchers.IO) { work() } }
                .onSuccess {
                    _state.update { state -> state.copy(busy = false) }
                    onSuccess(it)
                }
                .onFailure { failure ->
                    _state.update { state -> state.copy(busy = false) }
                    if (onFailure != null) onFailure(failure)
                    else _state.update { state -> state.copy(error = failure.readableMessage(localized)) }
                }
        }
    }

    private fun normalizeUrl(raw: String): String? {
        val trimmed = raw.trim().trimEnd('/')
        if (trimmed.isBlank()) return null
        val withScheme = if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
            trimmed
        } else {
            "https://$trimmed"
        }
        return runCatching { java.net.URL(withScheme) }.map { withScheme }.getOrNull()
    }
}

private val STUDIO_CONFIG_GROUPS = setOf(
    SettingsGroup.Display,
    SettingsGroup.Proxy,
    SettingsGroup.Memory,
    SettingsGroup.Compression,
    SettingsGroup.Sessions,
    SettingsGroup.Privacy,
)

private data class CronEditorData(
    val job: CronJob?,
    val models: List<ModelOption>,
    val skills: List<String>,
    val targets: List<CronDeliveryTarget>,
)

private fun List<CronJob>.upsert(job: CronJob): List<CronJob> =
    (filterNot { it.id == job.id } + job).sortedBy { it.name.lowercase() }

private val INVITE_ALPHABET = ('A'..'Z') + ('2'..'9')

internal fun Throwable.invalidatesSavedSession(): Boolean =
    (this as? HermesException)?.statusCode in setOf(401, 403)

private fun Throwable.readableMessage(context: android.content.Context): String = when (this) {
    // A HermesException already carries what the server said, in its own words.
    is HermesException -> message ?: context.getString(R.string.error_request_failed)
    is java.net.UnknownHostException -> context.getString(R.string.error_unreachable)
    is java.net.SocketTimeoutException -> context.getString(R.string.error_timeout)
    is javax.net.ssl.SSLException -> context.getString(R.string.error_tls)
    else -> message ?: this::class.java.simpleName
}
