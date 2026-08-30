package us.i3u.hermesstudio

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
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
fun EkkoHubScreen(state: UiState, viewModel: AppViewModel) {
    var editMemory by remember { mutableStateOf<EkkoMemory?>(null) }
    var editMcp by remember { mutableStateOf<EkkoMcpServer?>(null) }
    var newMcp by remember { mutableStateOf(false) }
    editMemory?.let { memory -> EkkoMemoryDialog(memory, { editMemory = null }, { title, content -> editMemory = null; viewModel.saveEkkoMemory(memory, title, content) }) }
    if (newMcp || editMcp != null) {
        val original = editMcp?.name
        EkkoMcpDialog(editMcp, { newMcp = false; editMcp = null }) { name, config -> newMcp = false; editMcp = null; viewModel.saveEkkoMcp(original, name, config) }
    }
    Scaffold(topBar = { TopAppBar(title = { Text(stringResource(R.string.ekko_hub_title)) }, navigationIcon = { IconButton(viewModel::back) { Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.action_back)) } }, actions = { IconButton(viewModel::openEkkoHub) { Icon(Icons.Filled.Refresh, stringResource(R.string.action_refresh)) } }) }) { padding ->
        LazyColumn(Modifier.fillMaxSize().padding(padding), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            state.error?.let { item { Text(it, color = MaterialTheme.colorScheme.error) } }
            item { SectionTitle(stringResource(R.string.ekko_memory_title), state.ekkoMemories.size) }
            items(state.ekkoMemories, key = { it.id }) { memory ->
                HubCard { Column(Modifier.weight(1f)) { Text(memory.title.ifBlank { memory.id }, fontWeight = FontWeight.Bold); Text(memory.content, maxLines = 3); Text(memory.status + " · r" + memory.revision, style = MaterialTheme.typography.labelSmall) }; TextButton(onClick = { editMemory = memory }) { Text(stringResource(R.string.action_edit)) }; TextButton(onClick = { viewModel.deleteEkkoMemory(memory) }) { Text(stringResource(R.string.action_delete)) } }
            }
            item { SectionTitle(stringResource(R.string.ekko_skills_title), state.ekkoSkills.sumOf { it.skills.size }) }
            state.ekkoSkills.flatMap { it.skills }.forEach { skill -> item(key = "skill-${skill.name}") { HubCard { Column(Modifier.weight(1f)) { Text(skill.name, fontWeight = FontWeight.Bold); Text(skill.description, maxLines = 2) }; Switch(skill.enabled, { viewModel.toggleEkkoSkill(skill) }) } } }
            item { Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) { SectionTitle(stringResource(R.string.ekko_mcp_title), state.ekkoMcpServers.size, Modifier.weight(1f)); Button(onClick = { newMcp = true }) { Text(stringResource(R.string.action_add)) } } }
            items(state.ekkoMcpServers, key = { it.name }) { server -> HubCard { Column(Modifier.weight(1f)) { Text(server.name, fontWeight = FontWeight.Bold); Text(server.transport) }; Switch(server.enabled, { viewModel.toggleEkkoMcp(server) }); TextButton(onClick = { viewModel.testEkkoMcp(server) }) { Text(stringResource(R.string.action_test)) }; TextButton(onClick = { editMcp = server }) { Text(stringResource(R.string.action_edit)) }; TextButton(onClick = { viewModel.deleteEkkoMcp(server) }) { Text(stringResource(R.string.action_delete)) } } }
        }
    }
}

@Composable private fun HubCard(content: @Composable RowScope.() -> Unit) { Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)) { Row(Modifier.fillMaxWidth().padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp), content = content) } }
@Composable private fun SectionTitle(text: String, count: Int, modifier: Modifier = Modifier) { Text("$text · $count", modifier.padding(top = 10.dp), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold) }

@Composable private fun EkkoMemoryDialog(memory: EkkoMemory, dismiss: () -> Unit, save: (String, String) -> Unit) { var title by remember { mutableStateOf(memory.title) }; var content by remember { mutableStateOf(memory.content) }; AlertDialog(onDismissRequest = dismiss, title = { Text(stringResource(R.string.ekko_memory_edit)) }, text = { Column { OutlinedTextField(title, { title = it }, label = { Text(stringResource(R.string.ekko_memory_name)) }); OutlinedTextField(content, { content = it }, label = { Text(stringResource(R.string.ekko_memory_content)) }, minLines = 5) } }, confirmButton = { TextButton(onClick = { save(title, content) }) { Text(stringResource(R.string.action_save)) } }, dismissButton = { TextButton(onClick = dismiss) { Text(stringResource(R.string.action_cancel)) } }) }
@Composable private fun EkkoMcpDialog(server: EkkoMcpServer?, dismiss: () -> Unit, save: (String, String) -> Unit) { var name by remember { mutableStateOf(server?.name.orEmpty()) }; var config by remember { mutableStateOf(server?.config ?: "{\n  \"transport\": \"stdio\",\n  \"command\": \"\"\n}") }; AlertDialog(onDismissRequest = dismiss, title = { Text(stringResource(R.string.ekko_mcp_edit)) }, text = { Column { OutlinedTextField(name, { name = it }, label = { Text(stringResource(R.string.mcp_name)) }); OutlinedTextField(config, { config = it }, label = { Text(stringResource(R.string.mcp_advanced_json)) }, minLines = 7) } }, confirmButton = { TextButton(enabled = name.isNotBlank(), onClick = { save(name, config) }) { Text(stringResource(R.string.action_save)) } }, dismissButton = { TextButton(onClick = dismiss) { Text(stringResource(R.string.action_cancel)) } }) }
