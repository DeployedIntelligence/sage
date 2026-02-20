import XCTest
@testable import Sage

// MARK: - Mock URLSession

final class ClaudeServiceTests: XCTestCase {

    // MARK: - Helpers

    private func makeService(
        data: Data? = nil,
        response: URLResponse? = nil,
        error: Error? = nil,
        apiKey: String? = "sk-ant-test"
    ) -> ClaudeService {
        let keychain = MockKeychain(key: apiKey)
        let session = MockURLSession(mockData: data, mockResponse: response, mockError: error)
        return ClaudeService(session: session, keychain: keychain)
    }

    private func makeStreamingService(
        lines: [String] = [],
        error: Error? = nil,
        apiKey: String? = "sk-ant-test"
    ) -> ClaudeService {
        let keychain = MockKeychain(key: apiKey)
        let bytesSession = MockBytesSession(mockLines: lines, mockError: error)
        // Data session is irrelevant for streaming tests; use a default stub.
        let session = MockURLSession(mockData: nil, mockResponse: nil, mockError: nil)
        return ClaudeService(session: session, bytesSession: bytesSession, keychain: keychain)
    }

    /// Builds well-formed SSE lines for a sequence of text chunks.
    private func sseLines(chunks: [String], includeDone: Bool = true) -> [String] {
        var lines = chunks.map { chunk -> String in
            let json = "{\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"\(chunk)\"}}"
            return "data: \(json)"
        }
        if includeDone { lines.append("data: [DONE]") }
        return lines
    }

    private func ok200() -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.anthropic.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    private func http(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.anthropic.com")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    private var validResponseData: Data {
        let json = """
        {
          "id": "msg_01",
          "type": "message",
          "role": "assistant",
          "content": [{"type": "text", "text": "Hello!"}],
          "model": "claude-opus-4-6",
          "stop_reason": "end_turn",
          "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        """
        return Data(json.utf8)
    }

    // MARK: - Success

    func testSend_returnsDecodedResponse() async throws {
        let svc = makeService(data: validResponseData, response: ok200())
        let result = try await svc.send(userMessage: "Hi")
        XCTAssertEqual(result.text, "Hello!")
        XCTAssertEqual(result.id, "msg_01")
    }

    // MARK: - Missing API Key

    func testSend_throwsMissingAPIKey_whenNoKeyStored() async {
        let svc = makeService(apiKey: nil)
        do {
            _ = try await svc.send(userMessage: "Hi")
            XCTFail("Expected missingAPIKey")
        } catch NetworkError.missingAPIKey {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - HTTP Errors

    func testSend_throwsInvalidAPIKey_on401() async {
        let errorBody = Data("""
        {"type":"error","error":{"type":"authentication_error","message":"Invalid API key"}}
        """.utf8)
        let svc = makeService(data: errorBody, response: http(401))
        do {
            _ = try await svc.send(userMessage: "Hi")
            XCTFail("Expected invalidAPIKey")
        } catch NetworkError.invalidAPIKey {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSend_throwsRateLimited_on429() async {
        let svc = makeService(data: Data(), response: http(429))
        do {
            _ = try await svc.send(userMessage: "Hi")
            XCTFail("Expected rateLimited")
        } catch NetworkError.rateLimited {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSend_throwsHTTPError_on400() async {
        let errorBody = Data("""
        {"type":"error","error":{"type":"invalid_request_error","message":"Bad param"}}
        """.utf8)
        let svc = makeService(data: errorBody, response: http(400))
        do {
            _ = try await svc.send(userMessage: "Hi")
            XCTFail("Expected httpError")
        } catch NetworkError.httpError(let code, _) {
            XCTAssertEqual(code, 400)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Connectivity

    func testSend_throwsNoConnection_onNotConnectedError() async {
        let urlError = URLError(.notConnectedToInternet)
        let svc = makeService(error: urlError)
        do {
            _ = try await svc.send(userMessage: "Hi")
            XCTFail("Expected noConnection")
        } catch NetworkError.noConnection {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Decoding

    func testSend_throwsDecodingFailed_onMalformedJSON() async {
        let svc = makeService(data: Data("not-json".utf8), response: ok200())
        do {
            _ = try await svc.send(userMessage: "Hi")
            XCTFail("Expected decodingFailed")
        } catch NetworkError.decodingFailed {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - sendConversation

    func testSendConversation_returnsDecodedResponse() async throws {
        let svc = makeService(data: validResponseData, response: ok200())
        let history = [
            Message(conversationId: 1, role: .user,      content: "How do I improve?"),
            Message(conversationId: 1, role: .assistant, content: "Practice daily."),
            Message(conversationId: 1, role: .user,      content: "Anything else?"),
        ]
        let result = try await svc.sendConversation(messages: history)
        XCTAssertEqual(result.text, "Hello!")
    }

    func testSendConversation_throwsMissingAPIKey_whenNoKey() async {
        let svc = makeService(apiKey: nil)
        let history = [Message(conversationId: 1, role: .user, content: "Hi")]
        do {
            _ = try await svc.sendConversation(messages: history)
            XCTFail("Expected missingAPIKey")
        } catch NetworkError.missingAPIKey {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSendConversation_withSystemPrompt_succeeds() async throws {
        let svc = makeService(data: validResponseData, response: ok200())
        let history = [Message(conversationId: 1, role: .user, content: "Start")]
        let result = try await svc.sendConversation(
            messages: history,
            systemPrompt: "You are a helpful coach."
        )
        XCTAssertFalse(result.text.isEmpty)
    }

    // MARK: - streamConversation

    func testStreamConversation_yieldsChunksInOrder() async throws {
        let svc = makeStreamingService(lines: sseLines(chunks: ["Hello", ", ", "world!"]))
        let history = [Message(conversationId: 1, role: .user, content: "Hi")]

        var collected: [String] = []
        for try await chunk in svc.streamConversation(messages: history) {
            collected.append(chunk)
        }

        XCTAssertEqual(collected, ["Hello", ", ", "world!"])
    }

    func testStreamConversation_concatenated_equalsFullReply() async throws {
        let chunks = ["Great", " question", "! Keep practising."]
        let svc = makeStreamingService(lines: sseLines(chunks: chunks))
        let history = [Message(conversationId: 1, role: .user, content: "Tips?")]

        var full = ""
        for try await chunk in svc.streamConversation(messages: history) {
            full += chunk
        }

        XCTAssertEqual(full, chunks.joined())
    }

    func testStreamConversation_throwsMissingAPIKey_whenNoKey() async {
        let svc = makeStreamingService(apiKey: nil)
        let history = [Message(conversationId: 1, role: .user, content: "Hi")]

        do {
            for try await _ in svc.streamConversation(messages: history) {}
            XCTFail("Expected missingAPIKey")
        } catch NetworkError.missingAPIKey {
            // pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStreamConversation_forwardsNetworkError() async {
        let urlError = URLError(.notConnectedToInternet)
        let svc = makeStreamingService(error: urlError)
        let history = [Message(conversationId: 1, role: .user, content: "Hi")]

        do {
            for try await _ in svc.streamConversation(messages: history) {}
            XCTFail("Expected error")
        } catch {
            // Any error is acceptable here since MockBytesSession throws directly.
            XCTAssertNotNil(error)
        }
    }

    func testStreamConversation_skipsNonDeltaEvents() async throws {
        // Simulate realistic SSE stream with ping + message_start before deltas.
        let lines: [String] = [
            "data: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":10}}}",
            "data: {\"type\":\"content_block_start\",\"index\":0}",
            "",  // blank heartbeat line
            "data: {\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"Hi\"}}",
            "data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"}}",
            "data: [DONE]",
        ]
        let svc = makeStreamingService(lines: lines)
        let history = [Message(conversationId: 1, role: .user, content: "Hello")]

        var collected: [String] = []
        for try await chunk in svc.streamConversation(messages: history) {
            collected.append(chunk)
        }

        // Only the one text_delta chunk should be emitted.
        XCTAssertEqual(collected, ["Hi"])
    }
}

// MARK: - Test Doubles

private struct MockKeychain: KeychainStoring {
    let key: String?
    func set(_ value: String, for k: KeychainService.Key) throws {}
    func get(_ k: KeychainService.Key) throws -> String? { key }
    @discardableResult func delete(_ k: KeychainService.Key) -> Bool { true }
}

/// Stub that satisfies `URLSessionDataTasking` without touching the real network.
private struct MockURLSession: URLSessionDataTasking {
    let mockData: Data?
    let mockResponse: URLResponse?
    let mockError: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError { throw error }
        return (mockData ?? Data(), mockResponse ?? URLResponse())
    }
}

/// Stub that satisfies `URLSessionBytesTasking` for streaming tests.
///
/// Yields each pre-configured line in order, then finishes (or throws if `mockError` is set).
private struct MockBytesSession: URLSessionBytesTasking {
    let mockLines: [String]
    let mockError: Error?

    func lines(for request: URLRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            if let error = mockError {
                continuation.finish(throwing: error)
                return
            }
            for line in mockLines {
                continuation.yield(line)
            }
            continuation.finish()
        }
    }
}
