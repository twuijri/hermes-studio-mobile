# Hermes Studio Mobile

Native mobile clients for [Hermes Studio](https://github.com/EKKOLearnAI/hermes-studio), kept together so the Android and iOS experiences can evolve as one product.

Current mobile release: **1.2.0**

`VERSION` is the shared public version source. The Android and iOS workflows run
`scripts/check-version.sh` and reject a build if either platform drifts from it.

| Platform | Source | Local build |
| --- | --- | --- |
| Android | [`android/`](android/) | `cd android && gradle assembleDebug` |
| iOS | [`ios/`](ios/) | Open `ios/HermesStudio.xcodeproj` in Xcode |

Both apps connect directly to the same Hermes Studio REST and Socket.IO APIs. They share the same product structure—Chats, Groups, Agent tools, native Kanban, jobs, channels, skills, plugins, MCP, profiles, and Studio settings—while following the interaction and navigation conventions of each platform.

Native notifications that arrive while an app is closed require a small server
addition on top of Studio's existing completion events. The capability-gated,
privacy-safe contract and its APNs/FCM prerequisites are documented in
[`docs/push-notifications.md`](docs/push-notifications.md).

## Install

- **Android:** download [`hermes-studio-android.apk`](https://github.com/twuijri/hermes-studio-mobile/releases/tag/latest-debug) from the rolling release.
- **iPhone:** open the Xcode project, choose your Apple Development team, connect the device, and press Run. TestFlight/App Store distribution can be added when the Apple Developer account is ready.

Platform-specific requirements, architecture notes, and development commands are documented in the [Android README](android/README.md) and [iOS README](ios/README.md).

This is an unofficial, community-built client and is not affiliated with EKKOLearnAI.

## License

MIT — see [LICENSE](LICENSE).
