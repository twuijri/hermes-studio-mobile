# Hermes Studio Mobile — iOS

A native SwiftUI companion for [Hermes Studio](https://github.com/EKKOLearnAI/hermes-studio). It connects directly to the same REST and Socket.IO endpoints as Studio and keeps the bearer token in the iOS Keychain.

Current release: **1.3.0**. The public version is kept in sync with the Android app.

## Included

- Chats with streaming text, live reasoning, tool progress, attachments, voice transcription, downloadable agent files, pull-to-refresh and automatic last-message positioning.
- Group rooms with live people/agent messages and agent management.
- A mobile Kanban board with drag and drop, task creation, assignment and comments.
- Scheduled jobs, channels, skills, plugins, MCP servers, pets, memory and model management.
- Account, profiles, connection, appearance, Arabic RTL and all Studio configuration sections collected under More Settings.
- Hermes app icon and the short Home Screen name `H Studio`; the product name remains `Hermes Studio`.

## Branding and distribution

The install target includes every required iPhone and iPad icon size directly, generated from the 1024 px master. The App Store asset catalog is retained in `Design/Assets.xcassets`, and the editable vector master is `AppIcon.svg`. When preparing an App Store archive with a current Xcode release, add that catalog to the app target and select `AppIcon` as the App Icons Source.

## Install on a personal iPhone

1. Open `HermesStudio.xcodeproj` in Xcode.
2. Select the `HermesStudio` target, open **Signing & Capabilities**, and choose your Apple ID's Personal Team.
3. Connect the iPhone, choose it as the run destination and press Run.
4. If iOS asks, enable Developer Mode and trust the developer profile in **Settings > General > VPN & Device Management**.

A free Personal Team installation normally needs to be signed again after seven days. TestFlight and App Store distribution require the paid Apple Developer Program.
