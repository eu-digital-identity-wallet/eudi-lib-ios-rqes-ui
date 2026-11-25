/*
 * Copyright (c) 2026 European Commission
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import XCTest
@testable import EudiRQESUi

final class TestEudiRQESUiError: XCTestCase {

  func testErrorDescription_WhenCheckingEveryCase_ThenReturnsTheExpectedMessage() {
    // Given
    let cases: [(EudiRQESUiError, String)] = [
      (.notInitialized, "You need to initialize the EudiRQESUi SDK first with an EudiRQESUiConfig Impl"),
      (.invalidState("someState"), "State is Invalid - someState"),
      (.unableToFetchCredentials, "unableToFetchCredentials"),
      (.unableToSignHashDocument, "unableToSignHashDocument"),
      (.unableToOpenURL, "unableToOpenURL"),
      (.noRQESServiceProvided, "noRQESServiceProvided"),
      (.noDocumentProvided, "noDocumentProvided")
    ]

    // Then
    for (error, expected) in cases {
      XCTAssertEqual(error.errorDescription, expected, "Mismatch for \(error)")
    }
  }
}
