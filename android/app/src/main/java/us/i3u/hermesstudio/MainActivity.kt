package us.i3u.hermesstudio

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.InsertDriveFile
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Rule
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AttachFile
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.AccountTree
import androidx.compose.material.icons.filled.Cable
import androidx.compose.material.icons.filled.Compress
import androidx.compose.material.icons.filled.DisplaySettings
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.HourglassBottom
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Insights
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material.icons.filled.ModelTraining
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.PrivacyTip
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.VpnLock
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.RestartAlt
import androidx.compose.material.icons.filled.Dns
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.PowerSettingsNew
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Extension
import androidx.compose.material.icons.filled.Pets
import androidx.compose.material.icons.filled.School
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.ViewKanban
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.AssistChip
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.ui.res.painterResource
import androidx.compose.material.ExperimentalMaterialApi
import androidx.compose.material.pullrefresh.PullRefreshIndicator
import androidx.compose.material.pullrefresh.pullRefresh
import androidx.compose.material.pullrefresh.rememberPullRefreshState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.core.content.FileProvider
import java.io.File
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.compose.runtime.rememberCoroutineScope
import java.util.Locale

class MainActivity : ComponentActivity() {

    /** Applies the language chosen in Settings before any screen is built. */
    override fun attachBaseContext(newBase: Context) {
        super.attachBaseContext(AppLocale.wrap(newBase))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { App() }
    }
}

@Composable
private fun App(viewModel: AppViewModel = viewModel()) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var availableUpdate by remember { mutableStateOf<AvailableUpdate?>(null) }
    var downloadingUpdate by remember { mutableStateOf(false) }
    var updateError by remember { mutableStateOf<Int?>(null) }

    LaunchedEffect(Unit) { availableUpdate = runCatching { AppUpdater.check() }.getOrNull() }

    HermesTheme(appearance = state.appearance) {
        Surface(modifier = Modifier.fillMaxSize()) {
            AppContent(state, viewModel)
        }
        availableUpdate?.let { update ->
            AlertDialog(
                onDismissRequest = { if (!downloadingUpdate) availableUpdate = null },
                title = { Text(stringResource(R.string.update_available_title)) },
                text = {
                    Text(
                        stringResource(
                            updateError ?: if (downloadingUpdate) R.string.update_downloading else R.string.update_available_body,
                        ),
                    )
                },
                confirmButton = {
                    TextButton(
                        enabled = !downloadingUpdate,
                        onClick = {
                            scope.launch {
                                downloadingUpdate = true
                                updateError = null
                                runCatching { AppUpdater.download(context, update) }
                                    .onSuccess { apk ->
                                        downloadingUpdate = false
                                        if (AppUpdater.install(context, apk) == InstallResult.PermissionRequired) {
                                            updateError = R.string.update_permission
                                        }
                                    }
                                    .onFailure {
                                        downloadingUpdate = false
                                        updateError = R.string.update_failed
                                    }
                            }
                        },
                    ) { Text(stringResource(R.string.update_install)) }
                },
                dismissButton = {
                    TextButton(
                        enabled = !downloadingUpdate,
                        onClick = { availableUpdate = null },
                    ) { Text(stringResource(R.string.update_later)) }
                },
            )
        }
    }
}

@Composable
private fun AppContent(state: UiState, viewModel: AppViewModel) {

    // The system back gesture belongs to the app while there is somewhere to go
    // back to. Only the two root lists let it fall through and close the app.
    when (state.screen) {
        Screen.Conversation, Screen.Room, Screen.Profiles, Screen.Settings,
        Screen.MoreSettings, Screen.SettingsGroup, Screen.Channels, Screen.Channel, Screen.CronJobs,
        Screen.CronJob, Screen.CronHistory, Screen.Kanban, Screen.KanbanTask, Screen.Skills,
        Screen.Skill, Screen.Plugins, Screen.Mcp, Screen.Pets, Screen.Insights,
        -> BackHandler { viewModel.back() }
        Screen.Groups, Screen.AgentHub -> BackHandler { viewModel.showTab(Tab.Chats) }
        else -> Unit
    }

    when (state.screen) {
        Screen.Loading -> LoadingScreen(
            baseUrl = state.baseUrl,
            error = state.error,
            busy = state.busy,
            onRetry = { viewModel.retrySession() },
            onSignOut = { viewModel.signOut() },
        )
        Screen.Onboarding -> OnboardingScreen(
            languageAction = { LanguageAction(state, viewModel) },
            onDone = { viewModel.finishOnboarding() },
        )
        Screen.Settings -> SettingsScreen(state, viewModel)
        Screen.MoreSettings -> MoreSettingsScreen(state, viewModel)
        Screen.SettingsGroup -> SettingsGroupScreen(state, viewModel)
        Screen.Channels -> ChannelsScreen(state, viewModel)
        Screen.Channel -> ChannelScreen(state, viewModel)
        Screen.CronJobs -> CronJobsScreen(state, viewModel)
        Screen.CronJob -> CronJobEditorScreen(state, viewModel)
        Screen.CronHistory -> CronHistoryScreen(state, viewModel)
        Screen.Kanban -> KanbanScreen(state, viewModel)
        Screen.KanbanTask -> KanbanTaskScreen(state, viewModel)
        Screen.Skills -> SkillsScreen(state, viewModel)
        Screen.Skill -> SkillScreen(state, viewModel)
        Screen.Plugins -> PluginsScreen(state, viewModel)
        Screen.Mcp -> McpScreen(state, viewModel)
        Screen.Pets -> PetsScreen(state, viewModel)
        Screen.Insights -> InsightsScreen(state, viewModel)
        Screen.Login -> LoginScreen(state, viewModel)
        Screen.Chats -> ChatsScreen(state, viewModel)
        Screen.Groups -> GroupsScreen(state, viewModel)
        Screen.AgentHub -> AgentHubScreen(state, viewModel)
        Screen.Conversation -> ConversationScreen(state, viewModel)
        Screen.Room -> RoomScreen(state, viewModel)
        Screen.Profiles -> ProfilesScreen(state, viewModel)
    }
}

// ── login ────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LoginScreen(state: UiState, viewModel: AppViewModel) {
    var url by rememberSaveable { mutableStateOf(state.baseUrl) }
    var username by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }

    Scaffold(
        topBar = {
            StudioTopBar(
                title = stringResource(R.string.app_name),
                actions = { LanguageAction(state, viewModel) },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(20.dp)
                .imePadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(stringResource(R.string.login_title), style = MaterialTheme.typography.titleMedium)
            OutlinedTextField(
                value = url,
                onValueChange = { url = it },
                label = { Text(stringResource(R.string.login_server_label)) },
                placeholder = { Text(stringResource(R.string.login_server_hint)) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = username,
                onValueChange = { username = it },
                label = { Text(stringResource(R.string.login_username)) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text(stringResource(R.string.login_password)) },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                modifier = Modifier.fillMaxWidth(),
            )
            Button(
                onClick = { viewModel.login(url, username, password) },
                enabled = !state.busy,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(stringResource(if (state.busy) R.string.login_submitting else R.string.login_submit))
            }
            state.error?.let { ErrorNote(it) { viewModel.dismissError() } }
            Text(
                stringResource(R.string.login_note),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

// ── conversation list ────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class, ExperimentalMaterialApi::class)
@Composable
private fun ChatsScreen(state: UiState, viewModel: AppViewModel) {
    var manage by remember { mutableStateOf<SessionSummary?>(null) }
    var rename by remember { mutableStateOf<SessionSummary?>(null) }
    var confirmDelete by remember { mutableStateOf<SessionSummary?>(null) }
    var query by rememberSaveable { mutableStateOf("") }
    val visibleSessions = remember(state.sessions, query) {
        val clean = query.trim()
        if (clean.isBlank()) state.sessions else state.sessions.filter {
            it.title.contains(clean, true) ||
                it.profile.orEmpty().contains(clean, true) ||
                it.model.orEmpty().contains(clean, true)
        }
    }
    val pullRefreshState = rememberPullRefreshState(
        refreshing = state.refreshingSessions,
        onRefresh = viewModel::refreshSessions,
    )

    manage?.let { session ->
        ModalBottomSheet(
            onDismissRequest = { manage = null },
            sheetState = rememberModalBottomSheetState(),
        ) {
            SheetTitle(session.title)
            ManageSheet(
                onRename = {
                    manage = null
                    rename = session
                },
                onDelete = {
                    manage = null
                    confirmDelete = session
                },
            )
        }
    }
    rename?.let { session ->
        TextPromptDialog(
            title = stringResource(R.string.chats_rename_title),
            initial = session.title,
            hint = session.title,
            action = stringResource(R.string.action_rename),
            onConfirm = { viewModel.renameSession(session, it) },
            onDismiss = { rename = null },
        )
    }
    confirmDelete?.let { session ->
        ConfirmDialog(
            title = stringResource(R.string.chats_delete_title),
            body = stringResource(R.string.chats_delete_body),
            action = stringResource(R.string.action_delete),
            onConfirm = { viewModel.deleteSession(session) },
            onDismiss = { confirmDelete = null },
        )
    }

    Scaffold(
        topBar = {
            StudioLargeTopBar(
                title = stringResource(R.string.chats_title),
                navigationIcon = {
                    IconButton(onClick = { viewModel.openProfiles() }) {
                        ProfileAvatar(
                            name = state.activeProfile.ifBlank { "default" },
                            spec = state.avatarOf(state.activeProfile),
                            size = 34.dp,
                        )
                    }
                },
                actions = {
                    IconButton(
                        onClick = { viewModel.refreshSessions() },
                        enabled = !state.refreshingSessions,
                    ) {
                        Icon(Icons.Filled.Refresh, contentDescription = stringResource(R.string.action_refresh), tint = MaterialTheme.colorScheme.primary)
                    }
                    IconButton(onClick = { viewModel.startNewConversation() }) {
                        Icon(Icons.Filled.Edit, contentDescription = stringResource(R.string.action_new_chat), tint = MaterialTheme.colorScheme.primary)
                    }
                },
            )
        },
        bottomBar = { StudioTabs(state, viewModel) },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .pullRefresh(pullRefreshState),
        ) {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = StudioHorizontalPadding, end = StudioHorizontalPadding, top = 8.dp, bottom = 28.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item { ProfileFilterRow(state, viewModel) }
                item {
                    StudioSearchField(
                        value = query,
                        onValueChange = { query = it },
                        placeholder = stringResource(R.string.action_search),
                    )
                }
                if (state.busy) item { LoadingRow() }
                state.error?.let { message -> item { ErrorNote(message) { viewModel.dismissError() } } }
                if (!state.busy && visibleSessions.isEmpty()) {
                    item { EmptyNote(stringResource(R.string.chats_empty)) }
                } else if (visibleSessions.isNotEmpty()) {
                    item {
                        StudioGroupedCard {
                            visibleSessions.forEachIndexed { index, session ->
                                SessionRow(
                                    session = session,
                                    avatar = state.avatarOf(session.profile),
                                    onClick = { viewModel.openSession(session) },
                                    onLongClick = { manage = session },
                                )
                                if (index != visibleSessions.lastIndex) StudioCardDivider(startIndent = 76)
                            }
                        }
                    }
                }
            }
            PullRefreshIndicator(
                refreshing = state.refreshingSessions,
                state = pullRefreshState,
                modifier = Modifier.align(Alignment.TopCenter),
                backgroundColor = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun SessionRow(
    session: SessionSummary,
    avatar: AvatarSpec?,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .padding(horizontal = 14.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ProfileAvatar(
            name = session.profile.orEmpty().ifBlank { "default" },
            spec = avatar,
            size = 48.dp,
        )
        Spacer(Modifier.width(12.dp))
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(text = session.title, modifier = Modifier.weight(1f), maxLines = 2, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.width(8.dp))
                Text(
                    text = formatStamp(session.updatedAt),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                text = listOfNotNull(session.profile, session.model).joinToString(" · "),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Icon(
            Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
        )
    }
}

/** The avatar Studio shows for a profile, or null when it is not loaded yet. */
private fun UiState.avatarOf(profile: String?): AvatarSpec? {
    val name = profile?.ifBlank { null } ?: activeProfile
    return profiles.firstOrNull { it.name == name }?.avatar
}

@Composable
private fun ProfileFilterRow(state: UiState, viewModel: AppViewModel) {
    var open by remember { mutableStateOf(false) }
    val label = state.profileFilter.ifBlank { stringResource(R.string.chats_all_profiles) }

    Box {
        StudioGroupedCard {
            Row(
                modifier = Modifier.fillMaxWidth().clickable { open = true }.padding(horizontal = 16.dp, vertical = 15.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.Tune, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.width(12.dp))
                Text(label, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.width(5.dp))
                Icon(Icons.Filled.KeyboardArrowDown, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
                Spacer(Modifier.weight(1f))
                Text(
                    "${state.sessions.size} ${stringResource(R.string.chats_section)}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            DropdownMenuItem(
                text = { Text(stringResource(R.string.chats_all_profiles)) },
                onClick = {
                    open = false
                    viewModel.setProfileFilter("")
                },
            )
            state.profiles.forEach { profile ->
                DropdownMenuItem(
                    text = { Text(profile.name) },
                    onClick = {
                        open = false
                        viewModel.setProfileFilter(profile.name)
                    },
                )
            }
        }
    }
}

// ── group rooms ──────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
private fun GroupsScreen(state: UiState, viewModel: AppViewModel) {
    var creating by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf<Room?>(null) }

    if (creating) {
        NewRoomDialog(
            profiles = state.profiles.map { it.name },
            onCreate = { name, agents -> viewModel.createRoom(name, agents) },
            onDismiss = { creating = false },
        )
    }
    confirmDelete?.let { room ->
        ConfirmDialog(
            title = stringResource(R.string.groups_delete_title),
            body = stringResource(R.string.groups_delete_body),
            action = stringResource(R.string.action_delete),
            onConfirm = { viewModel.deleteRoom(room) },
            onDismiss = { confirmDelete = null },
        )
    }

    Scaffold(
        topBar = {
            StudioLargeTopBar(
                title = stringResource(R.string.groups_title),
                actions = {
                    IconButton(onClick = { viewModel.refreshRooms() }) {
                        Icon(Icons.Filled.Refresh, contentDescription = stringResource(R.string.action_refresh), tint = MaterialTheme.colorScheme.primary)
                    }
                    IconButton(onClick = { creating = true }) {
                        Icon(Icons.Filled.Add, contentDescription = stringResource(R.string.groups_new), tint = MaterialTheme.colorScheme.primary)
                    }
                },
            )
        },
        bottomBar = { StudioTabs(state, viewModel) },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(start = StudioHorizontalPadding, end = StudioHorizontalPadding, top = 8.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (state.busy) item { LoadingRow() }
            state.error?.let { message -> item { ErrorNote(message) { viewModel.dismissError() } } }
            if (!state.busy && state.rooms.isEmpty()) {
                item { EmptyNote(stringResource(R.string.groups_empty)) }
            } else if (state.rooms.isNotEmpty()) {
                item {
                    StudioGroupedCard {
                        state.rooms.forEachIndexed { index, room ->
                            RoomRow(
                                room = room,
                                onClick = { viewModel.openRoom(room) },
                                onLongClick = { confirmDelete = room },
                            )
                            if (index != state.rooms.lastIndex) StudioCardDivider(startIndent = 78)
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun RoomRow(room: Room, onClick: () -> Unit, onLongClick: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .padding(horizontal = 14.dp, vertical = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier.size(50.dp).clip(RoundedCornerShape(15.dp)).background(
                Brush.linearGradient(listOf(MaterialTheme.colorScheme.primary, Color(0xFF4389FF))),
            ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.Groups, contentDescription = null, tint = Color.White)
        }
        Spacer(Modifier.width(13.dp))
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(room.name, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.titleMedium)
                formatStamp(room.updatedAt).takeIf { it.isNotBlank() }?.let { stamp ->
                    Text(stamp, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            if (room.agentCount != null && room.memberCount != null) {
                Text(
                    stringResource(R.string.groups_counts, room.agentCount, room.memberCount),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f))
    }
}

/** Name the room, and choose which agents are in it. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun NewRoomDialog(
    profiles: List<String>,
    onCreate: (String, List<String>) -> Unit,
    onDismiss: () -> Unit,
) {
    var name by remember { mutableStateOf("") }
    val chosen = remember { mutableStateListOf<String>() }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.groups_new)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    placeholder = { Text(stringResource(R.string.groups_new_hint)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                Text(
                    stringResource(R.string.groups_pick_agents),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    profiles.forEach { profile ->
                        val selected = profile in chosen
                        AssistChip(
                            onClick = { if (selected) chosen.remove(profile) else chosen.add(profile) },
                            label = { Text(profile) },
                            leadingIcon = if (selected) {
                                { Icon(Icons.Filled.Check, contentDescription = null, modifier = Modifier.size(16.dp)) }
                            } else {
                                null
                            },
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                enabled = name.isNotBlank(),
                onClick = {
                    onDismiss()
                    onCreate(name.trim(), chosen.toList())
                },
            ) { Text(stringResource(R.string.action_create)) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_cancel)) } },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RoomScreen(state: UiState, viewModel: AppViewModel) {
    val room = state.openRoom
    var draft by rememberSaveable { mutableStateOf("") }
    val listState = rememberLazyListState()

    LaunchedEffect(room?.messages?.size) {
        val count = room?.messages?.size ?: 0
        if (count > 0) listState.animateScrollToItem(count - 1)
    }

    Scaffold(
        topBar = {
            StudioTopBar(
                title = room?.name ?: stringResource(R.string.room_title),
                subtitle = listOfNotNull(
                    room?.agents?.takeIf { it.isNotEmpty() }?.joinToString(", "),
                    stringResource(if (state.roomLive) R.string.room_live else R.string.room_offline),
                ).joinToString(" · "),
                onBack = { viewModel.back() },
            )
        },
        bottomBar = { StudioTabs(state, viewModel) },
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).imePadding()) {
            if (state.loadingHistory) LoadingRow()
            state.error?.let { ErrorNote(it) { viewModel.dismissError() } }
            val messages = room?.messages.orEmpty()
            if (!state.loadingHistory && messages.isEmpty()) {
                Box(
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        stringResource(R.string.room_empty),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            LazyColumn(
                state = listState,
                modifier = (if (messages.isEmpty()) Modifier else Modifier.weight(1f)).fillMaxWidth(),
                contentPadding = PaddingValues(12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(messages) { message ->
                    MessageBubble(
                        ChatLine(
                            text = message.content,
                            fromUser = !message.isAgent && message.sender == state.account,
                            timestamp = message.timestamp,
                            sender = message.sender,
                        ),
                        profile = message.sender.takeIf { message.isAgent },
                        avatar = state.avatarOf(message.sender.takeIf { message.isAgent }),
                    )
                }
            }

            // Rooms have no REST endpoint for posting: this rides the socket.
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 6.dp),
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                OutlinedTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    placeholder = { Text(stringResource(R.string.room_hint)) },
                    modifier = Modifier.weight(1f),
                    maxLines = 4,
                    shape = RoundedCornerShape(20.dp),
                )
                Box(
                    modifier = Modifier
                        .padding(bottom = 4.dp)
                        .size(46.dp)
                        .clip(RoundedCornerShape(23.dp))
                        .background(
                            if (draft.isNotBlank()) {
                                MaterialTheme.colorScheme.primary
                            } else {
                                MaterialTheme.colorScheme.surfaceVariant
                            },
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    IconButton(
                        onClick = {
                            if (viewModel.postToRoom(draft)) draft = ""
                        },
                        enabled = draft.isNotBlank(),
                    ) {
                        Icon(
                            Icons.AutoMirrored.Filled.Send,
                            contentDescription = stringResource(R.string.composer_send),
                            tint = if (draft.isNotBlank()) {
                                MaterialTheme.colorScheme.onPrimary
                            } else {
                                MaterialTheme.colorScheme.onSurface
                            },
                        )
                    }
                }
            }
        }
    }
}

// ── conversation ─────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class, ExperimentalMaterialApi::class)
@Composable
private fun ConversationScreen(state: UiState, viewModel: AppViewModel) {
    var draft by rememberSaveable { mutableStateOf("") }
    val listState = rememberLazyListState()
    val conversationKey = state.openSession?.id ?: "new"
    var reachedInitialBottom by remember(conversationKey) { mutableStateOf(false) }

    LaunchedEffect(conversationKey, state.loadingHistory, state.lines.size) {
        if (!state.loadingHistory && state.lines.isNotEmpty()) {
            val last = state.lines.lastIndex
            if (!reachedInitialBottom) {
                // A huge offset is intentionally clamped by LazyColumn to the
                // real end, including when the final message is taller than the
                // viewport. Animation from the first message made old chats
                // appear to open at the top.
                listState.scrollToItem(last, Int.MAX_VALUE / 2)
                reachedInitialBottom = true
            } else {
                listState.animateScrollToItem(last, Int.MAX_VALUE / 2)
            }
        }
    }

    LaunchedEffect(state.transcript) {
        state.transcript?.let { text ->
            draft = if (draft.isBlank()) text else "$draft $text"
            viewModel.consumeTranscript()
        }
    }

    val profile = state.openSession?.profile ?: state.activeProfile
    val avatar = state.avatarOf(profile)
    val pullRefreshState = rememberPullRefreshState(
        refreshing = state.loadingHistory,
        onRefresh = { viewModel.refreshConversation() },
    )
    Scaffold(
        // The composer applies the IME inset itself. Scaffold's default system
        // bottom inset would otherwise be added above the keyboard as a second,
        // empty navigation-bar-sized strip.
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            StudioTopBar(
                title = state.openSession?.title ?: stringResource(R.string.action_new_chat),
                subtitle = listOfNotNull(profile.ifBlank { null }, state.openSession?.model)
                    .joinToString(" · ")
                    .ifBlank { null },
                leading = {
                    ProfileAvatar(profile.ifBlank { "default" }, avatar, size = 32.dp)
                },
                onBack = { viewModel.back() },
                actions = {
                    if (state.openSession != null) {
                        IconButton(
                            onClick = { viewModel.refreshConversation() },
                            enabled = !state.loadingHistory,
                        ) {
                            Icon(
                                Icons.Filled.Refresh,
                                contentDescription = stringResource(R.string.action_refresh),
                                tint = MaterialTheme.colorScheme.primary,
                            )
                        }
                    }
                    IconButton(onClick = { viewModel.startNewConversation() }) {
                        Icon(
                            Icons.Filled.Add,
                            contentDescription = stringResource(R.string.action_new_chat),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                },
            )
        },
        bottomBar = { StudioTabs(state, viewModel) },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .imePadding(),
        ) {
            Box(
                modifier = Modifier.weight(1f).fillMaxWidth().pullRefresh(pullRefreshState),
            ) {
                if (state.lines.isEmpty() && !state.loadingHistory) {
                    Text(
                        stringResource(
                            R.string.conversation_empty,
                            profile.ifBlank { stringResource(R.string.conversation_your_agent) },
                        ),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.align(Alignment.Center),
                    )
                } else {
                LazyColumn(
                    state = listState,
                        modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.lines) { line ->
                        MessageBubble(
                            line = line,
                            profile = profile.ifBlank { "default" },
                            avatar = avatar,
                            onDownload = { file ->
                                viewModel.downloadChatFile(file, profile.ifBlank { "default" })
                            },
                        )
                    }
                }
                }
                PullRefreshIndicator(
                    refreshing = state.loadingHistory,
                    state = pullRefreshState,
                    modifier = Modifier.align(Alignment.TopCenter),
                    backgroundColor = MaterialTheme.colorScheme.surface,
                    contentColor = MaterialTheme.colorScheme.primary,
                )
            }

            if (state.sending && state.lines.none { it.streaming }) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(14.dp))
                    Text(
                        state.activity?.let { stringResource(R.string.conversation_tool, it) }
                            ?: stringResource(R.string.conversation_thinking),
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }

            state.error?.let { ErrorNote(it) { viewModel.dismissError() } }
            state.notice?.let { NoticeNote(it) { viewModel.dismissNotice() } }

            Composer(
                state = state,
                draft = draft,
                onDraftChange = { draft = it },
                onSend = {
                    viewModel.send(draft)
                    draft = ""
                },
                viewModel = viewModel,
            )
        }
    }
}

@Composable
private fun MessageBubble(
    line: ChatLine,
    profile: String? = null,
    avatar: AvatarSpec? = null,
    onDownload: ((ChatFileLink) -> Unit)? = null,
) {
    val parsed = remember(line.text, onDownload != null) {
        if (onDownload == null) ParsedChatMessage(line.text, emptyList()) else parseChatMessage(line.text)
    }
    val alignment = if (line.fromUser) Alignment.CenterEnd else Alignment.CenterStart
    val hasThinking = !line.fromUser && (
        line.streaming || line.reasoning?.isNotBlank() == true || line.tools.isNotEmpty()
    )
    val wide = !line.fromUser || hasThinking || parsed.files.isNotEmpty()
    val container = when {
        line.isError -> MaterialTheme.colorScheme.errorContainer
        line.fromUser -> MaterialTheme.colorScheme.primaryContainer
        else -> MaterialTheme.colorScheme.surfaceVariant
    }
    Box(modifier = Modifier.fillMaxWidth(), contentAlignment = alignment) {
        Row(
            modifier = if (wide) Modifier.fillMaxWidth() else Modifier,
            verticalAlignment = if (wide) Alignment.Top else Alignment.Bottom,
        ) {
            // The agent's picture rides with its own replies, the way Studio
            // shows it in the transcript.
            if (!line.fromUser && !profile.isNullOrBlank()) {
                ProfileAvatar(profile, avatar, size = 26.dp)
                Spacer(Modifier.width(8.dp))
            }
            Card(
                modifier = if (wide) Modifier.weight(1f) else Modifier,
                colors = CardDefaults.cardColors(containerColor = container),
            ) {
                Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    line.sender?.let {
                        Text(
                            it,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    if (hasThinking) ThinkingTimeline(line)
                    if (parsed.text.isNotBlank()) {
                        if (line.fromUser) Text(text = parsed.text) else ChatMarkdownText(text = parsed.text)
                    }
                    parsed.files.forEach { file ->
                        ChatFileCard(file = file, onDownload = { onDownload?.invoke(file) })
                    }
                    val stamp = formatStamp(line.timestamp)
                    if (stamp.isNotBlank()) {
                        Text(
                            stamp,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ChatFileCard(file: ChatFileLink, onDownload: () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onDownload),
        color = MaterialTheme.colorScheme.surface,
        shape = RoundedCornerShape(10.dp),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(9.dp),
        ) {
            Icon(
                Icons.AutoMirrored.Filled.InsertDriveFile,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
            )
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    file.label,
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                if (file.fileName != file.label) {
                    Text(
                        file.fileName,
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontFamily = FontFamily.Monospace,
                            textDirection = TextDirection.Ltr,
                        ),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            IconButton(onClick = onDownload) {
                Icon(
                    Icons.Filled.Download,
                    contentDescription = stringResource(R.string.download_action),
                    tint = MaterialTheme.colorScheme.primary,
                )
            }
        }
    }
}

@Composable
private fun ThinkingTimeline(line: ChatLine) {
    var expandedOverride by rememberSaveable(line.startedAtMillis) { mutableStateOf<Boolean?>(null) }
    val hasDetails = line.tools.isNotEmpty() || !line.reasoning.isNullOrBlank()
    val expanded = expandedOverride ?: line.streaming
    val nowMillis = timelineNow(line)
    val elapsed = line.startedAtMillis?.let { formatElapsed(nowMillis - it) }

    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .then(
                    if (hasDetails) Modifier.clickable { expandedOverride = !expanded }
                    else Modifier,
                )
                .padding(vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            if (line.streaming) {
                CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
            } else {
                Icon(
                    Icons.Filled.Psychology,
                    contentDescription = null,
                    modifier = Modifier.size(17.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                stringResource(R.string.thinking_title),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
            )
            elapsed?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.bodySmall.copy(
                        fontFamily = FontFamily.Monospace,
                        textDirection = TextDirection.Ltr,
                    ),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.weight(1f))
            if (hasDetails) {
                Icon(
                    if (expanded) Icons.Filled.KeyboardArrowUp else Icons.Filled.KeyboardArrowDown,
                    contentDescription = stringResource(
                        if (expanded) R.string.thinking_collapse else R.string.thinking_expand,
                    ),
                    modifier = Modifier.size(18.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        if (expanded) {
            Column(
                modifier = Modifier.padding(top = 7.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                line.tools.forEach { tool -> ToolStepRow(tool, nowMillis) }
                line.reasoning?.takeIf { it.isNotBlank() }?.let { reasoning ->
                    Surface(
                        color = MaterialTheme.colorScheme.surface,
                        shape = RoundedCornerShape(9.dp),
                    ) {
                        Text(
                            reasoning,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(horizontal = 9.dp, vertical = 8.dp),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ToolStepRow(tool: ChatToolStep, nowMillis: Long) {
    val seconds = tool.durationSeconds ?: if (tool.status == ToolRunStatus.Running) {
        (nowMillis - tool.startedAtMillis).coerceAtLeast(0) / 1000.0
    } else {
        null
    }
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surface,
        shape = RoundedCornerShape(9.dp),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 9.dp, vertical = 7.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Icon(
                Icons.Filled.Build,
                contentDescription = null,
                modifier = Modifier.size(16.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    tool.name,
                    style = MaterialTheme.typography.bodySmall.copy(
                        fontFamily = FontFamily.Monospace,
                        textDirection = TextDirection.Ltr,
                    ),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                tool.detail?.takeIf { it.isNotBlank() }?.let { detail ->
                    Text(
                        detail,
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontFamily = FontFamily.Monospace,
                            textDirection = TextDirection.Ltr,
                        ),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            seconds?.let {
                Text(
                    formatToolDuration(it),
                    style = MaterialTheme.typography.labelSmall.copy(
                        fontFamily = FontFamily.Monospace,
                        textDirection = TextDirection.Ltr,
                    ),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            when (tool.status) {
                ToolRunStatus.Running -> CircularProgressIndicator(
                    modifier = Modifier.size(15.dp),
                    strokeWidth = 2.dp,
                )
                ToolRunStatus.Done -> Icon(
                    Icons.Filled.Check,
                    contentDescription = stringResource(R.string.tool_status_done),
                    modifier = Modifier.size(17.dp),
                    tint = androidx.compose.ui.graphics.Color(0xFF67C650),
                )
                ToolRunStatus.Error -> Icon(
                    Icons.Filled.Close,
                    contentDescription = stringResource(R.string.tool_status_failed),
                    modifier = Modifier.size(17.dp),
                    tint = MaterialTheme.colorScheme.error,
                )
            }
        }
    }
}

@Composable
private fun timelineNow(line: ChatLine): Long {
    var now by remember(line.startedAtMillis, line.finishedAtMillis) {
        mutableLongStateOf(line.finishedAtMillis ?: System.currentTimeMillis())
    }
    LaunchedEffect(line.streaming, line.finishedAtMillis) {
        if (!line.streaming) {
            now = line.finishedAtMillis ?: System.currentTimeMillis()
            return@LaunchedEffect
        }
        while (true) {
            now = System.currentTimeMillis()
            delay(1_000)
        }
    }
    return line.finishedAtMillis ?: now
}

private fun formatElapsed(milliseconds: Long): String {
    val totalSeconds = (milliseconds.coerceAtLeast(0) / 1000).toInt()
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return if (minutes == 0) "${seconds}s" else "${minutes}m${seconds.toString().padStart(2, '0')}s"
}

private fun formatToolDuration(seconds: Double): String = when {
    seconds < 10 -> String.format(Locale.US, "%.1fs", seconds)
    seconds < 60 -> "${seconds.toInt()}s"
    else -> "${(seconds / 60).toInt()}m${(seconds.toInt() % 60).toString().padStart(2, '0')}s"
}

// ── profiles ─────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
private fun ProfilesScreen(state: UiState, viewModel: AppViewModel) {
    var confirmSignOut by remember { mutableStateOf(false) }
    var manage by remember { mutableStateOf<Profile?>(null) }
    var rename by remember { mutableStateOf<Profile?>(null) }
    var confirmDelete by remember { mutableStateOf<Profile?>(null) }
    var creating by remember { mutableStateOf(false) }

    manage?.let { profile ->
        ModalBottomSheet(
            onDismissRequest = { manage = null },
            sheetState = rememberModalBottomSheetState(),
        ) {
            SheetTitle(profile.name)
            ManageSheet(
                onRename = {
                    manage = null
                    rename = profile
                },
                onDelete = {
                    manage = null
                    confirmDelete = profile
                },
            )
        }
    }
    rename?.let { profile ->
        TextPromptDialog(
            title = stringResource(R.string.profiles_rename_title),
            initial = profile.name,
            hint = profile.name,
            action = stringResource(R.string.action_rename),
            onConfirm = { viewModel.renameProfile(profile.name, it) },
            onDismiss = { rename = null },
        )
    }
    confirmDelete?.let { profile ->
        ConfirmDialog(
            title = stringResource(R.string.profiles_delete_title, profile.name),
            body = stringResource(R.string.profiles_delete_body),
            action = stringResource(R.string.action_delete),
            onConfirm = { viewModel.deleteProfile(profile.name) },
            onDismiss = { confirmDelete = null },
        )
    }
    if (creating) {
        TextPromptDialog(
            title = stringResource(R.string.profiles_new),
            initial = "",
            hint = stringResource(R.string.profiles_new_hint),
            action = stringResource(R.string.action_create),
            onConfirm = { viewModel.createProfile(it) },
            onDismiss = { creating = false },
        )
    }
    if (confirmSignOut) {
        ConfirmDialog(
            title = stringResource(R.string.confirm_sign_out_title),
            body = stringResource(R.string.confirm_sign_out_body),
            action = stringResource(R.string.action_sign_out),
            onConfirm = { viewModel.signOut() },
            onDismiss = { confirmSignOut = false },
        )
    }

    Scaffold(
        topBar = {
            StudioTopBar(
                title = stringResource(R.string.profiles_title),
                subtitle = state.account?.let { stringResource(R.string.profiles_signed_in, it) },
                onBack = { viewModel.back() },
                actions = {
                    IconButton(onClick = { creating = true }) {
                        Icon(Icons.Filled.Add, contentDescription = stringResource(R.string.profiles_new), tint = MaterialTheme.colorScheme.primary)
                    }
                    IconButton(onClick = { viewModel.refreshProfiles() }) {
                        Icon(Icons.Filled.Refresh, contentDescription = stringResource(R.string.action_refresh), tint = MaterialTheme.colorScheme.primary)
                    }
                    IconButton(onClick = { confirmSignOut = true }) {
                        Icon(Icons.AutoMirrored.Filled.Logout, contentDescription = stringResource(R.string.action_sign_out), tint = MaterialTheme.colorScheme.primary)
                    }
                },
            )
        },
        bottomBar = { StudioTabs(state, viewModel) },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(
                start = StudioHorizontalPadding,
                end = StudioHorizontalPadding,
                top = 12.dp,
                bottom = 28.dp,
            ),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (state.busy) item { LoadingRow() }
            state.error?.let { message -> item { ErrorNote(message) { viewModel.dismissError() } } }
            if (state.profiles.isNotEmpty()) {
                item {
                    StudioGroupedCard {
                        state.profiles.forEachIndexed { index, profile ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .combinedClickable(
                                onClick = { viewModel.selectProfile(profile.name) },
                                onLongClick = { manage = profile },
                            )
                            .padding(horizontal = 15.dp, vertical = 13.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        ProfileAvatar(profile.name, profile.avatar, size = 52.dp)
                        Spacer(Modifier.width(13.dp))
                        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Text(profile.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            Text(
                                profile.model ?: stringResource(R.string.profiles_no_model),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                        if (profile.name == state.activeProfile) {
                            Surface(
                                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
                                shape = RoundedCornerShape(50.dp),
                            ) {
                                Text(
                                    stringResource(R.string.profiles_active),
                                    modifier = Modifier.padding(horizontal = 9.dp, vertical = 5.dp),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.primary,
                                    fontWeight = FontWeight.SemiBold,
                                )
                            }
                        } else {
                            Icon(
                                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                            if (index != state.profiles.lastIndex) StudioCardDivider(startIndent = 80)
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
private fun Composer(
    state: UiState,
    draft: String,
    onDraftChange: (String) -> Unit,
    onSend: () -> Unit,
    viewModel: AppViewModel,
) {
    val context = LocalContext.current
    var sheet by remember { mutableStateOf<ComposerSheet?>(null) }
    var captureUri by remember { mutableStateOf<Uri?>(null) }

    val pickImage = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let { readAndAttach(context, it, viewModel) }
    }
    val pickFile = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let { readAndAttach(context, it, viewModel) }
    }
    val takePhoto = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { saved ->
        val uri = captureUri
        captureUri = null
        if (saved && uri != null) readAndAttach(context, uri, viewModel, fallbackName = "photo.jpg")
    }
    val askCamera = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            val uri = newCaptureUri(context)
            captureUri = uri
            takePhoto.launch(uri)
        }
    }
    val askMic = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) viewModel.startRecording()
    }

    when (sheet) {
        ComposerSheet.Options -> ModalBottomSheet(
            onDismissRequest = { sheet = null },
            sheetState = rememberModalBottomSheetState(),
        ) {
            OptionsSheet(
                state = state,
                onCamera = {
                    sheet = null
                    askCamera.launch(Manifest.permission.CAMERA)
                },
                onGallery = {
                    sheet = null
                    pickImage.launch("image/*")
                },
                onDocument = {
                    sheet = null
                    pickFile.launch("*/*")
                },
                onModel = {
                    viewModel.loadModels()
                    sheet = ComposerSheet.Model
                },
                onReasoning = { sheet = ComposerSheet.Reasoning },
            )
        }

        ComposerSheet.Model -> ModalBottomSheet(
            onDismissRequest = { sheet = null },
            sheetState = rememberModalBottomSheetState(),
        ) {
            PickerSheet(
                title = stringResource(R.string.sheet_model),
                loading = state.loadingModels,
                rows = state.models.map { option ->
                    PickerRow(
                        label = option.id,
                        detail = option.provider,
                        selected = option.id == state.sessionModel,
                    ) {
                        viewModel.selectModel(option)
                        sheet = null
                    }
                },
            )
        }

        ComposerSheet.Reasoning -> ModalBottomSheet(
            onDismissRequest = { sheet = null },
            sheetState = rememberModalBottomSheetState(),
        ) {
            PickerSheet(
                title = stringResource(R.string.sheet_reasoning),
                loading = false,
                rows = REASONING_LEVELS.map { (value, label) ->
                    PickerRow(
                        label = stringResource(label),
                        detail = if (value.isBlank()) stringResource(R.string.reasoning_use_profile) else null,
                        selected = value == state.reasoningEffort,
                    ) {
                        viewModel.setReasoningEffort(value)
                        sheet = null
                    }
                },
            )
        }

        null -> Unit
    }

    Column(modifier = Modifier.fillMaxWidth()) {
        if (state.attachments.isNotEmpty() || state.attaching) {
            FlowRow(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                state.attachments.forEach { file ->
                    AssistChip(
                        onClick = { viewModel.removeAttachment(file) },
                        label = { Text(file.name, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                        trailingIcon = { Icon(Icons.Filled.Close, contentDescription = stringResource(R.string.action_remove)) },
                    )
                }
                if (state.attaching) AssistChip(onClick = {}, label = { Text(stringResource(R.string.composer_uploading)) })
            }
        }

        if (state.recording || state.transcribing) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                CircularProgressIndicator(modifier = Modifier.size(14.dp))
                Text(
                    stringResource(if (state.recording) R.string.composer_recording else R.string.composer_transcribing),
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.weight(1f),
                )
                if (state.recording) {
                    TextButton(onClick = { viewModel.cancelRecording() }) { Text(stringResource(R.string.action_cancel)) }
                }
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            OutlinedTextField(
                value = draft,
                onValueChange = onDraftChange,
                placeholder = { Text(stringResource(R.string.composer_hint)) },
                modifier = Modifier.weight(1f),
                maxLines = 5,
                shape = RoundedCornerShape(20.dp),
            )
            SendOrRecordButton(state, draft, onSend, viewModel) {
                askMic.launch(Manifest.permission.RECORD_AUDIO)
            }
        }

        // Studio keeps its context controls on a row under the field.
        Row(
            modifier = Modifier.fillMaxWidth().padding(start = 10.dp, end = 10.dp, top = 2.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .clickable(enabled = !state.sending) { sheet = ComposerSheet.Options },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Filled.Add,
                    contentDescription = stringResource(R.string.composer_more),
                    tint = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.size(18.dp),
                )
            }
            ToolbarChip(
                icon = Icons.Filled.Psychology,
                label = reasoningLabel(state.reasoningEffort),
            ) {
                sheet = ComposerSheet.Reasoning
            }
            ToolbarChip(
                icon = Icons.Filled.ModelTraining,
                label = state.sessionModel ?: stringResource(R.string.sheet_model),
            ) {
                viewModel.loadModels()
                sheet = ComposerSheet.Model
            }
            Spacer(modifier = Modifier.weight(1f))
            ContextUsage(state)
        }
    }
}

@Composable
private fun ContextUsage(state: UiState) {
    val ratio = if (state.contextWindow > 0) {
        (state.contextTokens.toFloat() / state.contextWindow.toFloat()).coerceIn(0f, 1f)
    } else 0f
    val color = when {
        ratio > .8f -> MaterialTheme.colorScheme.error
        ratio > .6f -> Color(0xFFD59A2D)
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    Column(modifier = Modifier.widthIn(min = 84.dp, max = 122.dp)) {
        Text(
            if (state.loadingContext) stringResource(R.string.context_loading)
            else if (state.contextWindow > 0) stringResource(
                R.string.context_usage,
                compactNumber(state.contextTokens),
                compactNumber(state.contextWindow),
            ) else stringResource(R.string.context_unknown),
            style = MaterialTheme.typography.labelSmall,
            color = color,
            maxLines = 1,
        )
        LinearProgressIndicator(
            progress = { ratio },
            modifier = Modifier.fillMaxWidth().height(3.dp).clip(RoundedCornerShape(99.dp)),
            color = color,
            trackColor = MaterialTheme.colorScheme.outlineVariant,
        )
    }
}

private fun compactNumber(value: Long): String = when {
    value >= 1_000_000 -> "%.1fM".format(Locale.US, value / 1_000_000.0)
    value >= 1_000 -> "%.1fK".format(Locale.US, value / 1_000.0)
    else -> value.toString()
}.replace(".0", "")

private enum class ComposerSheet { Options, Model, Reasoning }

private val REASONING_LEVELS = listOf(
    "" to R.string.reasoning_default,
    "low" to R.string.reasoning_low,
    "medium" to R.string.reasoning_medium,
    "high" to R.string.reasoning_high,
    "xhigh" to R.string.reasoning_extra_high,
)

private val APPEARANCE_LEVELS = listOf(
    "system" to R.string.appearance_system,
    "light" to R.string.appearance_light,
    "dark" to R.string.appearance_dark,
)

@Composable
private fun reasoningLabel(effort: String): String = stringResource(
    REASONING_LEVELS.firstOrNull { it.first == effort }?.second ?: R.string.reasoning_default,
)

@Composable
private fun appearanceLabel(appearance: String): String = stringResource(
    APPEARANCE_LEVELS.firstOrNull { it.first == appearance }?.second ?: R.string.appearance_system,
)

private const val PHONE_REPOSITORY_URL = "https://github.com/twuijri/hermes-studio-mobile"
private const val STUDIO_REPOSITORY_URL = "https://github.com/EKKOLearnAI/hermes-studio"

@Composable
private fun SendOrRecordButton(
    state: UiState,
    draft: String,
    onSend: () -> Unit,
    viewModel: AppViewModel,
    onRecord: () -> Unit,
) {
    val hasPayload = draft.isNotBlank() || state.attachments.isNotEmpty()
    val background = if (hasPayload || state.recording || state.sending) {
        MaterialTheme.colorScheme.primary
    } else {
        MaterialTheme.colorScheme.surfaceVariant
    }
    val tint = if (hasPayload || state.recording || state.sending) {
        MaterialTheme.colorScheme.onPrimary
    } else {
        MaterialTheme.colorScheme.onSurface
    }

    Box(
        modifier = Modifier
            .padding(bottom = 4.dp)
            .size(46.dp)
            .clip(RoundedCornerShape(23.dp))
            .background(background),
        contentAlignment = Alignment.Center,
    ) {
        when {
            state.recording -> IconButton(onClick = { viewModel.stopRecordingAndTranscribe() }) {
                Icon(Icons.Filled.Stop, contentDescription = stringResource(R.string.composer_stop), tint = tint)
            }
            // A streaming run can be called off, so the button becomes a stop.
            state.sending -> IconButton(onClick = { viewModel.stopRun() }) {
                Icon(Icons.Filled.Stop, contentDescription = stringResource(R.string.conversation_stop), tint = tint)
            }
            hasPayload -> IconButton(onClick = onSend, enabled = !state.sending) {
                Icon(Icons.AutoMirrored.Filled.Send, contentDescription = stringResource(R.string.composer_send), tint = tint)
            }
            else -> IconButton(onClick = onRecord, enabled = !state.transcribing) {
                Icon(Icons.Filled.Mic, contentDescription = stringResource(R.string.composer_record), tint = tint)
            }
        }
    }
}

@Composable
private fun ToolbarChip(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 8.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(15.dp),
        )
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.widthIn(max = 150.dp),
        )
        Text("⌄", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** The "+" sheet: attachments first, then the per-conversation controls. */
@Composable
private fun OptionsSheet(
    state: UiState,
    onCamera: () -> Unit,
    onGallery: () -> Unit,
    onDocument: () -> Unit,
    onModel: () -> Unit,
    onReasoning: () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth().padding(bottom = 28.dp)) {
        SheetTitle(stringResource(R.string.sheet_add))
        Row(
            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            AttachOption(Icons.Filled.PhotoCamera, stringResource(R.string.sheet_camera), onCamera)
            AttachOption(Icons.Filled.Image, stringResource(R.string.sheet_gallery), onGallery)
            AttachOption(Icons.AutoMirrored.Filled.InsertDriveFile, stringResource(R.string.sheet_file), onDocument)
        }
        HorizontalDivider(color = MaterialTheme.colorScheme.outline)
        SheetTitle(stringResource(R.string.sheet_conversation))
        SheetRow(
            icon = Icons.Filled.ModelTraining,
            label = stringResource(R.string.sheet_model),
            detail = state.sessionModel ?: stringResource(R.string.sheet_profile_default),
            onClick = onModel,
        )
        SheetRow(
            icon = Icons.Filled.Psychology,
            label = stringResource(R.string.sheet_reasoning),
            detail = reasoningLabel(state.reasoningEffort),
            onClick = onReasoning,
        )
    }
}

private data class PickerRow(
    val label: String,
    val detail: String?,
    val selected: Boolean,
    val onClick: () -> Unit,
)

@Composable
private fun PickerSheet(title: String, loading: Boolean, rows: List<PickerRow>) {
    Column(modifier = Modifier.fillMaxWidth().padding(bottom = 28.dp)) {
        SheetTitle(title)
        if (loading) LoadingRow()
        if (!loading && rows.isEmpty()) {
            Text(
                stringResource(R.string.sheet_empty),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
            )
        }
        rows.forEach { row ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = row.onClick)
                    .padding(horizontal = 20.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(row.label, style = MaterialTheme.typography.bodyLarge)
                    row.detail?.let {
                        Text(
                            it,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                if (row.selected) {
                    Icon(Icons.Filled.Check, contentDescription = stringResource(R.string.action_selected))
                }
            }
        }
    }
}

@Composable
private fun SheetTitle(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp),
    )
}

@Composable
private fun SheetRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    detail: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
        Column(modifier = Modifier.weight(1f)) {
            Text(label, style = MaterialTheme.typography.bodyLarge)
            Text(
                detail,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Icon(
            Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun AttachOption(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier.clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(
            modifier = Modifier
                .size(54.dp)
                .clip(RoundedCornerShape(27.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = label, tint = MaterialTheme.colorScheme.onSurface)
        }
        Text(label, style = MaterialTheme.typography.labelMedium)
    }
}

/** Cache-backed target for a camera capture, shared through the FileProvider. */
private fun newCaptureUri(context: Context): Uri {
    val dir = File(context.cacheDir, "captures").apply { mkdirs() }
    val file = File(dir, "capture-${System.currentTimeMillis()}.jpg")
    return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
}

/** Reads a picked document through the content resolver and hands it to the upload. */
private fun readAndAttach(
    context: Context,
    uri: Uri,
    viewModel: AppViewModel,
    fallbackName: String? = null,
) {
    val resolver = context.contentResolver
    val mime = resolver.getType(uri) ?: if (fallbackName?.endsWith(".jpg") == true) "image/jpeg" else "application/octet-stream"
    var name = fallbackName ?: "attachment"
    runCatching {
        resolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) name = cursor.getString(index) ?: name
        }
    }
    val bytes = runCatching { resolver.openInputStream(uri)?.use { it.readBytes() } }.getOrNull()
    if (bytes == null || bytes.isEmpty()) return
    viewModel.attach(bytes, name, mime)
}

private enum class ConfirmAction { SignOut, RestartGateway }

/** One text field, one button: rename a thing, or name a new one. */
@Composable
internal fun TextPromptDialog(
    title: String,
    initial: String,
    hint: String,
    action: String,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    var value by remember { mutableStateOf(initial) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            OutlinedTextField(
                value = value,
                onValueChange = { value = it },
                placeholder = { Text(hint) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
        },
        confirmButton = {
            TextButton(
                enabled = value.isNotBlank(),
                onClick = {
                    onDismiss()
                    onConfirm(value.trim())
                },
            ) { Text(action) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_cancel)) }
        },
    )
}

/** The rename / delete pair, shared by conversations, profiles and rooms. */
@Composable
private fun ManageSheet(
    onRename: (() -> Unit)?,
    onDelete: () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth().padding(bottom = 28.dp)) {
        onRename?.let {
            SheetRow(
                icon = Icons.Filled.Edit,
                label = stringResource(R.string.action_rename),
                detail = "",
                onClick = it,
            )
        }
        SheetRow(
            icon = Icons.Filled.Delete,
            label = stringResource(R.string.action_delete),
            detail = "",
            onClick = onDelete,
        )
    }
}

/** Stands between a stray tap and something that cannot be undone. */
@Composable
internal fun ConfirmDialog(
    title: String,
    body: String,
    action: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = { Text(body) },
        confirmButton = {
            TextButton(
                onClick = {
                    onDismiss()
                    onConfirm()
                },
            ) { Text(action) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_cancel)) }
        },
    )
}

/**
 * Language is reachable before sign-in on purpose: someone who cannot read the
 * sign-in form cannot get to Settings to fix that.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LanguageSheet(state: UiState, viewModel: AppViewModel, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val activity = context as? Activity
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = rememberModalBottomSheetState()) {
        PickerSheet(
            title = stringResource(R.string.settings_language),
            loading = false,
            rows = APP_LANGUAGES.map { option ->
                PickerRow(
                    label = AppLocale.labelFor(context, option),
                    detail = null,
                    selected = option.tag == state.language,
                ) {
                    onDismiss()
                    viewModel.setLanguage(option.tag)
                    // Resources are resolved when the activity is built, so rebuild it.
                    activity?.recreate()
                }
            },
        )
    }
}

@Composable
private fun LanguageAction(state: UiState, viewModel: AppViewModel) {
    var open by remember { mutableStateOf(false) }
    val context = LocalContext.current
    if (open) LanguageSheet(state, viewModel) { open = false }

    TextButton(onClick = { open = true }) {
        Icon(
            Icons.Filled.Language,
            contentDescription = stringResource(R.string.settings_language),
            modifier = Modifier.size(17.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.width(6.dp))
        Text(
            AppLocale.currentEndonym(context, state.language),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

/** Agent work gets a first-class home instead of masquerading as app settings. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AgentHubScreen(state: UiState, viewModel: AppViewModel) {
    val channels = state.serverConfig?.channels.orEmpty()
    val profile = state.profiles.firstOrNull { it.name == state.activeProfile }
        ?: state.profiles.firstOrNull { it.active }
        ?: state.profiles.firstOrNull()
    val profileName = profile?.name ?: state.activeProfile.ifBlank { "default" }

    Scaffold(
        topBar = {
            StudioLargeTopBar(
                title = stringResource(R.string.agent_hub_title),
                navigationIcon = {
                    IconButton(onClick = { viewModel.openProfiles() }) {
                        ProfileAvatar(profileName, profile?.avatar, size = 34.dp)
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.openSettings() }) {
                        Icon(
                            Icons.Filled.Settings,
                            contentDescription = stringResource(R.string.action_settings),
                            tint = MaterialTheme.colorScheme.primary,
                        )
                    }
                },
            )
        },
        bottomBar = { StudioTabs(state, viewModel) },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(
                start = StudioHorizontalPadding,
                end = StudioHorizontalPadding,
                top = 8.dp,
                bottom = 28.dp,
            ),
        ) {
            state.error?.let { message -> item { ErrorNote(message) { viewModel.dismissError() } } }
            state.notice?.let { message -> item { NoticeNote(message) { viewModel.dismissNotice() } } }

            item {
                StudioGroupedCard {
                    Row(
                        modifier = Modifier.fillMaxWidth().clickable { viewModel.openProfiles() }
                            .padding(horizontal = 16.dp, vertical = 15.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        ProfileAvatar(profileName, profile?.avatar, size = 58.dp)
                        Spacer(Modifier.width(14.dp))
                        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(profileName, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                            Text(
                                profile?.model.orEmpty().ifBlank { stringResource(R.string.settings_default_model_server) },
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                        Surface(
                            color = Color(0xFF43C879).copy(alpha = 0.16f),
                            shape = RoundedCornerShape(50.dp),
                        ) {
                            Text(
                                if (profile?.active == true) stringResource(R.string.agent_status_active)
                                else stringResource(R.string.agent_status_ready),
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = Color(0xFF43C879),
                            )
                        }
                    }
                }
            }

            item { StudioSectionTitle(stringResource(R.string.agent_hub_work)) }
            item {
                StudioGroupedCard {
                    StudioDestinationRow(
                        icon = Icons.Filled.Schedule,
                        color = Color(0xFF4D8DFF),
                        title = stringResource(R.string.cron_title),
                        subtitle = stringResource(R.string.settings_group_cron_note),
                        onClick = { viewModel.openCronJobs() },
                    )
                    StudioCardDivider()
                    StudioDestinationRow(
                        icon = Icons.Filled.ViewKanban,
                        color = Color(0xFFFF9F43),
                        title = stringResource(R.string.agent_hub_kanban),
                        subtitle = stringResource(R.string.agent_hub_kanban_note),
                        onClick = { viewModel.openKanban() },
                    )
                    StudioCardDivider()
                    StudioDestinationRow(
                        icon = Icons.Filled.Forum,
                        color = Color(0xFF45C878),
                        title = stringResource(R.string.settings_channels),
                        subtitle = if (channels.isEmpty()) {
                            stringResource(R.string.settings_group_channels_note)
                        } else {
                            stringResource(
                                R.string.settings_channels_summary,
                                channels.count { it.configured },
                                channels.size.coerceAtLeast(CHANNELS.size),
                            )
                        },
                        onClick = { viewModel.openChannels() },
                    )
                }
            }

            item { StudioSectionTitle(stringResource(R.string.insights_title)) }
            item {
                StudioGroupedCard {
                    StudioDestinationRow(
                        icon = Icons.Filled.Insights,
                        color = Color(0xFF7A5CFF),
                        title = stringResource(R.string.insights_title),
                        subtitle = stringResource(R.string.insights_subtitle),
                        onClick = { viewModel.openInsights() },
                    )
                }
            }

            item { StudioSectionTitle(stringResource(R.string.agent_hub_capabilities)) }
            item {
                StudioGroupedCard {
                    StudioDestinationRow(Icons.Filled.School, Color(0xFF7A5CFF), stringResource(R.string.agent_hub_skills), stringResource(R.string.agent_hub_skills_note), { viewModel.openSkills() })
                    StudioCardDivider()
                    StudioDestinationRow(Icons.Filled.Extension, Color(0xFFB45CFF), stringResource(R.string.agent_hub_plugins), stringResource(R.string.agent_hub_plugins_note), { viewModel.openPlugins() })
                    StudioCardDivider()
                    StudioDestinationRow(Icons.Filled.Cable, Color(0xFF35B7DB), stringResource(R.string.agent_hub_mcp), stringResource(R.string.agent_hub_mcp_note), { viewModel.openMcp() })
                    StudioCardDivider()
                    StudioDestinationRow(Icons.Filled.Pets, Color(0xFFFF6584), stringResource(R.string.agent_hub_pets), stringResource(R.string.agent_hub_pets_note), { viewModel.openPets() })
                }
            }

            item { StudioSectionTitle(stringResource(R.string.agent_hub_intelligence)) }
            item {
                StudioGroupedCard {
                    StudioDestinationRow(Icons.Filled.Memory, Color(0xFFFFB547), stringResource(R.string.settings_group_memory), stringResource(R.string.settings_group_memory_note), { viewModel.openSettingsGroup(SettingsGroup.Memory) })
                    StudioCardDivider()
                    StudioDestinationRow(Icons.Filled.ModelTraining, Color(0xFF39C6A3), stringResource(R.string.settings_group_models), stringResource(R.string.settings_group_models_note), { viewModel.openSettingsGroup(SettingsGroup.Models) })
                }
            }
        }
    }
}

/** App settings stay intentionally small; Studio's long list has one doorway. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsScreen(state: UiState, viewModel: AppViewModel) {
    val context = LocalContext.current
    val activity = context as? Activity
    val accountName = state.account.orEmpty().ifBlank { stringResource(R.string.settings_account_unknown) }
    val language = APP_LANGUAGES.firstOrNull { it.tag == state.language } ?: APP_LANGUAGES.first()
    var appearanceSheet by remember { mutableStateOf(false) }
    var languageSheet by remember { mutableStateOf(false) }
    var reasoningSheet by remember { mutableStateOf(false) }
    var confirmSignOut by remember { mutableStateOf(false) }

    if (appearanceSheet) {
        ModalBottomSheet(
            onDismissRequest = { appearanceSheet = false },
            sheetState = rememberModalBottomSheetState(),
        ) {
            PickerSheet(
                title = stringResource(R.string.settings_appearance),
                loading = false,
                rows = APPEARANCE_LEVELS.map { (value, label) ->
                    PickerRow(
                        label = stringResource(label),
                        detail = null,
                        selected = state.appearance == value,
                    ) {
                        appearanceSheet = false
                        viewModel.setAppearance(value)
                        activity?.recreate()
                    }
                },
            )
        }
    }
    if (languageSheet) LanguageSheet(state, viewModel) { languageSheet = false }
    if (reasoningSheet) {
        ModalBottomSheet(
            onDismissRequest = { reasoningSheet = false },
            sheetState = rememberModalBottomSheetState(),
        ) {
            PickerSheet(
                title = stringResource(R.string.settings_reasoning),
                loading = false,
                rows = REASONING_LEVELS.map { (value, label) ->
                    PickerRow(
                        label = stringResource(label),
                        detail = if (value.isBlank()) stringResource(R.string.reasoning_use_profile) else null,
                        selected = state.reasoningEffort == value,
                    ) {
                        reasoningSheet = false
                        viewModel.setReasoningEffort(value)
                    }
                },
            )
        }
    }
    if (confirmSignOut) {
        ConfirmDialog(
            title = stringResource(R.string.confirm_sign_out_title),
            body = stringResource(R.string.confirm_sign_out_body),
            action = stringResource(R.string.action_sign_out),
            onConfirm = { viewModel.signOut() },
            onDismiss = { confirmSignOut = false },
        )
    }

    Scaffold(
        topBar = {
            StudioLargeTopBar(
                title = stringResource(R.string.settings_title),
                navigationIcon = {
                    IconButton(onClick = { viewModel.back() }) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.action_back),
                        )
                    }
                },
            )
        },
        bottomBar = { StudioTabs(state, viewModel) },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(
                start = StudioHorizontalPadding,
                end = StudioHorizontalPadding,
                top = 8.dp,
                bottom = 28.dp,
            ),
        ) {
            state.error?.let { message -> item { ErrorNote(message) { viewModel.dismissError() } } }
            state.notice?.let { message -> item { NoticeNote(message) { viewModel.dismissNotice() } } }

            item {
                StudioGroupedCard {
                    Row(
                        modifier = Modifier.fillMaxWidth().clickable { viewModel.openSettingsGroup(SettingsGroup.Account) }
                            .padding(horizontal = 16.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        ProfileAvatar(accountName, state.accountAvatar, size = 50.dp)
                        Spacer(Modifier.width(13.dp))
                        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Text(accountName, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            Text(
                                state.currentUser?.role?.let {
                                    stringResource(if (it == "super_admin") R.string.users_super_admin else R.string.users_admin)
                                }.orEmpty(),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Icon(
                            Icons.AutoMirrored.Filled.KeyboardArrowRight,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    StudioCardDivider()
                    StudioDestinationRow(
                        icon = Icons.Filled.Person,
                        color = Color(0xFF4D8DFF),
                        title = stringResource(R.string.action_profiles),
                        subtitle = state.activeProfile,
                        onClick = { viewModel.openProfiles() },
                    )
                    StudioCardDivider()
                    StudioDestinationRow(
                        icon = Icons.Filled.Dns,
                        color = Color(0xFF35C878),
                        title = stringResource(R.string.settings_studio_connection),
                        subtitle = state.baseUrl,
                        onClick = { viewModel.openSettingsGroup(SettingsGroup.Server) },
                    )
                }
            }

            item { StudioSectionTitle(stringResource(R.string.settings_category_app)) }
            item {
                StudioGroupedCard {
                    StudioDestinationRow(
                        icon = Icons.Filled.DisplaySettings,
                        color = Color(0xFF6F72E8),
                        title = stringResource(R.string.settings_appearance),
                        subtitle = appearanceLabel(state.appearance),
                        onClick = { appearanceSheet = true },
                    )
                    StudioCardDivider()
                    StudioDestinationRow(
                        icon = Icons.Filled.Language,
                        color = Color(0xFF18B9C7),
                        title = stringResource(R.string.settings_language),
                        subtitle = AppLocale.labelFor(context, language),
                        onClick = { languageSheet = true },
                    )
                    StudioCardDivider()
                    StudioDestinationRow(
                        icon = Icons.Filled.Psychology,
                        color = Color(0xFFD62AE8),
                        title = stringResource(R.string.settings_reasoning),
                        subtitle = reasoningLabel(state.reasoningEffort),
                        onClick = { reasoningSheet = true },
                    )
                }
            }

            item { Spacer(Modifier.height(16.dp)) }
            item {
                StudioGroupedCard {
                    StudioDestinationRow(
                        icon = Icons.Filled.Tune,
                        color = Color(0xFFFF9F43),
                        title = stringResource(R.string.more_settings_title),
                        subtitle = stringResource(R.string.more_settings_note),
                        onClick = { viewModel.openMoreSettings() },
                    )
                }
            }
            item {
                Text(
                    stringResource(R.string.more_settings_footer),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 10.dp),
                )
            }

            item { StudioSectionTitle(stringResource(R.string.settings_section_about)) }
            item {
                StudioGroupedCard {
                    StudioDestinationRow(
                        icon = Icons.Filled.PhoneAndroid,
                        color = Color(0xFF7A5CFF),
                        title = stringResource(R.string.settings_phone_name),
                        trailing = {
                            Text(
                                BuildConfig.VERSION_NAME,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                style = MaterialTheme.typography.bodyLarge,
                            )
                        },
                    )
                    StudioCardDivider()
                    StudioDestinationRow(
                        icon = painterResource(R.drawable.ic_github),
                        color = MaterialTheme.colorScheme.onSurface,
                        title = stringResource(R.string.settings_phone_github),
                        onClick = {
                            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(PHONE_REPOSITORY_URL)))
                        },
                        trailing = { Icon(Icons.AutoMirrored.Filled.OpenInNew, contentDescription = null) },
                    )
                    StudioCardDivider()
                    StudioDestinationRow(
                        icon = painterResource(R.drawable.ic_github),
                        color = MaterialTheme.colorScheme.onSurface,
                        title = stringResource(R.string.settings_studio_github),
                        onClick = {
                            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(STUDIO_REPOSITORY_URL)))
                        },
                        trailing = { Icon(Icons.AutoMirrored.Filled.OpenInNew, contentDescription = null) },
                    )
                }
            }

            item { Spacer(Modifier.height(20.dp)) }
            item {
                StudioGroupedCard {
                    TextButton(
                        onClick = { confirmSignOut = true },
                        colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error),
                        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                    ) {
                        Icon(Icons.AutoMirrored.Filled.Logout, contentDescription = null)
                        Spacer(Modifier.width(8.dp))
                        Text(stringResource(R.string.action_sign_out), style = MaterialTheme.typography.titleMedium)
                    }
                }
            }
        }
    }
}

/** The non-agent Studio settings, grouped behind one clearly named entry. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MoreSettingsScreen(state: UiState, viewModel: AppViewModel) {
    Scaffold(
        topBar = {
            StudioTopBar(
                title = stringResource(R.string.more_settings_title),
                subtitle = stringResource(R.string.more_settings_subtitle),
                onBack = { viewModel.back() },
            )
        },
        bottomBar = { StudioTabs(state, viewModel) },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(
                start = StudioHorizontalPadding,
                end = StudioHorizontalPadding,
                top = 8.dp,
                bottom = 28.dp,
            ),
        ) {
            state.error?.let { message -> item { ErrorNote(message) { viewModel.dismissError() } } }
            state.notice?.let { message -> item { NoticeNote(message) { viewModel.dismissNotice() } } }

            item { StudioSectionTitle(stringResource(R.string.more_settings_agent)) }
            item {
                StudioGroupedCard {
                    StudioDestinationRow(Icons.Filled.Tune, Color(0xFF7A5CFF), stringResource(R.string.settings_group_agent), stringResource(R.string.settings_group_agent_note), { viewModel.openSettingsGroup(SettingsGroup.Agent) })
                    StudioCardDivider()
                    StudioDestinationRow(Icons.Filled.Memory, Color(0xFFFFB547), stringResource(R.string.settings_group_memory), stringResource(R.string.settings_group_memory_note), { viewModel.openSettingsGroup(SettingsGroup.Memory) })
                    StudioCardDivider()
                    StudioDestinationRow(Icons.Filled.Compress, Color(0xFFFF9F43), stringResource(R.string.settings_group_compression), stringResource(R.string.settings_group_compression_note), { viewModel.openSettingsGroup(SettingsGroup.Compression) })
                    StudioCardDivider()
                    StudioDestinationRow(Icons.Filled.ModelTraining, Color(0xFF39C6A3), stringResource(R.string.settings_group_models), stringResource(R.string.settings_group_models_note), { viewModel.openSettingsGroup(SettingsGroup.Models) })
                }
            }

            item { StudioSectionTitle(stringResource(R.string.more_settings_conversation)) }
            item {
                StudioGroupedCard {
                    StudioDestinationRow(Icons.Filled.DisplaySettings, Color(0xFFFF6584), stringResource(R.string.settings_group_display), stringResource(R.string.settings_group_display_note), { viewModel.openSettingsGroup(SettingsGroup.Display) })
                    StudioCardDivider()
                    StudioDestinationRow(Icons.Filled.History, Color(0xFF6F72E8), stringResource(R.string.settings_group_sessions), stringResource(R.string.settings_group_sessions_note), { viewModel.openSettingsGroup(SettingsGroup.Sessions) })
                }
            }

            item { StudioSectionTitle(stringResource(R.string.more_settings_network_privacy)) }
            item {
                StudioGroupedCard {
                    StudioDestinationRow(Icons.Filled.VpnLock, Color(0xFF18B9C7), stringResource(R.string.settings_group_proxy), stringResource(R.string.settings_group_proxy_note), { viewModel.openSettingsGroup(SettingsGroup.Proxy) })
                    StudioCardDivider()
                    StudioDestinationRow(Icons.Filled.PrivacyTip, Color(0xFFE85262), stringResource(R.string.settings_group_privacy), stringResource(R.string.settings_group_privacy_note), { viewModel.openSettingsGroup(SettingsGroup.Privacy) })
                }
            }

            if (state.currentUser?.role == "super_admin") {
                item { StudioSectionTitle(stringResource(R.string.more_settings_management)) }
                item {
                    StudioGroupedCard {
                        StudioDestinationRow(
                            icon = Icons.Filled.Group,
                            color = Color(0xFF35B7DB),
                            title = stringResource(R.string.settings_group_users),
                            subtitle = stringResource(R.string.settings_group_users_note),
                            onClick = { viewModel.openSettingsGroup(SettingsGroup.Users) },
                        )
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun InsightsScreen(state: UiState, viewModel: AppViewModel) {
    val usage = state.usageStats
    val performance = state.runtimePerformance
    Scaffold(
        topBar = {
            StudioTopBar(
                title = stringResource(R.string.insights_title),
                subtitle = stringResource(R.string.insights_subtitle),
                onBack = { viewModel.back() },
                actions = {
                    IconButton(onClick = { viewModel.refreshInsights() }) {
                        Icon(Icons.Filled.Refresh, contentDescription = stringResource(R.string.action_refresh))
                    }
                },
            )
        },
        bottomBar = { StudioTabs(state, viewModel) },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(StudioHorizontalPadding, 8.dp, StudioHorizontalPadding, 28.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            if (state.loadingInsights) item { LoadingRow() }
            state.error?.let { item { ErrorNote(it) { viewModel.dismissError() } } }
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(7, 30, 90, 365).forEach { days ->
                        AssistChip(
                            onClick = { viewModel.openInsights(days) },
                            label = { Text(stringResource(R.string.insights_days, days)) },
                            leadingIcon = if (days == state.usageDays) ({ Icon(Icons.Filled.Check, null, Modifier.size(16.dp)) }) else null,
                        )
                    }
                }
            }
            usage?.let { stats ->
                item { StudioSectionTitle(stringResource(R.string.insights_usage)) }
                item {
                    StudioGroupedCard {
                        InsightMetric(stringResource(R.string.insights_tokens), compactNumber(stats.inputTokens + stats.outputTokens))
                        StudioCardDivider()
                        InsightMetric(stringResource(R.string.insights_sessions), stats.sessions.toString())
                        StudioCardDivider()
                        InsightMetric(stringResource(R.string.insights_cost), "$${"%.4f".format(stats.cost)}")
                        StudioCardDivider()
                        InsightMetric(stringResource(R.string.insights_cache), compactNumber(stats.cacheReadTokens + stats.cacheWriteTokens))
                    }
                }
                if (stats.models.isNotEmpty()) {
                    item { StudioSectionTitle(stringResource(R.string.insights_by_model)) }
                    items(stats.models.take(8), key = { it.name }) { row ->
                        StudioGroupedCard { InsightMetric(row.name, compactNumber(row.totalTokens), row.sessions.toString()) }
                    }
                }
            }
            performance?.let { runtime ->
                item { StudioSectionTitle(stringResource(R.string.insights_runtime)) }
                item {
                    StudioGroupedCard {
                        InsightMetric("CPU", runtime.cpuPercent?.let { "%.1f%%".format(it) } ?: "—")
                        StudioCardDivider()
                        InsightMetric(stringResource(R.string.insights_memory), runtime.memoryPercent?.let { "%.1f%%".format(it) } ?: "—")
                        StudioCardDivider()
                        InsightMetric(stringResource(R.string.insights_workers), "${runtime.runningWorkers}/${runtime.workerCount}")
                        StudioCardDivider()
                        InsightMetric(stringResource(R.string.insights_live_sessions), runtime.sessionCount.toString())
                    }
                }
            }
        }
    }
}

@Composable
private fun InsightMetric(label: String, value: String, supporting: String? = null) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 13.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(label, style = MaterialTheme.typography.bodyLarge)
            supporting?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
        Text(value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsGroupScreen(state: UiState, viewModel: AppViewModel) {
    val group = state.openGroup ?: return
    val title = stringResource(
        when (group) {
            SettingsGroup.Account -> R.string.settings_account
            SettingsGroup.Server -> R.string.settings_group_server
            SettingsGroup.Users -> R.string.settings_group_users
            SettingsGroup.Profile -> R.string.settings_group_profile
            SettingsGroup.Models -> R.string.settings_group_models
            SettingsGroup.Agent -> R.string.settings_group_agent
            SettingsGroup.Memory -> R.string.settings_group_memory
            SettingsGroup.Compression -> R.string.settings_group_compression
            SettingsGroup.Sessions -> R.string.settings_group_sessions
            SettingsGroup.Privacy -> R.string.settings_group_privacy
            SettingsGroup.Proxy -> R.string.settings_group_proxy
            SettingsGroup.Display -> R.string.settings_group_display
            SettingsGroup.Device -> R.string.settings_group_device
            SettingsGroup.About -> R.string.settings_section_about
        },
    )

    Scaffold(
        topBar = { StudioTopBar(title = title, onBack = { viewModel.back() }) },
        bottomBar = { StudioTabs(state, viewModel) },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .imePadding(),
        ) {
            if (state.savingSetting) LoadingRow()
            state.error?.let { ErrorNote(it) { viewModel.dismissError() } }
            state.notice?.let { NoticeNote(it) { viewModel.dismissNotice() } }

            if (
                !state.loadingAgentSettings && !state.loadingStudioSettings &&
                !state.loadingAccountSettings && !state.loadingManagedUsers &&
                !state.loadingModelProviders
            ) {
                when (group) {
                    SettingsGroup.Account -> AccountSettings(state, viewModel)
                    SettingsGroup.Server -> ServerSettings(state, viewModel)
                    SettingsGroup.Users -> ManagedUsersSettings(state, viewModel)
                    SettingsGroup.Profile -> ProfileSettings(state, viewModel)
                    SettingsGroup.Models -> ModelProvidersSettings(state, viewModel)
                    SettingsGroup.Agent -> AgentSettings(state, viewModel)
                    SettingsGroup.Memory -> MemoryStudioSettings(state, viewModel)
                    SettingsGroup.Compression -> CompressionStudioSettings(state, viewModel)
                    SettingsGroup.Sessions -> SessionStudioSettings(state, viewModel)
                    SettingsGroup.Privacy -> PrivacyStudioSettings(state, viewModel)
                    SettingsGroup.Proxy -> ProxyStudioSettings(state, viewModel)
                    SettingsGroup.Display -> DisplayStudioSettings(state, viewModel)
                    SettingsGroup.Device -> DeviceSettings(state, viewModel)
                    SettingsGroup.About -> AboutSettings()
                }
            }
        }
    }
}

@Composable
private fun ServerSettings(state: UiState, viewModel: AppViewModel) {
    SettingsRow(
        icon = Icons.Filled.Dns,
        label = stringResource(R.string.settings_address),
        value = state.baseUrl.ifBlank { stringResource(R.string.settings_address_missing) },
    )
}

@Composable
private fun AccountSettings(state: UiState, viewModel: AppViewModel) {
    SettingsRow(
        icon = Icons.Filled.Person,
        label = stringResource(R.string.settings_account),
        value = state.account ?: stringResource(R.string.settings_account_unknown),
    )
    AccountStudioSettings(state, viewModel)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ProfileSettings(state: UiState, viewModel: AppViewModel) {
    var modelSheet by remember { mutableStateOf(false) }
    var confirmRestart by remember { mutableStateOf(false) }
    val profile = state.activeProfile.ifBlank { "default" }

    if (modelSheet) {
        ModalBottomSheet(
            onDismissRequest = { modelSheet = false },
            sheetState = rememberModalBottomSheetState(),
        ) {
            PickerSheet(
                title = stringResource(R.string.settings_default_model_title, profile),
                loading = state.loadingModels,
                rows = state.models.map { option ->
                    PickerRow(label = option.id, detail = option.provider, selected = option.id == state.defaultModel) {
                        viewModel.setDefaultModel(option)
                        modelSheet = false
                    }
                },
            )
        }
    }
    if (confirmRestart) {
        ConfirmDialog(
            title = stringResource(R.string.confirm_restart_title),
            body = stringResource(R.string.confirm_restart_body, profile),
            action = stringResource(R.string.settings_restart_gateway),
            onConfirm = { viewModel.restartGateway() },
            onDismiss = { confirmRestart = false },
        )
    }

    SettingsRow(
        icon = Icons.Filled.Person,
        label = stringResource(R.string.settings_profile),
        value = profile,
        onClick = { viewModel.openProfiles() },
    )
    SettingsRow(
        icon = Icons.Filled.ModelTraining,
        label = stringResource(R.string.settings_default_model),
        value = state.defaultModel ?: stringResource(R.string.settings_default_model_server),
        onClick = {
            viewModel.loadModels()
            modelSheet = true
        },
    )
    SettingsRow(
        icon = Icons.Filled.RestartAlt,
        label = stringResource(R.string.settings_restart_gateway),
        value = stringResource(R.string.settings_restart_gateway_note),
        onClick = { confirmRestart = true },
    )
}

/** The agent knobs, with gateway auto-start where Studio keeps it. */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun AgentSettings(state: UiState, viewModel: AppViewModel) {
    val agent = state.agentSettings
    val policy = state.autoStart
    var editing by remember { mutableStateOf<String?>(null) }
    var enforcementSheet by remember { mutableStateOf(false) }
    var policySheet by remember { mutableStateOf(false) }

    editing?.let { key ->
        val current = when (key) {
            "max_turns" -> agent?.maxTurns
            "gateway_timeout" -> agent?.gatewayTimeout
            else -> agent?.restartDrainTimeout
        }
        TextPromptDialog(
            title = stringResource(
                when (key) {
                    "max_turns" -> R.string.agent_max_turns
                    "gateway_timeout" -> R.string.agent_gateway_timeout
                    else -> R.string.agent_drain_timeout
                },
            ),
            initial = current?.toString().orEmpty(),
            hint = "",
            action = stringResource(R.string.action_save),
            onConfirm = { typed -> typed.toIntOrNull()?.let { viewModel.setAgentValue(key, it) } },
            onDismiss = { editing = null },
        )
    }
    if (enforcementSheet) {
        ModalBottomSheet(
            onDismissRequest = { enforcementSheet = false },
            sheetState = rememberModalBottomSheetState(),
        ) {
            PickerSheet(
                title = stringResource(R.string.agent_tool_enforcement),
                loading = false,
                rows = TOOL_ENFORCEMENT.map { (value, label) ->
                    PickerRow(label = stringResource(label), detail = null, selected = value == agent?.toolEnforcement) {
                        enforcementSheet = false
                        viewModel.setAgentValue("tool_use_enforcement", value)
                    }
                },
            )
        }
    }
    if (policySheet && policy != null) {
        ModalBottomSheet(
            onDismissRequest = { policySheet = false },
            sheetState = rememberModalBottomSheetState(),
        ) {
            PickerSheet(
                title = stringResource(R.string.agent_policy),
                loading = false,
                rows = listOf(
                    PickerRow(
                        label = stringResource(R.string.agent_policy_all),
                        detail = null,
                        selected = policy.include == null,
                    ) {
                        policySheet = false
                        viewModel.setAutoStart(policy.copy(include = null))
                    },
                    PickerRow(
                        label = stringResource(R.string.agent_policy_include),
                        detail = null,
                        selected = policy.include != null,
                    ) {
                        policySheet = false
                        viewModel.setAutoStart(
                            policy.copy(
                                include = policy.include ?: listOf(state.activeProfile),
                                exclude = emptyList(),
                            ),
                        )
                    },
                ),
            )
        }
    }

    SettingsRow(
        icon = Icons.Filled.Repeat,
        label = stringResource(R.string.agent_max_turns),
        value = agent?.maxTurns?.toString() ?: stringResource(R.string.agent_unset),
        onClick = { editing = "max_turns" },
    )
    SettingsRow(
        icon = Icons.Filled.Timer,
        label = stringResource(R.string.agent_gateway_timeout),
        value = agent?.gatewayTimeout?.toString() ?: stringResource(R.string.agent_unset),
        onClick = { editing = "gateway_timeout" },
    )
    SettingsRow(
        icon = Icons.Filled.HourglassBottom,
        label = stringResource(R.string.agent_drain_timeout),
        value = agent?.restartDrainTimeout?.toString() ?: stringResource(R.string.agent_unset),
        onClick = { editing = "restart_drain_timeout" },
    )
    SettingsRow(
        icon = Icons.AutoMirrored.Filled.Rule,
        label = stringResource(R.string.agent_tool_enforcement),
        value = stringResource(
            TOOL_ENFORCEMENT.firstOrNull { it.first == agent?.toolEnforcement }?.second ?: R.string.agent_tool_auto,
        ),
        onClick = { enforcementSheet = true },
    )

    SettingsSection(stringResource(R.string.agent_autostart_title))
    Text(
        stringResource(R.string.agent_autostart_note),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp),
    )
    SettingsRow(
        icon = Icons.Filled.PowerSettingsNew,
        label = stringResource(R.string.settings_auto_start),
        value = stringResource(
            if (policy?.enabled == true) R.string.settings_auto_start_on else R.string.settings_auto_start_off,
        ),
        trailing = {
            Switch(
                checked = policy?.enabled == true,
                onCheckedChange = { on -> policy?.let { viewModel.setAutoStart(it.copy(enabled = on)) } },
            )
        },
    )
    if (policy?.enabled == true) {
        if (state.activeProfile.ifBlank { "default" } == "default") {
            SettingsRow(
                icon = Icons.Filled.AccountTree,
                label = stringResource(R.string.agent_management),
                value = stringResource(R.string.agent_management_note),
                trailing = {
                    Switch(
                        checked = policy.management == "unified",
                        onCheckedChange = { unified ->
                            viewModel.setAutoStart(
                                policy.copy(management = if (unified) "unified" else "per_profile"),
                            )
                        },
                    )
                },
            )
        }
        SettingsRow(
            icon = Icons.Filled.Groups,
            label = stringResource(R.string.agent_policy),
            value = stringResource(
                if (policy.include == null) R.string.agent_policy_all else R.string.agent_policy_include,
            ),
            onClick = { policySheet = true },
        )
        policy.include?.let { included ->
            Text(
                stringResource(R.string.agent_policy_profiles),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 6.dp),
            )
            FlowRow(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                state.profiles.forEach { profile ->
                    val chosen = profile.name in included
                    AssistChip(
                        onClick = {
                            val next = if (chosen) included - profile.name else included + profile.name
                            viewModel.setAutoStart(policy.copy(include = next))
                        },
                        label = { Text(profile.name) },
                        leadingIcon = if (chosen) {
                            { Icon(Icons.Filled.Check, contentDescription = null, modifier = Modifier.size(16.dp)) }
                        } else {
                            null
                        },
                    )
                }
            }
        }
        if (policy.include == null) {
            Text(
                stringResource(R.string.agent_excluded_profiles),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 6.dp),
            )
            FlowRow(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                state.profiles.forEach { profile ->
                    val excluded = profile.name in policy.exclude
                    AssistChip(
                        onClick = {
                            val next = if (excluded) policy.exclude - profile.name else policy.exclude + profile.name
                            viewModel.setAutoStart(policy.copy(exclude = next))
                        },
                        label = { Text(profile.name) },
                        leadingIcon = if (excluded) {
                            { Icon(Icons.Filled.Close, contentDescription = null, modifier = Modifier.size(16.dp)) }
                        } else {
                            null
                        },
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DeviceSettings(state: UiState, viewModel: AppViewModel) {
    val context = LocalContext.current
    var languageSheet by remember { mutableStateOf(false) }
    val language = APP_LANGUAGES.firstOrNull { it.tag == state.language } ?: APP_LANGUAGES.first()

    val pickLogo = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        val bytes = runCatching {
            context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
        }.getOrNull()
        if (bytes != null && bytes.isNotEmpty()) viewModel.setAppLogo(bytes)
    }

    if (languageSheet) LanguageSheet(state, viewModel) { languageSheet = false }

    SettingsRow(
        icon = Icons.Filled.Language,
        label = stringResource(R.string.settings_language),
        value = AppLocale.labelFor(context, language),
        onClick = { languageSheet = true },
    )
    LogoRow(
        value = stringResource(
            when {
                AppLogo.isCustom -> R.string.settings_logo_custom
                AppLogo.image != null -> R.string.settings_logo_server
                else -> R.string.settings_logo_missing
            },
        ),
        onClick = { pickLogo.launch("image/*") },
    )
    if (AppLogo.isCustom) {
        SettingsRow(
            icon = Icons.Filled.Refresh,
            label = stringResource(R.string.settings_logo_reset),
            value = stringResource(R.string.settings_logo_reset_note),
            onClick = { viewModel.resetAppLogo() },
        )
    }
    Text(
        stringResource(R.string.settings_logo_note),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
    )
    SettingsRow(
        icon = Icons.Filled.Psychology,
        label = stringResource(R.string.settings_reasoning),
        value = reasoningLabel(state.reasoningEffort),
    )
    Text(
        stringResource(R.string.settings_reasoning_note),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 20.dp, vertical = 4.dp),
    )
}

@Composable
private fun AboutSettings() {
    SettingsRow(
        icon = Icons.Filled.Info,
        label = stringResource(R.string.settings_version),
        value = BuildConfig.VERSION_NAME,
    )
    Text(
        stringResource(R.string.settings_about_note),
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
    )
}

private val TOOL_ENFORCEMENT = listOf(
    "auto" to R.string.agent_tool_auto,
    "always" to R.string.agent_tool_always,
    "never" to R.string.agent_tool_never,
)

/** Every channel Hermes can speak on, and whether it is ready. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ChannelsScreen(state: UiState, viewModel: AppViewModel) {
    val known = state.serverConfig?.channels.orEmpty().associateBy { it.platform }
    val listed = CHANNELS.map { spec -> spec to known[spec.platform] }

    Scaffold(
        topBar = {
            StudioTopBar(
                title = stringResource(R.string.channels_title),
                subtitle = state.activeProfile.ifBlank { null },
                onBack = { viewModel.back() },
            )
        },
        bottomBar = { StudioTabs(state, viewModel) },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = StudioHorizontalPadding)
                .verticalScroll(rememberScrollState()),
        ) {
            if (state.savingSetting) LoadingRow()
            state.error?.let { ErrorNote(it) { viewModel.dismissError() } }
            state.notice?.let { NoticeNote(it) { viewModel.dismissNotice() } }

            StudioGroupedCard {
                listed.forEachIndexed { index, (spec, status) ->
                    val connected = status?.configured == true && status.enabled
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { viewModel.openChannel(spec.platform) }
                            .padding(horizontal = 14.dp, vertical = 13.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Surface(
                            shape = RoundedCornerShape(14.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant,
                        ) {
                            Icon(
                                painter = painterResource(spec.iconRes),
                                contentDescription = null,
                                tint = Color.Unspecified,
                                modifier = Modifier.padding(10.dp).size(28.dp),
                            )
                        }
                        Spacer(Modifier.width(14.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(spec.label, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            Text(
                                stringResource(
                                    when {
                                        connected -> R.string.channel_connected
                                        status?.configured == true -> R.string.channel_off
                                        else -> R.string.channel_missing
                                    },
                                ),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        Box(
                            modifier = Modifier
                                .size(11.dp)
                                .clip(RoundedCornerShape(99.dp))
                                .background(
                                    if (connected) Color(0xFF30D158)
                                    else MaterialTheme.colorScheme.outlineVariant,
                                ),
                        )
                        Spacer(Modifier.width(10.dp))
                        Icon(
                            Icons.AutoMirrored.Filled.KeyboardArrowRight,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    if (index != listed.lastIndex) StudioCardDivider(startIndent = 76)
                }
            }

            Text(
                stringResource(R.string.channel_note),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 14.dp),
            )
        }
    }
}

/** One channel: its credentials, and whether Hermes answers on it. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ChannelScreen(state: UiState, viewModel: AppViewModel) {
    val platform = state.openChannel ?: return
    val context = LocalContext.current
    val spec = channelSpec(platform)
    val status = state.serverConfig?.channels.orEmpty().firstOrNull { it.platform == platform }
    val values = remember(platform, status?.values) {
        mutableStateMapOf<String, String>().apply {
            putAll(status?.values.orEmpty())
            spec.fields.filter { it.kind == ChannelFieldKind.Toggle }.forEach { field ->
                putIfAbsent(field.path, field.defaultEnabled.toString())
            }
        }
    }
    val revealed = remember(platform) { mutableStateMapOf<String, Boolean>() }
    var enabled by remember(platform, status?.enabled) { mutableStateOf(status?.enabled ?: true) }
    var confirmClear by remember(platform) { mutableStateOf(false) }
    var openedQrId by remember(platform) { mutableStateOf("") }

    LaunchedEffect(state.weixinQr.id, state.weixinQr.url) {
        val qr = state.weixinQr
        if (platform == "weixin" && qr.id.isNotBlank() && qr.url.isNotBlank() && openedQrId != qr.id) {
            openedQrId = qr.id
            runCatching {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(qr.url)))
            }.onFailure { viewModel.showToolError(it) }
        }
    }

    if (confirmClear) {
        ConfirmDialog(
            title = stringResource(R.string.channel_clear_title, spec.label),
            body = stringResource(R.string.channel_clear_body),
            action = stringResource(R.string.channel_clear),
            onConfirm = { viewModel.clearChannel(platform) },
            onDismiss = { confirmClear = false },
        )
    }

    Scaffold(
        topBar = {
            StudioTopBar(
                title = spec.label,
                subtitle = stringResource(
                    when {
                        status?.configured == true && status.enabled -> R.string.channel_connected
                        status?.configured == true -> R.string.channel_off
                        else -> R.string.channel_missing
                    },
                ),
                onBack = { viewModel.back() },
                leading = {
                    Icon(
                        painter = painterResource(spec.iconRes),
                        contentDescription = null,
                        modifier = Modifier.size(28.dp),
                        tint = Color.Unspecified,
                    )
                },
            )
        },
        bottomBar = { StudioTabs(state, viewModel) },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .imePadding(),
        ) {
            if (state.savingSetting) LoadingRow()
            state.error?.let { ErrorNote(it) { viewModel.dismissError() } }
            state.notice?.let { NoticeNote(it) { viewModel.dismissNotice() } }

            if (spec.exclusive) {
                Surface(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp),
                    shape = RoundedCornerShape(16.dp),
                    color = Color(0xFFFF9500).copy(alpha = 0.14f),
                ) {
                    Text(
                        stringResource(R.string.channel_exclusive_warning),
                        style = MaterialTheme.typography.bodySmall,
                        color = Color(0xFFFFB340),
                        modifier = Modifier.padding(14.dp),
                    )
                }
            }

            if (platform == "weixin") {
                val qrStatus = when (state.weixinQr.status) {
                    "loading" -> R.string.channel_qr_loading
                    "waiting" -> R.string.channel_qr_waiting
                    "scanned" -> R.string.channel_qr_scanned
                    "confirmed" -> R.string.channel_qr_confirmed
                    "expired" -> R.string.channel_qr_expired
                    "error" -> R.string.channel_qr_error
                    else -> R.string.channel_qr_ready
                }
                SettingsRow(
                    icon = Icons.Filled.Cable,
                    label = stringResource(R.string.channel_qr_link),
                    value = stringResource(qrStatus),
                    onClick = viewModel::startWeixinQr,
                    trailing = if (state.weixinQr.status == "loading" || state.weixinQr.status == "waiting" || state.weixinQr.status == "scanned") {
                        { CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp) }
                    } else null,
                )
            }

            if (spec.fields.none {
                    it.target == ChannelFieldTarget.Credentials && it.path == "enabled"
                }
            ) {
                SettingsRow(
                    icon = painterResource(spec.iconRes),
                    label = stringResource(R.string.channel_enabled),
                    value = stringResource(R.string.channel_enabled_note),
                    trailing = {
                        Switch(checked = enabled, onCheckedChange = { enabled = it })
                    },
                )
            }

            @Composable
            fun section(target: ChannelFieldTarget, title: Int) {
                val fields = spec.fields.filter { it.target == target }
                if (fields.isEmpty()) return
                SettingsSection(stringResource(title))
                fields.forEach { field ->
                    val label = stringResource(field.labelRes)
                    val hint = field.hintRes?.let { stringResource(it) }.orEmpty()
                    when (field.kind) {
                        ChannelFieldKind.Toggle -> SettingsRow(
                            icon = if (target == ChannelFieldTarget.Credentials) Icons.Filled.VpnLock else Icons.Filled.Tune,
                            label = label,
                            value = hint,
                            trailing = {
                                Switch(
                                    checked = values[field.path].toBoolean(),
                                    onCheckedChange = { values[field.path] = it.toString() },
                                )
                            },
                        )
                        ChannelFieldKind.Text,
                        ChannelFieldKind.Secret,
                        ChannelFieldKind.CommaList,
                        -> {
                            val secret = field.kind == ChannelFieldKind.Secret
                            val visible = revealed[field.path] == true
                            OutlinedTextField(
                                value = values[field.path].orEmpty(),
                                onValueChange = { values[field.path] = it },
                                label = { Text(label) },
                                supportingText = hint.takeIf(String::isNotBlank)?.let { { Text(it) } },
                                placeholder = field.placeholder.takeIf(String::isNotBlank)?.let { placeholder ->
                                    { Text(placeholder) }
                                },
                                trailingIcon = if (secret) {
                                    {
                                        IconButton(onClick = { revealed[field.path] = !visible }) {
                                            Icon(
                                                if (visible) Icons.Filled.VisibilityOff else Icons.Filled.Visibility,
                                                contentDescription = stringResource(
                                                    if (visible) R.string.channel_hide_secret else R.string.channel_show_secret,
                                                ),
                                            )
                                        }
                                    }
                                } else null,
                                singleLine = true,
                                visualTransformation = if (secret && !visible) PasswordVisualTransformation() else VisualTransformation.None,
                                modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 6.dp),
                            )
                        }
                    }
                }
            }

            section(ChannelFieldTarget.Credentials, R.string.channel_credentials_section)
            section(ChannelFieldTarget.Configuration, R.string.channel_behavior_section)

            Button(
                onClick = { viewModel.saveChannel(platform, values.toMap(), enabled) },
                enabled = !state.savingSetting,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp),
            ) {
                Text(stringResource(R.string.channel_save))
            }

            if (status?.configured == true && spec.supportsCredentialClear) {
                SettingsRow(
                    icon = Icons.Filled.Delete,
                    label = stringResource(R.string.channel_clear),
                    value = stringResource(R.string.channel_clear_body),
                    onClick = { confirmClear = true },
                )
            }

            Text(
                stringResource(R.string.channel_note),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 14.dp),
            )
        }
    }
}

@Composable
internal fun SettingsSection(label: String) {
    Text(
        label,
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(start = 22.dp, end = 22.dp, top = 18.dp, bottom = 4.dp),
    )
}

@Composable
internal fun SettingsRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    value: String,
    onClick: (() -> Unit)? = null,
    trailing: @Composable (() -> Unit)? = null,
) {
    SettingsRowContent(
        leading = { Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant) },
        label = label,
        value = value,
        onClick = onClick,
        trailing = trailing,
    )
}

/** Settings row for Studio/channel vector assets that are not Material icons. */
@Composable
internal fun SettingsRow(
    icon: Painter,
    label: String,
    value: String,
    onClick: (() -> Unit)? = null,
    trailing: @Composable (() -> Unit)? = null,
) {
    SettingsRowContent(
        leading = { Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant) },
        label = label,
        value = value,
        onClick = onClick,
        trailing = trailing,
    )
}

@Composable
private fun SettingsRowContent(
    leading: @Composable () -> Unit,
    label: String,
    value: String,
    onClick: (() -> Unit)?,
    trailing: @Composable (() -> Unit)?,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = StudioHorizontalPadding, vertical = 4.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(MaterialTheme.colorScheme.surfaceContainer)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        leading()
        Column(modifier = Modifier.weight(1f)) {
            Text(label, style = MaterialTheme.typography.bodyLarge)
            Text(
                value,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
        when {
            trailing != null -> trailing()
            onClick != null -> Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/** Settings row that previews the current app mark instead of an icon. */
@Composable
private fun LogoRow(value: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = StudioHorizontalPadding, vertical = 4.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(MaterialTheme.colorScheme.surfaceContainer)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        AppMark(size = 34.dp, corner = 10.dp)
        Column(modifier = Modifier.weight(1f)) {
            Text(stringResource(R.string.settings_logo), style = MaterialTheme.typography.bodyLarge)
            Text(
                value,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Icon(
            Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
    HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.4f))
}

@Composable
internal fun NoticeNote(message: String, onDismiss: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
        Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(message, modifier = Modifier.weight(1f))
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_ok)) }
        }
    }
}

// ── shared pieces ────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun StudioTopBar(
    title: String,
    subtitle: String? = null,
    onBack: (() -> Unit)? = null,
    leading: @Composable (() -> Unit)? = null,
    actions: @Composable () -> Unit = {},
) {
    TopAppBar(
        title = {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (leading != null) {
                    leading()
                    Spacer(Modifier.width(10.dp))
                }
                Column(modifier = Modifier.weight(1f, fill = false)) {
                    Text(title, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    subtitle?.let {
                        Text(
                            it,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
        },
        navigationIcon = {
            if (onBack != null) {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.action_back))
                }
            }
        },
        actions = { actions() },
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = MaterialTheme.colorScheme.surface,
        ),
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
internal fun StudioTabs(state: UiState, viewModel: AppViewModel) {
    // Keeping the navigation bar in Scaffold while the IME covers it reserves
    // a full invisible bar between the composer and keyboard. Material apps
    // hide bottom navigation during text entry, then restore it with the IME.
    if (WindowInsets.isImeVisible) return

    val colors = NavigationBarItemDefaults.colors(
        selectedIconColor = MaterialTheme.colorScheme.primary,
        selectedTextColor = MaterialTheme.colorScheme.primary,
        indicatorColor = MaterialTheme.colorScheme.primaryContainer,
        unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
        unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant,
    )

    NavigationBar(
        containerColor = MaterialTheme.colorScheme.surfaceContainer,
        tonalElevation = 0.dp,
    ) {
        NavigationBarItem(
            selected = state.tab == Tab.Chats,
            onClick = { viewModel.showTab(Tab.Chats) },
            icon = { Icon(Icons.AutoMirrored.Filled.Chat, contentDescription = null) },
            label = { Text(stringResource(R.string.chats_tab)) },
            colors = colors,
        )
        NavigationBarItem(
            selected = state.tab == Tab.Groups,
            onClick = { viewModel.showTab(Tab.Groups) },
            icon = { Icon(Icons.Filled.Group, contentDescription = null) },
            label = { Text(stringResource(R.string.groups_tab)) },
            colors = colors,
        )
        NavigationBarItem(
            selected = state.tab == Tab.Agent,
            onClick = { viewModel.showTab(Tab.Agent) },
            icon = { Icon(Icons.Filled.AutoAwesome, contentDescription = null) },
            label = { Text(stringResource(R.string.agent_hub_tab)) },
            colors = colors,
        )
    }
}

@Composable
private fun SectionHeader(label: String, count: Int) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontWeight = FontWeight.Medium,
        )
        Spacer(Modifier.width(8.dp))
        Text(
            count.toString(),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun EmptyNote(message: String) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Text(message, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
internal fun LoadingRow() {
    Row(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        horizontalArrangement = Arrangement.Center,
    ) {
        CircularProgressIndicator(modifier = Modifier.height(22.dp).width(22.dp))
    }
}

@Composable
internal fun ErrorNote(message: String, onDismiss: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
    ) {
        Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                message,
                modifier = Modifier.weight(1f),
                color = MaterialTheme.colorScheme.onErrorContainer,
            )
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_dismiss)) }
        }
    }
}
