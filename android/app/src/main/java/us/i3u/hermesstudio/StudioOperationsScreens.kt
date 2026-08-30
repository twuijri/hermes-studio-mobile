package us.i3u.hermesstudio

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WorkflowsScreen(state: UiState, viewModel: AppViewModel) {
    var inputFor by remember { mutableStateOf<StudioWorkflow?>(null) }
    var runInput by remember { mutableStateOf("") }
    inputFor?.let { workflow ->
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { inputFor = null },
            title = { Text(stringResource(R.string.workflow_run_title, workflow.name)) },
            text = { OutlinedTextField(runInput, { runInput = it }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.workflow_input)) }) },
            confirmButton = { TextButton(onClick = { inputFor = null; viewModel.runWorkflow(workflow, runInput) }) { Text(stringResource(R.string.workflow_run)) } },
            dismissButton = { TextButton(onClick = { inputFor = null }) { Text(stringResource(R.string.action_cancel)) } },
        )
    }
    Scaffold(topBar = {
        TopAppBar(
            title = { Text(stringResource(R.string.workflows_title)) },
            navigationIcon = { IconButton(viewModel::back) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.action_back)) } },
            actions = { IconButton(viewModel::openWorkflows) { Icon(Icons.Filled.Refresh, stringResource(R.string.action_refresh)) } },
        )
    }) { padding ->
        LazyColumn(Modifier.fillMaxSize().padding(padding), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item { Text(stringResource(R.string.workflows_mobile_note), color = MaterialTheme.colorScheme.onSurfaceVariant) }
            if (state.loadingWorkflows) item { Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) { CircularProgressIndicator() } }
            state.error?.let { item { Text(it, color = MaterialTheme.colorScheme.error) } }
            if (!state.loadingWorkflows && state.workflows.isEmpty()) item { Text(stringResource(R.string.workflows_empty)) }
            items(state.workflows, key = { it.id }) { workflow ->
                WorkflowCard(workflow, state.workflowRuns[workflow.id].orEmpty(), onRun = { inputFor = workflow; runInput = "" }, onStop = viewModel::stopWorkflowRun, onApproval = viewModel::approveWorkflowNode)
            }
        }
    }
}

@Composable
private fun WorkflowCard(workflow: StudioWorkflow, runs: List<StudioWorkflowRun>, onRun: () -> Unit, onStop: (StudioWorkflowRun) -> Unit, onApproval: (StudioWorkflowRun, Boolean) -> Unit) {
    Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(20.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(workflow.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Text(stringResource(R.string.workflow_summary, workflow.profile, workflow.nodeCount, workflow.edgeCount), color = MaterialTheme.colorScheme.onSurfaceVariant)
            workflow.workspace?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
            Button(onClick = onRun) { Icon(Icons.Filled.PlayArrow, null); Text(stringResource(R.string.workflow_run)) }
            runs.take(5).forEach { run ->
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Column(Modifier.weight(1f)) { Text(run.status, fontWeight = FontWeight.SemiBold); Text(run.id.take(10), style = MaterialTheme.typography.labelSmall) }
                    if (run.status == "running" || run.status == "queued") OutlinedButton(onClick = { onStop(run) }) { Icon(Icons.Filled.Stop, null); Text(stringResource(R.string.action_stop)) }
                    if (run.pendingNodeId != null) {
                        TextButton(onClick = { onApproval(run, true) }) { Text(stringResource(R.string.action_approve)) }
                        TextButton(onClick = { onApproval(run, false) }) { Text(stringResource(R.string.action_reject)) }
                    }
                }
                run.error?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GlobalAgentScreen(state: UiState, viewModel: AppViewModel) {
    val sessions = state.sessions.filter { it.source == "global_agent" }
    Scaffold(topBar = { TopAppBar(title = { Text(stringResource(R.string.global_agent_title)) }, navigationIcon = { IconButton(viewModel::back) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.action_back)) } }, actions = { IconButton(viewModel::refreshSessions) { Icon(Icons.Filled.Refresh, stringResource(R.string.action_refresh)) } }) }) { padding ->
        LazyColumn(Modifier.fillMaxSize().padding(padding), contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item { Text(stringResource(R.string.global_agent_description), style = MaterialTheme.typography.bodyLarge) }
            item { Text(stringResource(R.string.global_agent_profile, state.activeProfile.ifBlank { "default" }), color = MaterialTheme.colorScheme.onSurfaceVariant) }
            item { Button(onClick = viewModel::startGlobalAgentConversation, Modifier.fillMaxWidth()) { Text(stringResource(R.string.global_agent_open)) } }
            item { Text(stringResource(R.string.global_agent_remote_note), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
            if (sessions.isNotEmpty()) item { Text(stringResource(R.string.global_agent_sessions), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold) }
            items(sessions, key = { it.id }) { session ->
                Card(Modifier.fillMaxWidth().clickable { viewModel.openSession(session) }, shape = RoundedCornerShape(18.dp)) {
                    Column(Modifier.padding(15.dp)) { Text(session.title, fontWeight = FontWeight.Bold); Text(session.updatedAt.orEmpty(), style = MaterialTheme.typography.labelSmall) }
                }
            }
        }
    }
}
