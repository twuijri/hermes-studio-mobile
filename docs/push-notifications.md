# Mobile push notifications

Hermes Studio Mobile must not request notification permission until the connected
Studio server confirms that native push delivery is configured. The existing
Studio `display.notify_on_complete` option is a browser/desktop preference; it
does not send notifications through APNs or FCM and must not be presented as a
native mobile push switch.

## Current Studio support

The upstream Studio server already exposes the useful completion signal:

- `/chat-run` emits `run.completed` and `run.failed`.
- App Relay forwards every server-emitted `/chat-run` event to a paired mobile
  connection.
- Cron output is durable and can be read from `/api/cron-history`.

Those mechanisms work while a client connection is alive. A suspended or
terminated mobile app still needs a provider server to send through Apple Push
Notification service (APNs) and Firebase Cloud Messaging (FCM). Upstream Studio
does not currently expose device registration or native push delivery endpoints.

## Required server contract

The mobile apps will enable their native notification control only after this
authenticated capability request succeeds:

```http
GET /api/mobile-notifications/capabilities
Authorization: Bearer <Studio user token>
```

```json
{
  "enabled": true,
  "events": ["chat.completed", "chat.failed", "approval.required", "cron.completed", "cron.failed"],
  "platforms": { "ios": true, "android": true },
  "android": {
    "projectId": "public Firebase project id",
    "applicationId": "public Firebase application id",
    "apiKey": "public Firebase API key",
    "senderId": "public Firebase sender id"
  }
}
```

Registration is idempotent and scoped to the authenticated Studio user:

```http
PUT /api/mobile-notifications/devices/{installationId}
DELETE /api/mobile-notifications/devices/{installationId}
POST /api/mobile-notifications/devices/{installationId}/test
```

```json
{
  "platform": "ios",
  "token": "current APNs or FCM token",
  "bundleId": "us.i3u.hermesstudio.ios",
  "locale": "ar-SA",
  "profiles": ["manager"],
  "appVersion": "1.2.0"
}
```

The server must never accept a user id from this body. It derives the owner from
the bearer token, encrypts provider tokens at rest, supports multiple devices per
user, removes invalid provider tokens, and suppresses a push when the same user
has that conversation open in a foreground mobile connection.

Every payload uses a stable event id for deduplication and contains only a short,
privacy-safe preview. Opening it deep-links to the relevant session, room,
approval, or cron run; authentication and profile authorization remain
authoritative on the Studio server.

## Delivery points

The Studio server should publish a notification event after durable state has
been written, not merely when a socket packet is emitted:

- direct chat `run.completed` / `run.failed`;
- group reply completion;
- approval or clarification requested;
- cron run output or failure recorded;
- workflow completion when a user explicitly subscribes to it.

App Relay is the preferred path for online mobile state and foreground
suppression. APNs/FCM is the required path when the app is suspended or closed.

## Platform prerequisites

- iOS: a paid Apple Developer Program team, Push Notifications capability on
  the App ID, an APNs signing key stored only on the provider server, and token
  registration on every launch. Do not add the `aps-environment` entitlement to
  Personal Team builds before the paid team is ready.
- Android: a Firebase project for `us.i3u.hermesstudio`, FCM server credentials
  stored only on the provider server, and public Firebase client configuration
  returned by the capability endpoint or packaged in the release.

Until all prerequisites and the capability endpoint exist, both apps keep the
native notification permission untouched and continue to refresh conversations
normally when opened.

## Plugin-first deployment without an upstream Studio patch

Hermes Agent user plugins provide a practical first release that does not need
changes merged into Hermes Studio. A standalone `hermes-mobile-notifications`
plugin can register the Agent `post_llm_call` hook and send a signed, minimal
completion event to a Hermes Mobile notification relay. Users install it under
`~/.hermes/plugins/`, enable it for each desired profile from Studio's Plugins
screen, and pair it with the mobile app using a short-lived code.

The plugin and relay have different responsibilities:

- the plugin observes successful Hermes Agent turns and sends `session_id`,
  profile, event id, timestamp, and a privacy-limited preview over HTTPS;
- the relay owns the APNs key and FCM service credentials, maps paired installs
  to device tokens, deduplicates events, and sends the native push;
- the mobile app owns notification permission and deep-links the notification
  back to the authenticated conversation.

This can cover ordinary Hermes Agent turns and Agent-powered scheduled runs. It
cannot promise every Studio event by itself: Studio-native coding-agent paths,
groups, approvals, failures before `post_llm_call`, and any cron executor that
bypasses the Hermes Agent plugin lifecycle need either a matching generic Agent
hook or the server event contract above. The first plugin release must advertise
the exact event coverage it detects instead of claiming universal delivery.

The plugin should never contain APNs or FCM server secrets, and it should not
accept a permanent Studio bearer token. Pairing produces a revocable,
installation-scoped signing secret. Users can therefore uninstall or disable the
plugin without modifying Studio core, while a later upstream event bridge can
expand coverage without changing the app-facing notification model.
