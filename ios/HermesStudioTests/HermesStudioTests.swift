import XCTest
@testable import HermesStudio

final class HermesStudioTests: XCTestCase {
    func testSocketUsageSupportsStudioContextFields() {
        let packet = #"42/chat-run,["run.completed",{"contextTokens":24000,"contextWindow":128000}]"#
        let event = ChatSocket.event(packet, namespace: "/chat-run")
        XCTAssertEqual(event?.1.int("contextTokens"), 24_000)
        XCTAssertEqual(event?.1.int("contextWindow"), 128_000)
    }
    func testExtractsStandardStudioFileLink() {
        let links = ChatFiles.links(in: "[Download report](/home/agent/.hermes/profiles/main/workspace/report.pdf)")
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.label, "Download report")
        XCTAssertEqual(links.first?.path, "/home/agent/.hermes/profiles/main/workspace/report.pdf")
    }

    func testExtractsMalformedAgentLink() {
        let text = "[تحميل العرض](</home/agent/.hermes/profiles/main/workspace/deck.pptx>)"
        let links = ChatFiles.links(in: text)
        XCTAssertEqual(links.first?.path, "/home/agent/.hermes/profiles/main/workspace/deck.pptx")
        XCTAssertEqual(ChatFiles.fileName(for: links[0]), "deck.pptx")
    }

    func testStudioAudioContentBlockRendersAsAttachment() throws {
        let parsed = ChatFiles.parse(#"[{"type":"file","name":"voice-1786646557278.m4a","path":"/home/agent/.hermes-web-ui/upload/manager/bbdd9dabb00e962d.m4a","media_type":"audio/mp4"}]"#)

        XCTAssertTrue(parsed.text.isEmpty)
        XCTAssertEqual(parsed.files.count, 1)
        XCTAssertEqual(parsed.files.first?.label, "voice-1786646557278.m4a")
        XCTAssertEqual(parsed.files.first?.path, "/home/agent/.hermes-web-ui/upload/manager/bbdd9dabb00e962d.m4a")
    }

    func testParsesSocketEvent() {
        let packet = #"42/chat-run,["message.delta",{"delta":"hello"}]"#
        let event = ChatSocket.event(packet, namespace: "/chat-run")
        XCTAssertEqual(event?.0, "message.delta")
        XCTAssertEqual(event?.1.string("delta"), "hello")
    }

    func testResumeRecoversAnswerCompletedDuringDisconnect() {
        let payload: JSON = [
            "isWorking": false,
            "messages": [
                ["role": "assistant", "content": "old answer"],
                ["role": "user", "content": "voice attachment"],
                ["role": "assistant", "content": "transcription completed", "reasoning": "audio processed"],
            ],
        ]

        let completion = ChatSocket.completion(fromResume: payload)

        XCTAssertEqual(completion?.output, "transcription completed")
        XCTAssertEqual(completion?.reasoning, "audio processed")
    }

    func testConversationMessageKeepsStudioUnixTimestamp() throws {
        let seconds = 1_786_800_123.0
        let message = Message([
            "id": 42,
            "role": "assistant",
            "content": "older reply",
            "timestamp": seconds,
        ])

        XCTAssertEqual(try XCTUnwrap(message.sentAt).timeIntervalSince1970, seconds, accuracy: 0.001)
        XCTAssertEqual(
            try XCTUnwrap(StudioTimestamp.date(from: "1786800123456")).timeIntervalSince1970,
            1_786_800_123.456,
            accuracy: 0.001
        )
    }

    func testConversationMessageDoesNotInventMissingTimestamp() {
        let message = Message(["role": "assistant", "content": "undated reply"])

        XCTAssertNil(message.sentAt)
    }

    func testDownloadURLCarriesProfileAndToken() throws {
        let client = APIClient(baseURL: "https://studio.example", token: "secret")
        let url = client.downloadURL(path: "/workspace/file.pdf", name: "file.pdf", profile: "main")
        let components = URLComponents(url: try XCTUnwrap(url), resolvingAgainstBaseURL: false)
        let items = Dictionary(uniqueKeysWithValues: try XCTUnwrap(components?.queryItems).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["profile"], "main")
        XCTAssertEqual(items["token"], "secret")
    }

    func testSessionsDefaultToAllProfiles() {
        XCTAssertEqual(APIClient.sessionsPath(profile: nil), "/api/hermes/sessions?limit=80")
        XCTAssertEqual(APIClient.sessionsPath(profile: ""), "/api/hermes/sessions?limit=80")
        XCTAssertEqual(APIClient.sessionsPath(profile: "manager"), "/api/hermes/sessions?profile=manager&limit=80")
    }

    func testSessionPreservesCanonicalAgentFamily() {
        let session = SessionSummary(["id": "s1", "profile": "main", "coding_agent_id": "claude-code", "source": "coding_agent"])
        XCTAssertEqual(session.agentID, "claude-code")
        XCTAssertEqual(session.agentDisplayName, "Claude Code")
        XCTAssertEqual(session.source, "coding_agent")
        XCTAssertEqual(AgentIdentity.canonicalID("ekko"), "ekko-agent")
    }

    func testAgentRuntimeStatusUsesCanonicalStudioFields() {
        let status = AgentRuntimeStatus(["id": "codex", "installed": true, "source": "user-cli", "version": "1.2.3", "path": "/usr/bin/codex"])
        XCTAssertTrue(status.installed)
        XCTAssertEqual(status.source, "user-cli")
        XCTAssertEqual(status.version, "1.2.3")
    }

    func testCanonicalSessionOrganizationFields() {
        let session = SessionSummary(["id": "s2", "category_id": 7, "is_archived": 1, "preview": "matched text", "message_count": 12])
        XCTAssertEqual(session.categoryID, 7)
        XCTAssertTrue(session.archived)
        XCTAssertEqual(session.preview, "matched text")
        XCTAssertEqual(session.messageCount, 12)
    }

    func testWorkflowRunParsesBlockedApprovalNode() {
        let run = WorkflowRun(["id": "r1", "workflow_id": "w1", "status": "running", "node_sessions": [["id": "n1", "node_id": "review", "status": "blocked", "agent": "codex", "execution_id": "e1"]]])
        XCTAssertEqual(run.nodes.first?.status, "blocked")
        XCTAssertEqual(run.nodes.first?.executionID, "e1")
        XCTAssertEqual(run.nodes.first?.agent, "codex")
    }

    func testEkkoAndProviderCanonicalPayloads() {
        let memory = EkkoMemoryItem(["id": "m1", "title": "Preference", "content": "Arabic", "status": "active", "revision": 4, "tags": ["user"]])
        XCTAssertEqual(memory.revision, 4)
        XCTAssertEqual(memory.tags, ["user"])
        let provider = ProviderSummary(["provider": "groq", "label": "Groq", "models": ["m1", "m2"], "api_key": "stored", "model_refreshable": true])
        XCTAssertTrue(provider.credentialConfigured)
        XCTAssertTrue(provider.refreshable)
        XCTAssertEqual(provider.models.count, 2)
    }

    func testProfileRuntimeStatusParsesBridgeAndGateway() {
        let status = ProfileRuntime(["profile": "main", "bridge": ["running": true], "gateway": ["running": false, "url": "http://127.0.0.1:3000"]])
        XCTAssertTrue(status.bridgeRunning)
        XCTAssertFalse(status.gatewayRunning)
        XCTAssertEqual(status.gatewayURL, "http://127.0.0.1:3000")
    }

    func testMarkdownParsesArabicHeadingsListsAndInlineBold() throws {
        let source = "### البريد غير المقروء\n- **635** عاجلة وتتطلب إجراء.\n  - طلبات معلومات.\n\n1. **تنظيف البريد**"
        let blocks = ChatMarkdownParser.parse(source)

        XCTAssertEqual(blocks[0], .heading(level: 3, text: "البريد غير المقروء"))
        XCTAssertEqual(blocks[1], .unordered(indent: 0, text: "**635** عاجلة وتتطلب إجراء."))
        XCTAssertEqual(blocks[2], .unordered(indent: 1, text: "طلبات معلومات."))
        XCTAssertEqual(blocks[3], .ordered(indent: 0, marker: "1.", text: "**تنظيف البريد**"))
        XCTAssertEqual(String(try XCTUnwrap(MarkdownText.attributed(blocks[1].text)).characters), "635 عاجلة وتتطلب إجراء.")
        XCTAssertEqual(MarkdownText.layoutDirection(for: source), .rightToLeft)
    }

    func testEnglishMarkdownKeepsLeftToRightDirection() {
        XCTAssertEqual(MarkdownText.layoutDirection(for: "1. **First task**"), .leftToRight)
    }
}
