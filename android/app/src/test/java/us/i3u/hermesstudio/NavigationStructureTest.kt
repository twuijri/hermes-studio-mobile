package us.i3u.hermesstudio

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Keeps the mobile information architecture from drifting back into Settings-in-Settings. */
class NavigationStructureTest {

    private val viewModel = File("src/main/java/us/i3u/hermesstudio/AppViewModel.kt").readText()
    private val activity = File("src/main/java/us/i3u/hermesstudio/MainActivity.kt").readText()
    private val kanban = File("src/main/java/us/i3u/hermesstudio/KanbanScreens.kt").readText()

    @Test
    fun agentIsAFirstClassRootTab() {
        assertTrue(viewModel.contains("enum class Tab { Chats, Groups, Agent }"))
        assertTrue(activity.contains("viewModel.showTab(Tab.Agent)"))
        assertTrue(activity.contains("Screen.AgentHub -> AgentHubScreen"))
    }

    @Test
    fun agentHubOwnsAgentToolsAndIntelligence() {
        val hub = activity.substringAfter("private fun AgentHubScreen")
            .substringBefore("/** App settings stay intentionally small")

        listOf(
            "openCronJobs()",
            "openChannels()",
            "SettingsGroup.Memory",
            "SettingsGroup.Models",
            "openKanban()",
            "openSkills()",
            "openPlugins()",
            "openMcp()",
            "openPets()",
        ).forEach { destination -> assertTrue("Agent hub lost $destination", hub.contains(destination)) }
        listOf("SettingsGroup.Profile", "SettingsGroup.Agent").forEach { setting ->
            assertFalse("Agent hub should not duplicate $setting", hub.contains(setting))
        }
        assertFalse("Agent tools must never open the website", hub.contains("ACTION_VIEW"))
        assertFalse("Agent tools must never open the website", hub.contains("openStudioTool"))
    }

    @Test
    fun settingsHomeHasOneDoorToNonAgentStudioSettings() {
        val settings = activity.substringAfter("private fun SettingsScreen")
            .substringBefore("/** The non-agent Studio settings")
        assertTrue(settings.contains("openMoreSettings()"))
        assertTrue(settings.contains("SettingsGroup.Device"))
        assertTrue(settings.contains("SettingsGroup.About"))
        listOf("SettingsGroup.Agent", "SettingsGroup.Memory", "SettingsGroup.Models", "openCronJobs()", "openChannels()")
            .forEach { duplicate -> assertFalse("Settings home duplicates $duplicate", settings.contains(duplicate)) }
    }

    @Test
    fun moreSettingsOwnsTheRemainingStudioConfiguration() {
        val more = activity.substringAfter("private fun MoreSettingsScreen")
            .substringBefore("private fun SettingsGroupScreen")
        listOf(
            "SettingsGroup.Server",
            "SettingsGroup.Users",
            "SettingsGroup.Profile",
            "SettingsGroup.Agent",
            "SettingsGroup.Compression",
            "SettingsGroup.Sessions",
            "SettingsGroup.Privacy",
            "SettingsGroup.Proxy",
            "SettingsGroup.Display",
        ).forEach { group -> assertTrue("More settings lost $group", more.contains(group)) }
        listOf("SettingsGroup.Memory", "SettingsGroup.Models")
            .forEach { duplicate -> assertFalse("More settings duplicates $duplicate", more.contains(duplicate)) }
    }

    @Test
    fun kanbanHasNativeAccessibleMovementInBothDirections() {
        assertTrue(kanban.contains("detectDragGesturesAfterLongPress"))
        assertTrue(kanban.contains("LocalLayoutDirection.current"))
        assertTrue(kanban.contains("graphicsLayer { translationX = dragX }"))
        assertTrue(kanban.contains("DropdownMenuItem"))
    }
}
