import Foundation
import XCTest
import Nimble
@testable  import Bot

class ResponseTests: XCTestCase {

    func test_decoding_with_next_page_available() {
        let response =  Response(
            statusCode: 200,
            headers: [
                "Link": "<https://api.github.com/repositories/23096959/pulls?page=2&per_page=100>; rel=\"next\", <https://api.github.com/repositories/23096959/pulls?page=2&per_page=100>; rel=\"last\""
            ],
            body: Data())

        expect(response.containsReferenceForNextPage) == true
    }

    func test_decoding_without_more_pages() {
        let response =  Response(
            statusCode: 200,
            headers: [
                "Link": "<https://api.github.com/repositories/23096959/pulls?page=1&per_page=100>; rel=\"prev\", <https://api.github.com/repositories/23096959/pulls?page=1&per_page=100>; rel=\"first\""
            ],
            body: Data())

        expect(response.containsReferenceForNextPage) == false
    }
}
