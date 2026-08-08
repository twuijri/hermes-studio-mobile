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

    func testParsesSocketEvent() {
        let packet = #"42/chat-run,["message.delta",{"delta":"hello"}]"#
        let event = ChatSocket.event(packet, namespace: "/chat-run")
        XCTAssertEqual(event?.0, "message.delta")
        XCTAssertEqual(event?.1.string("delta"), "hello")
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

    func testMarkdownPreservesArabicParagraphsAndLists() throws {
        let source = "تم بدء العمل:\n\n1. **فحص الرسائل**\n   - عاجلة وتتطلب إجراء.\n   - طلبات معلومات.\n\n2. **تنظيف البريد**"
        let rendered = try XCTUnwrap(MarkdownText.attributed(source))
        let plain = String(rendered.characters)

        XCTAssertTrue(plain.contains("\n\n1. فحص الرسائل\n"))
        XCTAssertTrue(plain.contains("   - عاجلة وتتطلب إجراء."))
        XCTAssertTrue(plain.contains("\n\n2. تنظيف البريد"))
        XCTAssertEqual(MarkdownText.layoutDirection(for: source), .rightToLeft)
    }

    func testEnglishMarkdownKeepsLeftToRightDirection() {
        XCTAssertEqual(MarkdownText.layoutDirection(for: "1. **First task**"), .leftToRight)
    }
}
