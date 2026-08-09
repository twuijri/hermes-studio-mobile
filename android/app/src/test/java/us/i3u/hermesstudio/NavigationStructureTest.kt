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
    fun settingsHasOneRootEntryPointAndTabsAlwaysNavigateHome() {
        val chats = activity.substringAfter("private fun ChatsScreen")
            .substringBefore("private fun ProfileFilterRow")
        val agent = activity.substringAfter("private fun AgentHubScreen")
            .substringBefore("/** App settings stay intentionally small")

        assertFalse("Chats must not duplicate the Settings shortcut", chats.contains("openSettings()"))
        assertTrue("Agent must retain the Settings shortcut", agent.contains("openSettings()"))
        listOf("Tab.Chats", "Tab.Groups", "Tab.Agent").forEach { tab ->
            assertTrue("Bottom tab must always navigate to $tab home", activity.contains("onClick = { viewModel.showTab($tab) }"))
        }
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
    fun settingsHomeMatchesThePhoneInformationArchitecture() {
        val settings = activity.substringAfter("private fun SettingsScreen")
            .substringBefore("/** The non-agent Studio settings")
        assertTrue(settings.contains("openMoreSettings()"))
        assertTrue(settings.contains("SettingsGroup.Account"))
        assertTrue(settings.contains("SettingsGroup.Server"))
        assertTrue(settings.contains("openProfiles()"))
        assertTrue(settings.contains("PHONE_REPOSITORY_URL"))
        assertTrue(settings.contains("STUDIO_REPOSITORY_URL"))
        listOf("SettingsGroup.Agent", "SettingsGroup.Memory", "SettingsGroup.Models", "openCronJobs()", "openChannels()")
            .forEach { duplicate -> assertFalse("Settings home duplicates $duplicate", settings.contains(duplicate)) }
    }

    @Test
    fun moreSettingsUsesTheSameGroupsAsIPhone() {
        val more = activity.substringAfter("private fun MoreSettingsScreen")
            .substringBefore("private fun SettingsGroupScreen")
        listOf(
            "SettingsGroup.Users",
            "SettingsGroup.Agent",
            "SettingsGroup.Memory",
            "SettingsGroup.Compression",
            "SettingsGroup.Models",
            "SettingsGroup.Sessions",
            "SettingsGroup.Privacy",
            "SettingsGroup.Proxy",
            "SettingsGroup.Display",
        ).forEach { group -> assertTrue("More settings lost $group", more.contains(group)) }
        listOf("SettingsGroup.Server", "SettingsGroup.Profile")
            .forEach { duplicate -> assertFalse("Top-level setting leaked into More settings: $duplicate", more.contains(duplicate)) }
    }

    @Test
    fun kanbanHasNativeAccessibleMovementInBothDirections() {
        assertTrue(kanban.contains("detectDragGesturesAfterLongPress"))
        assertTrue(kanban.contains("LocalLayoutDirection.current"))
        assertTrue(kanban.contains("graphicsLayer { translationX = dragX }"))
        assertTrue(kanban.contains("DropdownMenuItem"))
    }

    @Test
    fun profilesReturnsToTheScreenThatOpenedIt() {
        assertTrue(viewModel.contains("val profilesReturnScreen: Screen"))
        assertTrue(viewModel.contains("Screen.Profiles -> state.profilesReturnScreen"))
        assertTrue(viewModel.contains("fun openProfiles()"))
        assertFalse("callers must not bypass origin tracking", activity.contains("show(Screen.Profiles)"))
    }
}
