package us.i3u.hermesstudio

import androidx.annotation.DrawableRes
import androidx.annotation.StringRes

enum class ChannelFieldKind { Text, Secret, Toggle, CommaList }
enum class ChannelFieldTarget { Credentials, Configuration }

/** One editable value from Studio's PlatformSettings schema. */
data class ChannelField(
    val path: String,
    @StringRes val labelRes: Int,
    @StringRes val hintRes: Int? = null,
    val kind: ChannelFieldKind = ChannelFieldKind.Secret,
    val target: ChannelFieldTarget = ChannelFieldTarget.Credentials,
    val placeholder: String = "",
    val defaultEnabled: Boolean = false,
)

data class ChannelSpec(
    val platform: String,
    val label: String,
    /** The same platform mark shown by Hermes Studio. */
    @DrawableRes val iconRes: Int,
    val fields: List<ChannelField>,
    /** Studio warns that these identities may only belong to one profile. */
    val exclusive: Boolean = false,
    /** WhatsApp enablement is not part of Studio's credential-clear allowlist. */
    val supportsCredentialClear: Boolean = true,
)

private fun credential(
    path: String,
    @StringRes label: Int,
    @StringRes hint: Int? = null,
    kind: ChannelFieldKind = ChannelFieldKind.Secret,
    placeholder: String = "",
    defaultEnabled: Boolean = false,
) = ChannelField(path, label, hint, kind, ChannelFieldTarget.Credentials, placeholder, defaultEnabled)

private fun setting(
    path: String,
    @StringRes label: Int,
    @StringRes hint: Int? = null,
    kind: ChannelFieldKind = ChannelFieldKind.Toggle,
    placeholder: String = "",
    defaultEnabled: Boolean = false,
) = ChannelField(path, label, hint, kind, ChannelFieldTarget.Configuration, placeholder, defaultEnabled)

/**
 * Kept in the same order and with the same fields as Studio's
 * `PlatformSettings.vue`. Paths are accepted verbatim by the stock server.
 */
val CHANNELS = listOf(
    ChannelSpec(
        platform = "telegram",
        label = "Telegram",
        iconRes = R.drawable.ic_channel_telegram,
        exclusive = true,
        fields = listOf(
            credential("token", R.string.channel_bot_token, R.string.channel_bot_token_hint, placeholder = "123456:ABC-DEF…"),
            credential("proxy", R.string.channel_proxy_url, R.string.channel_proxy_url_hint, ChannelFieldKind.Text, "socks5://127.0.0.1:7890"),
            setting("require_mention", R.string.channel_require_mention, R.string.channel_require_mention_group),
            setting("reactions", R.string.channel_reactions, R.string.channel_reactions_hint),
            setting("free_response_chats", R.string.channel_free_response_chats, R.string.channel_free_response_chats_hint, ChannelFieldKind.Text, "chat_id1,chat_id2"),
            setting("mention_patterns", R.string.channel_mention_patterns, R.string.channel_mention_patterns_hint, ChannelFieldKind.CommaList, "pattern1, pattern2"),
        ),
    ),
    ChannelSpec(
        platform = "discord",
        label = "Discord",
        iconRes = R.drawable.ic_channel_discord,
        exclusive = true,
        fields = listOf(
            credential("token", R.string.channel_bot_token, R.string.channel_bot_token_hint, placeholder = "Bot token…"),
            credential("proxy", R.string.channel_proxy_url, R.string.channel_proxy_url_hint, ChannelFieldKind.Text, "socks5://127.0.0.1:7890"),
            setting("require_mention", R.string.channel_require_mention, R.string.channel_require_mention_channel),
            setting("auto_thread", R.string.channel_auto_thread, R.string.channel_auto_thread_channel),
            setting("reactions", R.string.channel_reactions, R.string.channel_reactions_hint),
            setting("free_response_channels", R.string.channel_free_response_channels, R.string.channel_free_response_channels_hint, ChannelFieldKind.Text, "channel_id1,channel_id2"),
            setting("allowed_channels", R.string.channel_allowed_channels, R.string.channel_allowed_channels_hint, ChannelFieldKind.Text, "channel_id1,channel_id2"),
            setting("ignored_channels", R.string.channel_ignored_channels, R.string.channel_ignored_channels_hint, ChannelFieldKind.Text, "channel_id1,channel_id2"),
            setting("no_thread_channels", R.string.channel_no_thread_channels, R.string.channel_no_thread_channels_hint, ChannelFieldKind.Text, "channel_id1,channel_id2"),
        ),
    ),
    ChannelSpec(
        platform = "slack",
        label = "Slack",
        iconRes = R.drawable.ic_channel_slack,
        exclusive = true,
        fields = listOf(
            credential("token", R.string.channel_bot_token, R.string.channel_bot_token_hint, placeholder = "xoxb-…"),
            setting("require_mention", R.string.channel_require_mention, R.string.channel_require_mention_channel),
            setting("allow_bots", R.string.channel_allow_bots, R.string.channel_allow_bots_hint),
            setting("free_response_channels", R.string.channel_free_response_channels, R.string.channel_free_response_channels_hint, ChannelFieldKind.Text, "channel_id1,channel_id2"),
        ),
    ),
    ChannelSpec(
        platform = "whatsapp",
        label = "WhatsApp",
        iconRes = R.drawable.ic_channel_whatsapp,
        exclusive = true,
        supportsCredentialClear = false,
        fields = listOf(
            credential("enabled", R.string.channel_whatsapp_enabled, R.string.channel_whatsapp_enabled_hint, ChannelFieldKind.Toggle),
            setting("require_mention", R.string.channel_require_mention, R.string.channel_require_mention_group),
            setting("free_response_chats", R.string.channel_free_response_chats, R.string.channel_free_response_chats_hint, ChannelFieldKind.Text, "chat_id1,chat_id2"),
            setting("mention_patterns", R.string.channel_mention_patterns, R.string.channel_mention_patterns_hint, ChannelFieldKind.CommaList, "pattern1, pattern2"),
        ),
    ),
    ChannelSpec(
        platform = "matrix",
        label = "Matrix",
        iconRes = R.drawable.ic_channel_matrix,
        fields = listOf(
            credential("token", R.string.channel_access_token, R.string.channel_access_token_hint, placeholder = "syt_…"),
            credential("extra.user_id", R.string.channel_matrix_user_id, R.string.channel_matrix_user_id_hint, ChannelFieldKind.Text, "@hermes:example.org"),
            credential("extra.password", R.string.channel_matrix_password, R.string.channel_matrix_password_hint),
            credential("extra.homeserver", R.string.channel_homeserver, R.string.channel_homeserver_hint, ChannelFieldKind.Text, "https://matrix.org"),
            credential("proxy", R.string.channel_proxy_url, R.string.channel_proxy_url_hint, ChannelFieldKind.Text, "socks5://127.0.0.1:7890"),
            setting("require_mention", R.string.channel_require_mention, R.string.channel_require_mention_room),
            setting("auto_thread", R.string.channel_auto_thread, R.string.channel_auto_thread_room),
            setting("dm_mention_threads", R.string.channel_dm_mention_threads, R.string.channel_dm_mention_threads_hint),
            setting("free_response_rooms", R.string.channel_free_response_rooms, R.string.channel_free_response_rooms_hint, ChannelFieldKind.Text, "room_id1,room_id2"),
        ),
    ),
    ChannelSpec(
        platform = "weixin",
        label = "Weixin",
        iconRes = R.drawable.ic_channel_weixin,
        exclusive = true,
        fields = listOf(
            credential("token", R.string.channel_weixin_token, R.string.channel_weixin_token_hint),
            credential("extra.account_id", R.string.channel_account_id, R.string.channel_account_id_hint, ChannelFieldKind.Text),
        ),
    ),
    ChannelSpec(
        platform = "wecom",
        label = "WeCom",
        iconRes = R.drawable.ic_channel_wecom,
        fields = listOf(
            credential("extra.bot_id", R.string.channel_bot_id, R.string.channel_bot_id_hint, ChannelFieldKind.Text),
            credential("extra.secret", R.string.channel_app_secret, R.string.channel_wecom_secret_hint),
        ),
    ),
    ChannelSpec(
        platform = "feishu",
        label = "Feishu",
        iconRes = R.drawable.ic_channel_feishu,
        exclusive = true,
        fields = listOf(
            credential("extra.app_id", R.string.channel_app_id, R.string.channel_app_id_hint, ChannelFieldKind.Text, "cli_…"),
            credential("extra.app_secret", R.string.channel_app_secret, R.string.channel_app_secret_hint),
            credential("extra.encrypt_key", R.string.channel_encrypt_key, R.string.channel_encrypt_key_hint),
            credential("extra.verification_token", R.string.channel_verification_token, R.string.channel_verification_token_hint),
            setting("require_mention", R.string.channel_require_mention, R.string.channel_require_mention_group),
            setting("free_response_chats", R.string.channel_free_response_chats, R.string.channel_free_response_chats_hint, ChannelFieldKind.Text, "chat_id1,chat_id2"),
        ),
    ),
    ChannelSpec(
        platform = "dingtalk",
        label = "DingTalk",
        iconRes = R.drawable.ic_channel_dingtalk,
        exclusive = true,
        fields = listOf(
            credential("extra.client_id", R.string.channel_client_id, R.string.channel_client_id_hint, ChannelFieldKind.Text),
            credential("extra.client_secret", R.string.channel_client_secret, R.string.channel_client_secret_hint),
            credential("extra.app_key", R.string.channel_app_key, R.string.channel_app_key_hint, ChannelFieldKind.Text),
            credential("extra.card_template_id", R.string.channel_card_template_id, R.string.channel_card_template_id_hint, ChannelFieldKind.Text),
            credential("allow_all_users", R.string.channel_allow_all_users, R.string.channel_allow_all_users_hint, ChannelFieldKind.Toggle),
            credential("allowed_users", R.string.channel_allowed_users, R.string.channel_allowed_users_hint, ChannelFieldKind.Text, "user_id1,user_id2"),
            setting("require_mention", R.string.channel_require_mention, R.string.channel_require_mention_group),
            setting("free_response_chats", R.string.channel_free_response_chats, R.string.channel_free_response_chats_hint, ChannelFieldKind.Text, "chat_id1,chat_id2"),
        ),
    ),
    ChannelSpec(
        platform = "qqbot",
        label = "QQ Bot",
        iconRes = R.drawable.ic_channel_qqbot,
        exclusive = true,
        fields = listOf(
            credential("extra.app_id", R.string.channel_qq_app_id, R.string.channel_qq_app_id_hint, ChannelFieldKind.Text),
            credential("extra.client_secret", R.string.channel_qq_secret, R.string.channel_qq_secret_hint),
            credential("allowed_users", R.string.channel_allowed_users, R.string.channel_allowed_users_hint, ChannelFieldKind.Text, "openid1,openid2"),
            credential("allow_all_users", R.string.channel_allow_all_users, R.string.channel_allow_all_users_hint, ChannelFieldKind.Toggle),
            setting("extra.markdown_support", R.string.channel_qq_markdown, R.string.channel_qq_markdown_hint, defaultEnabled = true),
        ),
    ),
)

fun channelSpec(platform: String): ChannelSpec =
    CHANNELS.firstOrNull { it.platform == platform }
        ?: ChannelSpec(
            platform = platform,
            label = platform.replaceFirstChar { it.uppercase() },
            iconRes = R.drawable.ic_channel_matrix,
            fields = emptyList(),
            supportsCredentialClear = false,
        )
