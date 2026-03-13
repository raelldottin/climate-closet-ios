import Foundation
import XCTest

@testable import ClimateCloset

struct HTTPClientStub: HTTPClient {
  let handler: @Sendable (URLRequest) throws -> (Data, URLResponse)

  func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    try handler(request)
  }
}

func makeHTTPResponse(url: URL, statusCode: Int = 200) -> HTTPURLResponse {
  guard
    let response = HTTPURLResponse(
      url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
  else {
    XCTFail("Unable to create HTTPURLResponse")
    fatalError("Unable to create HTTPURLResponse")
  }
  return response
}
