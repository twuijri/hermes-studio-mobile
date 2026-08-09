package us.i3u.hermesstudio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Keeps both mobile channel editors aligned with Studio's PlatformSettings schema. */
class ChannelSchemaTest {
    @Test
    fun telegramExposesEveryStudioOption() {
        val telegram = channelSpec("telegram")
        assertTrue(telegram.exclusive)
        assertEquals(
            listOf(
                "token", "proxy", "require_mention", "reactions",
                "free_response_chats", "mention_patterns",
            ),
            telegram.fields.map { it.path },
        )
        assertEquals(
            listOf(
                ChannelFieldTarget.Credentials,
                ChannelFieldTarget.Credentials,
                ChannelFieldTarget.Configuration,
                ChannelFieldTarget.Configuration,
                ChannelFieldTarget.Configuration,
                ChannelFieldTarget.Configuration,
            ),
            telegram.fields.map { it.target },
        )
    }

    @Test
    fun everyChannelHasEditableSchemaAndSafeClearPolicy() {
        assertTrue(CHANNELS.all { it.fields.isNotEmpty() })
        assertFalse(channelSpec("whatsapp").supportsCredentialClear)
        assertTrue(CHANNELS.filterNot { it.platform == "whatsapp" }.all { it.supportsCredentialClear })
        assertTrue(channelSpec("matrix").fields.any { it.path == "extra.homeserver" })
        assertTrue(channelSpec("discord").fields.any { it.path == "no_thread_channels" })
        assertTrue(channelSpec("qqbot").fields.any { it.path == "extra.markdown_support" })
    }

    @Test
    fun allNestedAndroidPagesKeepTheRootTabsLikeIos() {
        val files = listOf(
            "MainActivity.kt",
            "AgentToolScreens.kt",
            "CronJobs.kt",
            "KanbanScreens.kt",
        ).associateWith { name ->
            File("src/main/java/us/i3u/hermesstudio/$name").readText()
        }
        val nestedScreens = listOf(
            "RoomScreen" to "MainActivity.kt",
            "ConversationScreen" to "MainActivity.kt",
            "ProfilesScreen" to "MainActivity.kt",
            "SettingsScreen" to "MainActivity.kt",
            "MoreSettingsScreen" to "MainActivity.kt",
            "SettingsGroupScreen" to "MainActivity.kt",
            "ChannelsScreen" to "MainActivity.kt",
            "ChannelScreen" to "MainActivity.kt",
            "SkillsScreen" to "AgentToolScreens.kt",
            "SkillScreen" to "AgentToolScreens.kt",
            "PluginsScreen" to "AgentToolScreens.kt",
            "McpScreen" to "AgentToolScreens.kt",
            "PetsScreen" to "AgentToolScreens.kt",
            "CronJobsScreen" to "CronJobs.kt",
            "CronJobEditorScreen" to "CronJobs.kt",
            "CronHistoryScreen" to "CronJobs.kt",
            "KanbanScreen" to "KanbanScreens.kt",
            "KanbanTaskScreen" to "KanbanScreens.kt",
        )
        nestedScreens.forEach { (screen, file) ->
            val body = files.getValue(file).substringAfter("fun $screen").substringBefore("\n@OptIn", missingDelimiterValue = files.getValue(file).substringAfter("fun $screen"))
            assertTrue("$screen lost its persistent root tabs", body.contains("bottomBar = { StudioTabs(state, viewModel) }"))
        }
    }
}
