import XCTest
@testable import HermesStudio

final class HermesStudioTests: XCTestCase {
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
